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
################################################################################
# Simplification of check_all_disks.pl (YM?) to check only one disk
# check_single_disk.pl [FS_to_check] [warn] [crit]
################################################################################
# 24/09/2013 : first version
################################################################################
# 25/09/2013 : adding perfdata, OK for Linux and HP-UX
#              changing nagios return code
#              code cleanup (check was initially designed for multiple disks)
################################################################################
# 02/12/2013 : corrected loophole in check : if disk was not mounted, check
#              displayed the disk underneath without throwing an error
################################################################################

my $os = os_uname();
$os = "IRIX" if $os =~ "IRIX64"; # IRIX can have two different unames.
# my $os = "NEXTSTEP";  # Uncomment this if you have a NeXT machine.

my %commandlist = (
  "HP-UX" =>       {
                   dfcommand => "/bin/bdf -l ",
                   },
  "Linux" =>       {
                   dfcommand => "/bin/df -kl ",
                   },
  "SunOS" =>       {
                   dfcommand => "/bin/df -k ",
                 # dfcommand => "/bin/df -kl",   # For only local disks
                   },
  "IRIX" =>        {
                   dfcommand => "/bin/df -kP ",
                 # dfcommand => "/bin/df -klP",   # For only local disks
                   },
  "OSF1" =>        {
                   dfcommand => "/bin/df -k ",
                   },
  "FreeBSD" =>     {
                   dfcommand => "/bin/df -k ",
                   },
  "NEXTSTEP" =>    {
                   dfcommand => "/bin/df ",
                   },
  "BSD/OS" =>      {
                   dfcommand => "/bin/df ",
                   },
  "OpenBSD" =>     {
                   dfcommand => "/bin/df -k ",
                   },
  "AIX" =>        {
                  dfcommand => "/usr/bin/df -Ik ",
                  },
  "NetBSD" =>     {
                  dfcommand => "/usr/bin/df -k ",
                  },
  "UNIXWARE2" =>  {
                  dfcommand => "/usr/ucb/df ",
                  },
  "SCO-SV" =>     {
                  dfcommand => "/bin/df -Bk ",
                  }
              );

BEGIN { $ENV{PATH} = '/bin:/usr/bin:/usr/local/bin:/usr/sbin' }

my %ERRORS = ('OK', '0',
                'WARNING', '1',
                'CRITICAL', '2',
                'UNKNOWN', '3');

my $selected_disk = shift || &usage(%ERRORS);
my $warn = shift || 85;
my $critical = shift || 95;
my $ignore_error_output = "2>/dev/null";

my $state = "OK";

chomp($os);
my $servanswer = getdisk($os);
#print "$servanswer";
chomp($servanswer);

#
# Return disk warnings
#

my $state = disk_warnings();
exit $ERRORS{"$state"};


### Subroutines ##############################################

sub disk_warnings
  {
  my $state = "OK";
  my $print_answer;

  #check disk
  $print_answer="$selected_disk=$servanswer\%";
  $perfdata="$selected_disk=$servanswer\%;$warn;$critical;0;100";

  if ($servanswer >= $critical)
    {
    print "CRITICAL: $print_answer| $perfdata\n";
    $state = "CRITICAL";
    }
  elsif ($servanswer >= $warn)
    {
    print "WARNING: $print_answer| $perfdata\n";
    $state = "WARNING";
    }
  else
    {
    print "OK: $print_answer, below warning/critical thresholds| $perfdata\n";
    }
  return($state);
  }

sub usage
  {
#
# Usage check_single_disk.pl
#
  print "Minimum arguments not supplied!\n\n";
  print "Usage: $0 <mount points> [warn] [crit]\n\n";
  print "[warn] = Percentage to warn at (default 85%)\n";
  print "[crit] = Percentage to go critical at (default 95%)\n";
  exit $ERRORS{"UNKNOWN"};
  }

sub os_uname
        {
        my $uname = ( -e '/usr/bin/uname' ) ? '/usr/bin/uname' : '/bin/uname';
        my $os = (`$uname 2>/dev/null`);
        chomp $os;
        return $os ? $os : undef;
        }

sub getdisk
        {
        my $dfoutput;

        open(DFOUTPUT,"$commandlist{$os}{dfcommand}$selected_disk $ignore_error_output |") || die;
        $_ = <DFOUTPUT>;
        while($_ = <DFOUTPUT>)
                {
                if (/^[\w\/\:\.\-\=]*\s*\d*\s*\d*\s*\d*\s*(\d*)\%\s*([\w\/\-]*)/)
                        {
                        $dfoutput = $1;
                        $dfdisk = $2;
                        }
                }
        if (($dfdisk eq $selected_disk) && ($dfoutput))
                {
                return $dfoutput;
                }
        else
                {
                print "CRITICAL : Disk not found or not mounted\n";
                exit $ERRORS{"CRITICAL"};
                }
        close(DFOUTPUT);
        undef $dfoutput;
        }
