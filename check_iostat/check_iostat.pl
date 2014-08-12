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
#01/10/2013 - First version, still lot to do (warn + crit) + debug option
#             VG regroupment for Linux not done yet (might crash)
############################################################################
#02/10/2013 - Linux version added, checked
############################################################################
#04/10/2013 - VG regroupment is not working when nrpe works as Nagios as LVM
#             commandes requires privileges. As a temporary workaround the 
#             following can be used but from a security PoV this is awful!!
#             # chown root:nagios /usr/sbin/pvs
#             # chmod u+s /usr/sbin/pvs
############################################################################
#11/08/2014 - Another way to work around this is to add sudo privilege for 
#             nrpe user (nagios most of the time in rpm packages), by adding 
#             the following line in /etc/sudoers
#                 nagios ALL = NOPASSWD: /usr/sbin/pvs, /sbin/multipath
#             You might have to comment out this line
#                 #Default requiretty
#             if you receive the following error
#                 "sudo: sorry, you must have a tty to run sudo"
############################################################################
#12/08/2014 - Corrected the regex for disk grouping in VG for sdXY disks
#             Added a "all" or "vgonly" switch to display only VG. This is 
#             useful for LVM systems with a lot of disks, partitions, 
#             multipath devices where the graphics and perfdata become 
#             unusable really fast
############################################################################

my $os = os_uname();

BEGIN { $ENV{PATH} = '/bin:/usr/bin:/usr/local/bin:/usr/sbin' }

my %ERRORS = ('OK', '0',
                'WARNING', '1',
                'CRITICAL', '2',
                'UNKNOWN', '3');

my $vg_opt = shift || "all";
my $ignore_error_output = "2>/dev/null";
#On some linuxservers, sudo is mandatory, on others, it's unnecessary (maybe 
#due to a patch?). Comment the one you need. TODO : add option
my $sudopath = "/usr/bin/sudo";
#my $sudopath = "";

my $state = "OK";

my $state = getdata();
exit $ERRORS{"$state"};

### Subroutines ##############################################

sub iostat_warnings
        {
        my @t = @_;
        my $state = "OK";
        my $perfdata;
        my $print_answer;

        #Disks information
        my $disk;
        my $disk_name;
        my $disk_rate;
        my $vg_name;
        my $vg_table = {};

        #Here we sort out single disks from VG disks
        foreach $disk (@t)
                {
                ($disk_name,$disk_rate,$vg_name) = split(";", $disk);
		#If this disk is not from a VG and vg_opt = vgonly, ignore it
		#If vg_opt = all, display it
                if ( $vg_name eq "NOVG")
                        {
			if ( $vg_opt eq "all" )
				{
	                        $perfdata .= $disk_name."=".$disk_rate."Bps;$warn;$critical;0; ";
				}
			#TODO : provide more options
			#else
			#	{
			#	}
                        }
                else
                        {
                        #PV disk
                        $vg_table{$vg_name} = $vg_table{$vg_name} + $disk_rate;
                        #DEBUG
                        #print $vg_name." ".$vg_table{$vg_name}."\n";
                        }
                }

        #Now we have the total Bps for VGs from PVs, we can print it
        for my $key ( keys %vg_table )
                {
                my $value = $vg_table{$key};
                $perfdata .= $key."=".$value."Bps;$warn;$critical;0; ";
                }

        #TODO : Add threshold
        #print "OK: $print_answer, below warning/critical thresholds| $perfdata\n";
        #$perfdata =~ s/\./,/;
        print "OK | $perfdata\n";

        return($state);
        }

sub os_uname
        {
        my $uname = ( -e '/usr/bin/uname' ) ? '/usr/bin/uname' : '/bin/uname';
        my $os = (`$uname 2>/dev/null`);
        chomp $os;
        return $os ? $os : undef;
        }

