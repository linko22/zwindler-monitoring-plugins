#!/usr/bin/perl
################################################################################
#This file is a part of zwindler-monitoring-plugins repository
#Copyright (C) 2014 zwindler
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
################################################################################
# check_sensors_temp.pl checks various components and returns perfdata for graph
### Prerequisites ##############################################################
#sensors command line must be available for monitoring user. You can usually
#install it through the repositories
# - apt-get install lm-sensors for Debian/Ubuntu
# - yum install lm_sensors
### Program main part###########################################################
#Nagios constants
my %ERRORS = ('OK', '0',
                'WARNING', '1',
                'CRITICAL', '2',
                'UNKNOWN', '3');

#Initialisation
BEGIN { $ENV{PATH} = '/bin:/usr/bin:/usr/local/bin:/usr/sbin' }
my $ignore_error_output = "2>/dev/null";

#Getting arguments
my $component = shift || CPU;
my $warn = shift || 0;
my $critical = shift || 0;

#path to sensors binary
my $sensors_cmd = "/usr/bin/sensors";

#Calling subroutines for real work
my @collected_data = collect_data($sensors_cmd);
process_data(@collected_data);

#The process should have ended at "print_nagios_output". This is wrong
print "UNKNOWN: There is a problem with the plugin. Exiting.\n";
exit $ERRORS{"UNKNOWN"};

### Subroutines ################################################################

#Collect data from monitored system
sub collect_data
{
	my @collected_data;
	my $current_component;
	my $current_temp;
	my $current_unit;
	my $current_high_temp;
	my $current_crit_temp;

	open(SENSORSOUT,"$sensors_cmd |") || die "Failed: $!\n";
	while( <SENSORSOUT> )
	{
		if (/([\w\d\s]+):\s+\+(\d+\.\d)°([CF])\s+\(high = \+(\d+\.\d)°[CF], crit = \+(\d+\.\d)°[CF]\)/)
		{
			$current_component = $1;
			$current_temp = $2;
			$current_unit = $3;
			$current_high_temp = $4;
			$current_crit_temp = $5;
			$current_component =~ s/\s+/_/g;
			#Debug
			#print "$current_component;$current_temp;$current_unit;$current_high_temp;$current_crit_temp\n";
			@collected_data = (@collected_data,"$current_component;$current_temp;$current_unit;$current_high_temp;$current_crit_temp");
		}
	}
	close(SENSORSOUT);
	return @collected_data;
}

#Process the collected data, return state and additionnal useful information
sub process_data
{
	my $state="OK";
	my @collected_data = @_;
	my $current_component;
	my $current_temp;
	my $current_unit;
	my $current_high_temp;
	my $current_crit_temp;	
	my $perfdata;
	my $print_answer;

	#Check for high or critical temp and create perfdata
	foreach $component_data (@collected_data)
	{
		($current_component,$current_temp,$current_unit,$current_high_temp,$current_crit_temp) = split(";", $component_data);
		if ($current_temp >= $current_crit_temp)
		{
			if ($state ne "CRITICAL")
			{
				$state = "CRITICAL";
			}
			$output .= "$current_component $current_temp=CRIT ";
		}
		elsif ($current_temp >= $current_high_temp)
		{
			if ($state eq "OK")
			{
				$state = "WARNING";
			}
			$output .= "$current_component $current_temp=HIGH ";
		}
		else
		{
			$output .= "$current_component $current_temp=OK ";	
		}
		#Gen perfdata
		$perfdata .= "$current_component=$current_temp$current_unit;$current_high_temp;$current_crit_temp;; ";
	}

	if ($state eq "OK")
	{
		$print_answer = "OK: $output";
	}
	elsif ($state eq "WARNING")
	{
		$print_answer = "WARNING: $output";
	}
	else
	{
		$print_answer = "CRITICAL: $output";
	}

	#Add perfdata if it exists
	if ($perfdata)
	{
		$print_answer .= "| $perfdata";
	}
	$print_answer .= "\n";

	print $print_answer;
	exit $ERRORS{$state};
}

sub usage()
{
	print "\ncheck_sensors_temp.pl - v 1.0\n\n";
	print "usage:\n";
	exit $exit_codes{'UNKNOWN'};
}
