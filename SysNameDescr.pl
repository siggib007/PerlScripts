use strict;
use Net::SNMP;
use English;
use Sys::Hostname;
my ($device,$comstr,$session,$error,$sysname, $sysDescr, $result, $numin, $logfile, $errmsg, $progname);
my ($sname, $sDescr);

$sysname = '1.3.6.1.2.1.1.5.0';
$sysDescr = '.1.3.6.1.2.1.1.1.0';

$numin = scalar(@ARGV);
if ($numin != 2)
	{
		print "\nInvalid usage: Two arguments are required and you supplied $numin\n\n";
		print "Correct usage: perl $PROGRAM_NAME DeviceName pwd\n\n";
		print "DeviceName: the dns name or IP address of device to query\n";
		print "pwd: The snmp community string for this device.\n";
		print "Ex: perl $PROGRAM_NAME 192.168.1.15 public\n\n";
		exit();
	}
	
print "starting $PROGRAM_NAME\n";
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname.log";
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");

$device = $ARGV[0];
$comstr = $ARGV[1];

logentry ("opening a connection to $device\n");
($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr);
if (!defined($session)) {
      $errmsg = sprintf("ERROR: %s.\n", $error);
      logentry ("$errmsg");
      exit 1;
   }

$result = $session->get_request($sysname);
   if (!defined($result)) {
      $errmsg = sprintf("ERROR: %s.\n", $session->error);
      logentry ("$errmsg");
      $session->close;
      exit 1;
   }
$sname = $result->{$sysname};
logentry ("Sysname: $sname\n");

$result = $session->get_request($sysDescr);
   if (!defined($result)) {
      $errmsg = sprintf("ERROR: %s.\n", $session->error);
      logentry ("$errmsg");
      $session->close;
      exit 1;
   }
$sDescr = $result->{$sysDescr};
logentry ("SysDescr: $sDescr\n");

$session->close;
close(LOG);
exit 0;

sub logentry
	{
		my($outmsg) = @_;
		print $outmsg;
		print LOG $outmsg;
	}