sub getpvpervg_linux
        {
        my ($vg_cmd) = @_;
        my $pvtable = {};
        $current_vg;
        $current_pv;

        open(VGDISPLAYOUT,"$vg_cmd $ignore_error_output |") || die;
        $_ = <VGDISPLAYOUT>;
        while($_ = <VGDISPLAYOUT>)
                {
                #DEBUG
                #print $_;
                if (/\/dev\/(mpath\/)*([sd\w+|dm-|mapth]+\d*[p\d]*|cciss\/c\dd\dp\d)\s+(\S+)\s+lvm/)
                        {
                        $current_pv=$2;
                        $current_vg=$3;
                        #DEBUG
                        #print "$current_pv $current_vg\n";
                        $pvtable{$current_pv} = $current_vg;
                        }
                }
        return $pvtable;
        }

sub getpvpervg_hpux
        {
        my ($vg_cmd) = @_;
        my $pvtable = {};
        $current_vg;
        $current_pv;

        open(VGDISPLAYOUT,"$vg_cmd $ignore_error_output |") || die;
        $_ = <VGDISPLAYOUT>;
        while($_ = <VGDISPLAYOUT>)
                {
                if (/^vg_name=\/dev\/(\w+\d+):/)
                        {
                        $current_vg=$1;
			#DEBUG
                        #print "\n$current_vg\n";
                        }
                if (/^pv_name=\/dev\/disk\/(\w+\d+):/)
                        {
                        $current_pv=$1;
			#DEBUG
                        #print "$current_pv\n";
                        $pvtable{$current_pv} = $current_vg;
                        }
                }
        return $pvtable;
        }

sub getmpath_linux
        {
        my ($mpath_cmd) = @_;
        my $mpathtable = {};
	my $dm_mpath = {};
        $current_disk;
        $current_mpath_device;
	$current_dm_device;

        open(MPATHOUT,"$mpath_cmd $ignore_error_output |") || die;
        $_ = <MPATHOUT>;
        while($_ = <MPATHOUT>)
                {
                #DEBUG
                #print $_;
                if (/^(\w+\d+) \(.+\) (dm-\d+)/)
                        {
                        $current_mpath_device=$1;
			$current_dm_device=$2;
			#DEBUG
			#print $current_dm_device;
			$dm_mpath{$current_dm_device}=$current_mpath_device;
			#print $dm_mpath{$current_dm_device};
                        #print "\n$current_dm_device\n$current_mpath_device\n";
                        }
                else
			{ 
			if (/\d:\d:\d:\d\s+(\w+)/)
	                        {
        	                $current_disk=$1;
                	        #print "$current_disk\n";
                        	$mpathtable{$current_disk} = $current_mpath_device;
                       		}
			else
				{
				#DEBUG
				#print $_;
				#Nothing to see here
				next;
				}
			}
                }
        return ($mpathtable,$dm_mpath);
        }
		
sub getiostat_linux
        {
        my $disk_name;
        my $trans;
        my ($iostat_cmd) = @_;

        open(IOSTATOUT,"$iostat_cmd $ignore_error_output |") || die;
        $_ = <IOSTATOUT>;
        while($_ = <IOSTATOUT>)
                {
                #First output is stats average, which is useless for us, so we ignore the first time
                #DEBUG
                #print $_;
		#print $count;
                if (/Device:/)
                        {
                        $count += 1;
                        }
                if (( $count == 2 ) && (/([\w\d-]+)\s+([\d\.,]+)\s+([\d\.,]+)\s+([\d\.,]+)\s+([\d]+)\s+([\d]+)/))
                        {
                        #For Linux, iostat returns 6 columns as follow
                        #device  tps  KB_read/s  KB_wrtn/s  KB_read  KB_wrtn
                        $disk_name = $1;
                        $disk_rate = ($3 + $4) * 1024;
                        @iostatoutput = (@iostatoutput,"$disk_name;$disk_rate");
                        }
                }
        close(IOSTATOUT);
        return @iostatoutput;
        }

