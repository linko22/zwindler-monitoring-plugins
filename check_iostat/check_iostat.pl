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

my $os = os_uname();

BEGIN { $ENV{PATH} = '/bin:/usr/bin:/usr/local/bin:/usr/sbin' }

my %ERRORS = ('OK', '0',
                'WARNING', '1',
                'CRITICAL', '2',
                'UNKNOWN', '3');

#my $selected_disk = shift || &usage(%ERRORS);
my $warn = shift || 100*1024*1024;
my $critical = shift || 200*1024*1024;
my $ignore_error_output = "2>/dev/null";

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

	#Here we sort singles disks from disks in VG
	foreach $disk (@t)
		{
		($disk_name,$disk_rate,$vg_name) = split(";", $disk);
		if ( $vg_name eq "NOVG" )
			{
			#Single disk
			$perfdata .= $disk_name."=".$disk_rate."Bps;$warn;$critical;0; ";
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
		if (/\/dev\/([\w-]+\d*)\s+(\S+)\s+/)
			{
			$current_pv=$1;
			$current_vg=$2;
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
			#print "\n$current_vg\n";
			}
		if (/^pv_name=\/dev\/disk\/(\w+\d+):/)
			{
			$current_pv=$1;
			#print "$current_pv\n";
			$pvtable{$current_pv} = $current_vg;
			}
		}
	return $pvtable;
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
		#if (( $count == 2 ) && (/^\s*(disk\d+|c\d+t\d+d\d+)\s+(\d+)\s+([\d+\.])\s+([\d+\.])/)) #YUNOWORK!!!
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
	my $count = 0;

	my $disk;
	my $disk_name;
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
		@pvtable = getpvpervg_linux("pvs");

		#Getting iostat
		@iostatoutput = getiostat_linux("/usr/bin/iostat -d -k 1 2");
		}
	else
		{
		print "CRITICAL : OS $os not yet supported";
		exit $ERRORS{"CRITICAL"};
		}

	if (@iostatoutput)
		{
		#All disks are either tagged with their VG name or NOVG	
		foreach $disk (@iostatoutput)
			{
			($disk_name,$disk_rate)=split(";", $disk);
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
