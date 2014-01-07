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
#07/01/2014 - First version, some improvement on argument checking to do
### Prerequisites###########################################################
# - Install Naviseccli for Linux on your Nagios server
# - As Nagios user, create a certicifate if you don't want to 
#  specify EMC global admin password in the Naviseccli command 
#  line (recommended...) :
#     naviseccli -user sysadmin -password sysadmin -scope 0 \
#     -AddUserSecurity
### Program main part#######################################################
#Nagios constants
my %ERRORS = ('OK', '0',
                'WARNING', '1',
                'CRITICAL', '2',
                'UNKNOWN', '3');

#Initialisation (add variables for Naviseccli)
$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin:/usr/sbin:/opt/Navisphere/bin';
$ENV{SHLIB_PATH} = '/opt/Navisphere/lib/seccli';
$ENV{NAVI_SECCLI_CONF} = '/opt/Navisphere/seccli'; 

#Nagios env variable bypass
my $secfilepath="/home/nagios";
my $naviseccli_cmd = "naviseccli -h IP_ADDRESS -secfilepath $secfilepath reserved -lunpool -list";
#We use -list with no subcommand because naviseccli gives more information
#that way...

#Getting arguments
my $IP_ADDRESS = shift || "127.0.0.1";
#TODO : Check if valid IP address
$naviseccli_cmd =~ s/\QIP_ADDRESS\E/$IP_ADDRESS/g;

#By design
# - we warn if there is 1 or less free RLP for each LUN
# - we raise a critical if there are no more free RLP
#                   AND if one (or more) LUN is 95% full
my $warning = shift || 1;
my $critical = shift || 95;

#Calling subroutines for real work
my @collected_data = collect_data($naviseccli_cmd);
process_data(@collected_data);

#The process should have ended by now. This is wrong
print "UNKNOWN: There is a problem with the plugin. Exiting.\n";
exit $ERRORS{"UNKNOWN"};

### Subroutines ##############################################

#Collect data
sub collect_data
	{
	my @collected_data;
	my ($naviseccli_cmd) = @_;
	my $lun_count = 0;
	my $unalloc_rlp = 0;
	my $current_lun;
	my $current_lun_percent;

	open(NAVICLIOUT,"$naviseccli_cmd |") || die "Failed: $!\n";
	while( <NAVICLIOUT> )
		{
		if (/^Number of Unallocated LUNs in Pool:\s+(\d+)/)
			{
			$unalloc_rlp=$1;
			}
		elsif (/^Target LUN:\s+(\d+)/)
			{
			$current_lun=$1;
			$lun_count += 1;
			}
		elsif (/^Lun Pool LUN % Used:\s+(\d+.\d)/)
			{
			$current_lun_percent=$1;
			@collected_data = (@collected_data,"$current_lun;$current_lun_percent");
			}
		}
	@collected_data = ($lun_count, $unalloc_rlp, @collected_data);
	close(NAVICLIOUT);
	return @collected_data;
    }

#Process the collected data, Nagios output from processed data
sub process_data
	{
	my ($lun_count, $unalloc_rlp, @lun_data) = @_;
	my $single_lun;
	my $state;
	my $print_answer;
	my $perfdata;
	my $rlp_per_lun;
	if ($lun_count != 0)
		{
		$rlp_per_lun = $unalloc_rlp / $lun_count;
		}
	else
		{
		print "UNKNOWN: No LUN using RLP has been found. Exiting.\n";
		exit $ERRORS{"UNKNOWN"};
		}
	my $lun_num;
	my $lun_percent;
	
	#First we check if we have free RLP
	if ( $rlp_per_lun >= $warning )
		{
		$state = "OK";
		$print_answer = "OK: there are enough free RLP";			
		}
	else
		{
		$state = "WARNING";
		$print_answer = "WARNING: there are less than 1 free RLP for each lun! ";
		}
		
	#Now we generate perfdata and check for a critical event 
	foreach $single_lun (@lun_data)
		{
		($lun_num,$lun_percent) = split(";", $single_lun);
		if (($rlp_per_lun == 0 ) && ($lun_percent >= $critical))
			{
			#Here, at least one lun is over critical threshold and there
			#is no more free RLP to extend it
			$state = "CRITICAL";
			$print_answer = "CRITICAL: there are no free RLP and one or more lun are over $critical%!!!";
			}
		$perfdata .= "lun".$lun_num."=".$lun_percent."%;$critical;$critical;0;100 ";
		}
	$perfdata .= "free_rlp_per_lun=$rlp_per_lun;$warning;;0; ";

	#Add perfdata if it exists
	if ($perfdata)
		{
		$print_answer .=  "| $perfdata";
		}
	$print_answer .=  "\n";
	
	print $print_answer;
	exit $ERRORS{$state};
	}