sub getiostat_hpux
        {
        my $disk_name;
        my $disk_rate;
        my ($iostat_cmd) = @_;

        open(IOSTATOUT,"$iostat_cmd $ignore_error_output |") || die;
        $_ = <IOSTATOUT>;
        while($_ = <IOSTATOUT>)
                {
                #First output is stats average, which is useless for us, so we ignore the first time
                #DEBUG
                #print $_;
                if (/^\s$/)
                        {
                        $count += 1;
                        }
                if (( $count == 2 ) && (/^\s*(disk\d+|c\d+t\d+d\d+)\s+(\d+)/))
                        {
                        #For HPUX, iostat returns 4 columns as follow
                        #device  KB/s  NumSeek/s  ms/Seek(avg)
                        $disk_name = $1;
                        $disk_rate = $2 * 1024;
                        @iostatoutput = (@iostatoutput,"$disk_name;$disk_rate");
                        }
                }
        close(IOSTATOUT);
        return @iostatoutput;
        }

sub getdata
       {
        my $vg_cmd;
        my $iostat_cmd;
        my @iostatoutput = ();
        my @new_iostatoutput = ();
        my $pvtable = {};
	my $mpathtable = {};
	my $dm_mpath = {};
        my $count = 0;

        my $disk;
        my $disk_name;
	my $disk_name_nopart;
        my $disk_rate;
        my $vg_name;

        if ($os eq "HP-UX")
                {
                #Getting VG/PV information
                $pvtable = getpvpervg_hpux("vgdisplay -F -v | grep -v lv_name | grep -v pvg_name | grep -v deactivated");

                #Getting iostat
                @iostatoutput = getiostat_hpux("/usr/bin/iostat 1 2");
                }
        elsif ($os eq "Linux")
                {
                #Getting VG/PV information
		$pvtable = getpvpervg_linux("$sudopath /usr/sbin/pvs");

		#Getting Multipath information
		($mpathtable,$dm_mpath) = getmpath_linux("$sudopath /sbin/multipath -l");

                #Getting iostat
		if ( $vg_opt eq "vgonly")
			{
			#partitions may not be shown in some linux distrib without the -p ALL, but this generates lot of 
			#device iostat. Better used only with vgonly option
			@iostatoutput = getiostat_linux("/usr/bin/iostat -p ALL -d -k 1 2");
			}
		else
			{
			@iostatoutput = getiostat_linux("/usr/bin/iostat -d -k 1 2");
			}
                }
        else
                {
                print "CRITICAL : OS $os not yet supported";
                exit $ERRORS{"CRITICAL"};
                }

        if (@iostatoutput)
                {
                #All disks are either tagged with their VG name or NOVG
		#disk dm-\d+ are translated in mpath-\d+
		#TODO, add flags to let the user choose if
		#  - single disk should be grouped by VG or not
                #  - multipath paths are to be ignored
		#  - dm-XXX disks are translated in mpath-XXX
		#  - add options to filter in or out
                foreach $disk (@iostatoutput)
                        {
                        ($disk_name,$disk_rate)=split(";", $disk);
			#Multipath disks and their partitions are ignored
			$disk_name_nopart = $disk_name;
			$disk_name_nopart =~ s/(sd\w+)(\d)/$1/g;
			$disk_name_nopart =~ s/(c.d.)p(\d)/$1/g;
			#DEBUG
			#print "disk_nopart $disk_name_nopart from $disk_name \n";
			if ($mpathtable{$disk_name_nopart})
                                {
                                #DEBUG
                                #print "skipping $disk_name (from $disk_name_nopart=$mpathtable{$disk_name_nopart})\n";
				#This disk is part of a mpath, skipping it to avoid redundant information
				next
                                }
			#disk dm-\d+ are translated in mpath-\d+
			#DEBUG
			#print "$disk_name $dm_mpath{$disk_name}\n";
			if ($dm_mpath{$disk_name})
				{
				#DEBUG
                                #print "$disk_name will be translated in $dm_mpath{$disk_name}";
				$disk_name=$dm_mpath{$disk_name};
				$disk="$disk_name;$disk_rate";
				}
			#DEBUG
			#print "$disk_name\n";
                        $vg_name = $pvtable{$disk_name} || "NOVG";
                        #DEBUG
                        #print $disk_name." ".$disk_rate." ".$vg_name."\n";
                        @new_iostatoutput = (@new_iostatoutput, "$disk;$vg_name");
                        }

                return iostat_warnings(@new_iostatoutput);
                }
        else
                {
                print "UNKNOWN : No disk found, is iostat working?\n";
                exit $ERRORS{"UNKNOW"};
                }
        }
