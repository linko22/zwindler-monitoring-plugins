#!/usr/bin/perl
############################################################################
#This file is a part of zwindler-monitoring-plugins repository
#Copyright (C) 2013 zwindler
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program. If not, see {http://www.gnu.org/licenses/}.
############################################################################
#12/08/2014 - Code extension from check_snmp_process.pl v1.10 
############################################################################
# See http://nagios.manubulon.com/snmp_process.html and 
# and http://nagios-snmp.cvs.sourceforge.net/viewvc/nagios-snmp/plugins/check_snmp_process.pl?revision=1.10&view=markup
############################################################################
# Initial author and credits
############################## check_snmp_process ##########################
my $Version='1.10';
# Date : Oct 12 2007
# Author  : Patrick Proy (patrick at proy dot org)
# Help : http://nagios.manubulon.com
# Contrib : Makina Corpus, adam At greekattic d0t com
############################################################################
#
# help : ./check_snmp_process -h

use strict;
use Getopt::Long;

############################################################################
# D GERMAIN : Strange ... this file seems to have been modified by Centreon
require "/usr/local/nagios/libexec/Centreon/SNMP/Utils.pm";
#Initial file from http://nagios-snmp.cvs.sourceforge.net rather uses 
#use Net::SNMP;
#This MAY NOT be the same file as the original from CVS...
############################################################################


############### BASE DIRECTORY FOR TEMP FILE ###############################
my $o_base_dir="/tmp/tmp_Nagios_proc.";
my $file_history=200;   # number of data to keep in files.
my $delta_of_time_to_make_average=300;  # 5minutes by default

# Nagios specific

my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my %OPTION = (
    "host" => undef,
    "snmp-community" => "public", "snmp-version" => 1, "snmp-port" => 161,
    "snmp-auth-key" => undef, "snmp-auth-user" => undef, "snmp-auth-password" => undef, "snmp-auth-protocol" => "MD5",
    "snmp-priv-key" => undef, "snmp-priv-password" => undef, "snmp-priv-protocol" => "DES",
    "maxrepetitions" => undef,
    "64-bits" => undef,
);
my $session_params;

# SNMP Datas
my $process_table= '1.3.6.1.2.1.25.4.2.1';
my $index_table = '1.3.6.1.2.1.25.4.2.1.1';
my $run_name_table = '1.3.6.1.2.1.25.4.2.1.2';
my $run_path_table = '1.3.6.1.2.1.25.4.2.1.4';
my $run_param_table = '1.3.6.1.2.1.25.4.2.1.5';
my $proc_mem_table = '1.3.6.1.2.1.25.5.1.1.2'; # Kbytes
my $proc_cpu_table = '1.3.6.1.2.1.25.5.1.1.1'; # Centi sec of CPU
my $proc_run_state = '1.3.6.1.2.1.25.4.2.1.7';

# Globals
my $o_descr =   undef;          # description filter
my $o_warn =    0;              # warning limit
my @o_warnL=    undef;          # warning limits (min,max)
my $o_crit=     0;              # critical limit
my @o_critL=    undef;          # critical limits (min,max)
my $o_help=     undef;          # wan't some help ?
my $o_verb=     undef;          # verbose mode
my $o_version=   undef;         # print version
my $o_noreg=    undef;          # Do not use Regexp for name
my $o_path=     undef;          # check path instead of name
my $o_inverse=  undef;          # checks max instead of min number of process
my $o_get_all=  undef;          # get all tables at once
my $o_param=    undef;          # Add process parameters for selection
my $o_perf=     undef;          # Add performance output
my $o_timeout=  5;              # Default 5s Timeout
# Memory & CPU
my $o_mem=      undef;          # checks memory (max)
my @o_memL=     undef;          # warn and crit level for mem
my $o_mem_avg=  undef;          # cheks memory average
my $o_cpu=      undef;          # checks CPU usage
my @o_cpuL=     undef;          # warn and crit level for cpu
my $o_delta=    $delta_of_time_to_make_average;         # delta time for CPU check

# functions

sub p_version { print "check_snmp_process version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd) [-p <port>] -n <name> [-w <min_proc>[,<max_proc>] -c <min_proc>[,max_proc] ] [-m<warn Mb>,<crit Mb> -a -u<warn %>,<crit%> -d<delta> ] [-t <timeout>] [-o <octet_length>] [-f -A -F ] [-r] [-V] [-g]\n";
}

sub isnotnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^-?(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

# Get the alarm signal (just in case snmp timout screws up)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};

sub read_file {
    # Input : File, items_number
    # Returns : array of value : [line][item]
    my ($traffic_file,$items_number)=@_;
    my ($ligne,$n_rows)=(undef,0);
    my (@last_values,@file_values,$i);
    open(FILE,"<".$traffic_file) || return (1,0,0);

    while($ligne = <FILE>) {
        chomp($ligne);
        @file_values = split(":",$ligne);
        #verb("@file_values");
        if ($#file_values >= ($items_number-1)) {
            # check if there is enough data, else ignore line
            for ( $i=0 ; $i< $items_number ; $i++ ) {$last_values[$n_rows][$i]=$file_values[$i]; }
            $n_rows++;
        }
    }
    close FILE;
    if ($n_rows != 0) {
        return (0,$n_rows,@last_values);
    } else {
        return (1,0,0);
    }
}

sub write_file {
    # Input : file , rows, items, array of value : [line][item]
    # Returns : 0 / OK, 1 / error
    my ($file_out,$rows,$item,@file_values)=@_;
    my $start_line= ($rows > $file_history) ? $rows -  $file_history : 0;
    if ( open(FILE2,">".$file_out) ) {
        for (my $i=$start_line;$i<$rows;$i++) {
            for (my $j=0;$j<$item;$j++) {
                print FILE2 $file_values[$i][$j];
                if ($j != ($item -1)) { print FILE2 ":" };
            }
            print FILE2 "\n";
        }
        close FILE2;
        return 0;
    } else {
        return 1;
    }
}

sub help {
   print "\nSNMP Process Monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c)2004-2006 Patrick Proy\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information (and lists all storages)
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies SNMP v1 or v2c with option)
-l, --login=LOGIN ; -x, --passwd=PASSWD, -2, --v2c
   Login and auth password for snmpv3 authentication
   If no priv password exists, implies AuthNoPriv
   -2 : use snmp v2c
-n, --name=NAME
   Name of the process (regexp)
   No trailing slash !
-r, --noregexp
   Do not use regexp to match NAME in description OID
-f, --fullpath
   Use full path name instead of process name
   (Windows doesn't provide full path name)
-A, --param
   Add parameters to select processes.
   ex : "named.*-t /var/named/chroot" will only select named process with this parameter
-F, --perfout
   Add performance output
   outputs : memory_usage, num_process, cpu_usage
-w, --warn=MIN[,MAX]
   Number of process that will cause a warning
   -1 for no warning, MAX must be >0. Ex : -w-1,50
-c, --critical=MIN[,MAX]
   number of process that will cause an error (
   -1 for no critical, MAX must be >0. Ex : -c-1,50
Notes on warning and critical :
   with the following options : -w m1,x1 -c m2,x2
   you must have : m2 <= m1 < x1 <= x2
   you can omit x1 or x2 or both
-m, --memory=WARN,CRIT
   checks memory usage (default max of all process)
   values are warning and critical values in Mb
-a, --average
   makes an average of memory used by process instead of max
-u, --cpu=WARN,CRIT
   checks cpu usage of all process
   values are warning and critical values in % of CPU usage
   if more than one CPU, value can be > 100% : 100%=1 CPU
-d, --delta=seconds
   make an average of <delta> seconds for CPU (default 300=5min)
-g, --getall
  In some cases, it is necessary to get all data at once because
  process die very frequently.
  This option eats bandwidth an cpu (for remote host) at breakfast.
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-V, --version
   prints version number
Note :
  CPU usage is in % of one cpu, so maximum can be 100% * number of CPU
  example :
  Browse process list : <script> -C <community> -H <host> -n <anything> -v
  the -n option allows regexp in perl format :
  All process of /opt/soft/bin          : -n /opt/soft/bin/ -f
  All 'named' process                   : -n named

EOT
}

sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
         "H|hostname|host=s"         => \$OPTION{'host'},
        "C|community=s"             => \$OPTION{'snmp-community'},
        "snmp|snmp-version=s"       => \$OPTION{'snmp-version'},
        "p|port|P|snmpport|snmp-port=i"    => \$OPTION{'snmp-port'},
        "l|login|username=s"        => \$OPTION{'snmp-auth-user'},
        "x|passwd|authpassword|password=s" => \$OPTION{'snmp-auth-password'},
        "k|authkey=s"               => \$OPTION{'snmp-auth-key'},
        "authprotocol=s"            => \$OPTION{'snmp-auth-protocol'},
        "privpassword=s"            => \$OPTION{'snmp-priv-password'},
        "privkey=s"                 => \$OPTION{'snmp-priv-key'},
        "privprotocol=s"            => \$OPTION{'snmp-priv-protocol'},
        "maxrepetitions=s"          => \$OPTION{'maxrepetitions'},
        "64-bits"                   => \$OPTION{'64-bits'},

        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
                't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'n:s'   => \$o_descr,           'name:s'        => \$o_descr,
        'r'     => \$o_noreg,           'noregexp'      => \$o_noreg,
        'f'     => \$o_path,            'fullpath'      => \$o_path,
        'm:s'   => \$o_mem,             'memory:s'      => \$o_mem,
        'a'     => \$o_mem_avg,         'average'       => \$o_mem_avg,
        'u:s'   => \$o_cpu,             'cpu'           => \$o_cpu,
                'g'     => \$o_get_all,         'getall'        => \$o_get_all,
                'A'     => \$o_param,         'param'       => \$o_param,
                'F'     => \$o_perf,         'perfout'       => \$o_perf,
        'd:i'   => \$o_delta,           'delta:i'       => \$o_delta,
                'V'     => \$o_version,         'version'       => \$o_version
    );
    if (defined ($o_help)) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    # check snmp information
    ($session_params) = Centreon::SNMP::Utils::check_snmp_options($ERRORS{'UNKNOWN'}, \%OPTION);
        if (defined($o_timeout) && (isnotnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60)))
          { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
        if (!defined($o_timeout)) {$o_timeout=5;}
    # Check compulsory attributes
    if ( ! defined($o_descr) ) { print_usage(); exit $ERRORS{"UNKNOWN"}};
    @o_warnL=split(/,/,$o_warn);
    @o_critL=split(/,/,$o_crit);
    verb("$o_warn $o_crit $#o_warnL $#o_critL");
    if ( isnotnum($o_warnL[0]) || isnotnum($o_critL[0]))
       { print "Numerical values for warning and critical\n";print_usage(); exit $ERRORS{"UNKNOWN"};}
    if ((defined($o_warnL[1]) && isnotnum($o_warnL[1])) || (defined($o_critL[1]) && isnotnum($o_critL[1])))
       { print "Numerical values for warning and critical\n";print_usage(); exit $ERRORS{"UNKNOWN"};}
    # Check for positive numbers on maximum number of processes
    if ((defined($o_warnL[1]) && ($o_warnL[1] < 0)) || (defined($o_critL[1]) && ($o_critL[1] < 0)))
      { print " Maximum process warn and critical > 0 \n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    # Check min_crit < min warn < max warn < crit warn
    if ($o_warnL[0] < $o_critL[0]) { print " warn minimum must be >= crit minimum\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_warnL[1])) {
      if ($o_warnL[1] <= $o_warnL[0])
        { print "warn minimum must be < warn maximum\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    } elsif ( defined($o_critL[1]) && ($o_critL[1] <= $o_warnL[0]))
       { print "warn minimum must be < crit maximum when no crit warning defined\n";print_usage(); exit $ERRORS{"UNKNOWN"};}
    if ( defined($o_critL[1]) && defined($o_warnL[1]) && ($o_critL[1]<$o_warnL[1]))
       { print "warn max must be <= crit maximum\n";print_usage(); exit $ERRORS{"UNKNOWN"};}
    #### Memory checks
    if (defined ($o_mem)) {
      @o_memL=split(/,/,$o_mem);
      if ($#o_memL != 1)
        {print "2 values (warning,critical) for memory\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
      if (isnotnum($o_memL[0]) || isnotnum($o_memL[1]))
       {print "Numeric values for memory!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
      if ($o_memL[0]>$o_memL[1])
       {print "Warning must be <= Critical for memory!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    }
    #### CPU checks
    if (defined ($o_cpu)) {
      @o_cpuL=split(/,/,$o_cpu);
      if ($#o_cpuL != 1)
        {print "2 values (warning,critical) for cpu\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
      if (isnotnum($o_cpuL[0]) || isnotnum($o_cpuL[1]))
       {print "Numeric values for cpu!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
      if ($o_cpuL[0]>$o_cpuL[1])
       {print "Warning must be <= Critical for cpu!\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    }
}

########## MAIN ############################################################

check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
    verb("Alarm at $TIMEOUT");
    alarm($TIMEOUT);
} else {
    verb("no timeout defined : $o_timeout + 10");
    alarm ($o_timeout+10);
}

my $session = Centreon::SNMP::Utils::connection($ERRORS{'UNKNOWN'}, $session_params);

# Look for process in name or path name table
my $resultat=undef;
my %result_cons=();
my ($getall_run,$getall_cpu,$getall_mem)=(undef,undef,undef);
if ( !defined ($o_path) ) {
    $resultat = Centreon::SNMP::Utils::get_snmp_table($run_name_table, $session, $ERRORS{'UNKNOWN'}, \%OPTION);
} else {
    $resultat = Centreon::SNMP::Utils::get_snmp_table($run_path_table, $session, $ERRORS{'UNKNOWN'}, \%OPTION);
}

my $resultat_param=undef;
if (defined($o_param)) { # Get parameter table too
    $resultat_param =  Centreon::SNMP::Utils::get_snmp_table($run_param_table, $session, $ERRORS{'UNKNOWN'}, \%OPTION);
}

if (defined ($o_get_all)) {
    $getall_run = Centreon::SNMP::Utils::get_snmp_table($proc_run_state, $session, $ERRORS{'UNKNOWN'}, \%OPTION);
    foreach my $key ( keys %$getall_run) {
        $result_cons{$key}=$$getall_run{$key};
    }
    $getall_cpu = Centreon::SNMP::Utils::get_snmp_table($proc_cpu_table, $session, $ERRORS{'UNKNOWN'}, \%OPTION);
    foreach my $key ( keys %$getall_cpu) {
        $result_cons{$key}=$$getall_cpu{$key};
    }
    $getall_mem = Centreon::SNMP::Utils::get_snmp_table($proc_mem_table, $session, $ERRORS{'UNKNOWN'}, \%OPTION);
    foreach my $key ( keys %$getall_mem) {
        $result_cons{$key}=$$getall_mem{$key};
    }
}

my @tindex = undef;
my @oids = undef;
my @descr = undef;
my $num_int = 0;
my $count_oid = 0;
# Select storage by regexp of exact match
# and put the oid to query in an array

verb("Filter : $o_descr");

foreach my $key ( keys %$resultat) {
    # test by regexp or exact match
    # First add param if necessary
    if (defined($o_param)){
        my $pid = (split /\./,$key)[-1];
        $pid = $run_param_table .".".$pid;
        $$resultat{$key} .= " " . $$resultat_param{$pid};
    }
    verb("OID : $key, Desc : $$resultat{$key}");
    my $test = defined($o_noreg)
        ? $$resultat{$key} eq $o_descr
        : $$resultat{$key} =~ /$o_descr/;
    if ($test) {
        # get the index number of the interface
        my @oid_list = split (/\./,$key);
        $tindex[$num_int] = pop (@oid_list);
        # get the full description
        $descr[$num_int]=$$resultat{$key};
        # put the oid of running and mem (check this maybe ?) in an array.
        $oids[$count_oid++]=$proc_mem_table . "." . $tindex[$num_int];
        $oids[$count_oid++]=$proc_cpu_table . "." . $tindex[$num_int];
        $oids[$count_oid++]=$proc_run_state . "." . $tindex[$num_int];
        #verb("Name : $descr[$num_int], Index : $tindex[$num_int]");
        verb($oids[$count_oid-1]);
        $num_int++;
    }
}

if ( $num_int == 0) {
    print "No process ",(defined ($o_noreg)) ? "named " : "matching ", $o_descr, " found : ";
    if ($o_critL[0]>=0) {
        print "CRITICAL\n";
        exit $ERRORS{"CRITICAL"};
    } elsif ($o_warnL[0]>=0) {
        print "WARNING\n";
        exit $ERRORS{"WARNING"};
    }
    print "YOU told me it was : OK\n";
    exit $ERRORS{"OK"};
}

my $result=undef;
my $num_int_ok=0;
# Splitting snmp request because can't use get_bulk_request with v1 protocol
if (!defined ($o_get_all)) {
    if ( $count_oid >= 50) {
        my @toid=undef;
        my $tmp_num=0;
        my $tmp_index=0;
        my $tmp_count=$count_oid;
        my $tmp_result=undef;
        verb("More than 50 oid, splitting");
        while ( $tmp_count != 0 ) {
            $tmp_num = ($tmp_count >=50) ? 50 : $tmp_count;
            for (my $i=0; $i<$tmp_num;$i++) {
                $toid[$i]=$oids[$i+$tmp_index];
                #verb("$i :  $toid[$i] : $oids[$i+$tmp_index]");
            }
            $tmp_result = Centreon::SNMP::Utils::get_snmp_leef(\@toid, $session, $ERRORS{'UNKNOWN'});
            foreach (@toid) { $result_cons{$_}=$$tmp_result{$_}; }
            $tmp_count-=$tmp_num;
            $tmp_index+=$tmp_num;
        }
    } else {
        my $tmp_result = Centreon::SNMP::Utils::get_snmp_leef(\@oids, $session, $ERRORS{'UNKNOWN'});
        foreach (@oids) {$result_cons{$_}=$$tmp_result{$_};}
    }
}

#Check if process are in running or runnable state
for (my $i=0; $i< $num_int; $i++) {
    my $state=$result_cons{$proc_run_state . "." . $tindex[$i]};
    my $tmpmem=$result_cons{$proc_mem_table . "." . $tindex[$i]};
    my $tmpcpu=$result_cons{$proc_cpu_table . "." . $tindex[$i]};
    verb ("Process $tindex[$i] in state $state using $tmpmem, and $tmpcpu CPU");
    if (!isnotnum($state)) { # check argument is numeric (can be NoSuchInstance)
        $num_int_ok++ if (($state == 1) || ($state ==2));
    }
}

my $final_status=0;
my $perf_output;
my ($res_memory,$res_cpu)=(0,0);
my $memory_print="";
my $cpu_print="";
###### Checks memory usage

if (defined ($o_mem) ) {
    if (defined ($o_mem_avg)) {
        for (my $i=0; $i< $num_int; $i++) { $res_memory += $result_cons{$proc_mem_table . "." . $tindex[$i]};}
        $res_memory /= ($num_int_ok*1024);
        verb("Memory average : $res_memory");
    } else {
        for (my $i=0; $i< $num_int; $i++) {
            $res_memory = ($result_cons{$proc_mem_table . "." . $tindex[$i]} > $res_memory) ? $result_cons{$proc_mem_table . "." . $tindex[$i]} : $res_memory;
        }
        $res_memory /=1024;
        verb("Memory max : $res_memory");
    }
    if ($res_memory > $o_memL[1]) {
        $final_status=2;
        $memory_print=", Mem : ".sprintf("%.1f",$res_memory)."Mb > ".$o_memL[1]." CRITICAL";
    } elsif ( $res_memory > $o_memL[0]) {
        $final_status=1;
        $memory_print=", Mem : ".sprintf("%.1f",$res_memory)."Mb > ".$o_memL[0]." WARNING";
    } else {
        $memory_print=", Mem : ".sprintf("%.1f",$res_memory)."Mb OK";
    }
    if (defined($o_perf)) {
        $perf_output= "'memory_usage'=".sprintf("%.1f",$res_memory) ."MB;".$o_memL[0].";".$o_memL[1];
    }
}

######## Checks CPU usage

if (defined ($o_cpu) ) {
    my $timenow=time;
    my $temp_file_name;
    my ($return,@file_values)=(undef,undef);
    my $n_rows=0;
    my $n_items_check=2;
    my $trigger=$timenow - ($o_delta - ($o_delta/10));
    my $trigger_low=$timenow - 3*$o_delta;
    my ($old_value,$old_time)=undef;
    my $found_value=undef;

    #### Get the current values
    for (my $i=0; $i< $num_int; $i++) { $res_cpu += $result_cons{$proc_cpu_table . "." . $tindex[$i]};}

    verb("Time: $timenow , cpu (centiseconds) : $res_cpu");

    #### Read file
    $temp_file_name=$o_descr;
    $temp_file_name =~ s/ /_/g;
    $temp_file_name = $o_base_dir . $OPTION{'host'} ."." . $temp_file_name;
    # First, read entire file
    my @ret_array=read_file($temp_file_name,$n_items_check);
    $return = shift(@ret_array);
    $n_rows = shift(@ret_array);
    if ($n_rows != 0) { @file_values = @ret_array };
    verb ("File read returns : $return with $n_rows rows");
    #make the checks if the file is OK
    if ($return ==0) {
        my $j=$n_rows-1;
        do {
            if ($file_values[$j][0] < $trigger) {
                if ($file_values[$j][0] > $trigger_low) {
                    # found value = centiseconds / seconds = %cpu
                    $found_value= ($res_cpu-$file_values[$j][1]) / ($timenow - $file_values[$j][0] );
                    if ($found_value <0) { # in case of program restart
                        $j=0;$found_value=undef; # don't look for more values
                        $n_rows=0; # reset file
                    }
                }
            }
            $j--;
        } while ( ($j>=0) && (!defined($found_value)) );
    }
    ###### Write file
    $file_values[$n_rows][0]=$timenow;
    $file_values[$n_rows][1]=$res_cpu;
    $n_rows++;
    $return=write_file($temp_file_name,$n_rows,$n_items_check,@file_values);
    if ($return != 0) { $cpu_print.="! ERROR writing file $temp_file_name !";$final_status=3;}
    ##### Check values (if something to check...)
    if (defined($found_value)) {
        if ($found_value > $o_cpuL[1]) {
            $final_status=2;
            $cpu_print.=", Cpu : ".sprintf("%.0f",$found_value)."% > ".$o_cpuL[1]." CRITICAL";
        } elsif ( $found_value > $o_cpuL[0]) {
            $final_status=($final_status==2)?2:1;
            $cpu_print.=", Cpu : ".sprintf("%.0f",$found_value)."% > ".$o_cpuL[0]." WARNING";
        } else {
            $cpu_print.=", Cpu : ".sprintf("%.0f",$found_value)."% OK";
        }
        if (defined($o_perf)) {
            if (!defined($perf_output)) {$perf_output="";} else {$perf_output.=" ";}
            $perf_output.= "'cpu_usage'=". sprintf("%.0f",$found_value)."%;".$o_cpuL[0].";".$o_cpuL[1];
        }
    } else {
        if ($final_status==0) { $final_status=3 };
        $cpu_print.=", No data for CPU (".$n_rows." line(s)):UNKNOWN";
    }
}

print $num_int_ok, " process ", (defined ($o_noreg)) ? "named " : "matching ", $o_descr, " ";

#### Check for min and max number of process
if ( $num_int_ok <= $o_critL[0] ) {
    print "(<= ",$o_critL[0]," : CRITICAL)";
    $final_status=2;
} elsif ( $num_int_ok <= $o_warnL[0] ) {
    print "(<= ",$o_warnL[0]," : WARNING)";
    $final_status=($final_status==2)?2:1;
} else {
    print "(> ",$o_warnL[0],")";
}
if (defined($o_critL[1]) && ($num_int_ok > $o_critL[1])) {
    print " (> ",$o_critL[1]," : CRITICAL)";
    $final_status=2;
} elsif (defined($o_warnL[1]) && ($num_int_ok > $o_warnL[1])) {
    print " (> ",$o_warnL[1]," : WARNING)";
    $final_status=($final_status==2)?2:1;
} elsif (defined($o_warnL[1])) {
    print " (<= ",$o_warnL[1],"):OK";
}

print $memory_print,$cpu_print;

if (defined($o_perf)) {
    if (!defined($perf_output)) {$perf_output="";} else {$perf_output.=" ";}
############################################################################
    #D GERMAIN : Extension of initial code. If user sets min warn level at 
    -1, the perfdata will lead to erroneous rrd graphs with crit and warn 
    line at -1. Clear it OR use max warn/crit level, if provided
############################################################################
    my $warn_output;
    my $crit_output;
    if ($o_warnL[0] < 0){
        if (defined($o_warnL[1])) {$warn_output=$o_warnL[1];} else {$warn_output="";}
    }
    else{
        $warn_output=$o_warnL[0];
    }
    if ($o_critL[0] < 0){
        if (defined($o_critL[1])) {$crit_output=$o_critL[1];} else {$crit_output="";}
    }
    else{
        $crit_output=$o_critL[0];
    }
    $perf_output.= "'num_process'=". $num_int_ok.";".$warn_output.";".$crit_output;
    print " | ",$perf_output;
}
print "\n";

if ($final_status==2) { exit $ERRORS{"CRITICAL"};}
if ($final_status==1) { exit $ERRORS{"WARNING"};}
if ($final_status==3) { exit $ERRORS{"UNKNOWN"};}
exit $ERRORS{"OK"};
