#!/usr/bin/perl

# Simplification of check_all_disks.pl (YM?) to check only one disk
# check_single_disk.pl [FS_to_check] [warn] [crit]
# Denis GERMAIN

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

my %ERRORS = ('UNKNOWN', '-1',
                'OK', '0',
                'WARNING', '1',
                'CRITICAL', '2');

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
exit $ERRORS{$state};


### Subroutines ##############################################

sub disk_warnings
  {
  my $state = "OK";
  my $print_answer;

  #check disk
  split(/\,/,$servanswer);
  $print_answer="$_[0]=$_[1]\%";

  if ($_[1] >= $critical)
    {
    print "Critical: $print_answer\n";
    $state = "CRITICAL";
    }
  elsif ($_[1] >= $warn)
    {
    print "Warning: $print_answer\n";
    $state = "WARNING";
    }
  else
    {
    print "Ok: $print_answer, below warning/critical thresholds\n";
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
        my $disklisting;

        open(DFOUTPUT,"$commandlist{$os}{dfcommand}$selected_disk $ignore_error_output |") || die;
        $_ = <DFOUTPUT>;
        while($_ = <DFOUTPUT>)
                {
                if (/^[\w\/\:\.\-\=]*\s*\d*\s*\d*\s*\d*\s*(\d*)\%\s*([\w\/\-]*)/)
                        {
                        $disklisting .= "(".$2.",".$1.")";
                        }
                }
        if ($disklisting)
                {
                return $disklisting;
                }
        else
                {
                print "CRITICAL : Disk not found\n";
                exit $ERRORS{"CRITICAL"};
                }
        close(DFOUTPUT);
        undef $disklisting;
        }
