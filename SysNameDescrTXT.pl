use strict;
use Net::SNMP;
use English;
use Sys::Hostname;
my ($device,$comstr,$session,$error,$sysname, $sysDescr, $result, $numin, $logfile, $errmsg, $progname);
my ($sname, $sDescr, $strOut, $InFile, $outfile, $IPAddr, $line);

$sysname = '1.3.6.1.2.1.1.5.0';
$sysDescr = '1.3.6.1.2.1.1.1.0';

$numin = scalar(@ARGV);
if ($numin != 3)
	{
		print "\nInvalid usage: Three arguments are required and you supplied $numin\n\n";
		print "Correct usage: perl $PROGRAM_NAME infile outfile pwd\n\n";
		print "InFile: A comma seperate file listing the target server techs\n";
		print "OutFile: filename with complete path of where you want the results saved.\n";
		print "pwd: The snmp community string for this device.\n\n";
		print "Ex: perl $PROGRAM_NAME c:/tools/devicelist.txt c:/tools/snmpout.txt public \n";
		exit();
	}
	
print "starting $PROGRAM_NAME\n";
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname.log";
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");

$InFile = $ARGV[0];
$outfile = $ARGV[1];
$comstr = $ARGV[2];

$InFile=~s/\\/\//g;

$outfile=~s/\\/\//g;

open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

$strOut = "Device\tIP\tSysName\tSysDescr\n";
logentry ("$strOut");
print OUT $strOut;

foreach $line (<IN>)
{
	chomp($line);
	($IPAddr,$device)  = split (/\t/, $line);
	
	logentry("processing $device at address $IPAddr...\n");

	logentry ("opening a connection to $IPAddr\n");
	($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr);
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
	$strOut = "$device\t$IPAddr\t$sname\t$sDescr\n";
	logentry ("$strOut");
	print OUT $strOut;
}
close(LOG);
exit 0;

sub logentry
	{
		my($outmsg) = @_;
		print $outmsg;
		print LOG $outmsg;
	}