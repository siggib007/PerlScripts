use strict;
use Socket;
use Net::SNMP;
use Net::Ping::External qw(ping);
use Net::Telnet 3.00;
use English;
use Sys::Hostname;
my ($device,$comstr,$session,$error,$sysname, $result, $numin, $logfile, $errmsg, $progname, $t, $seq, $SNMPSec);
my ($sname, $strOut, $InFile, $outfile, $IPAddr, $line, $PortTest, $TelnetTest, $TelnetSec, $StopTime, $StartTime);
my ($isec, $imin, $ihour, $iDiff, $iDays, $iDiff, $iHours, $iDiff, $iMins, $iSecs,);
my ($Perc, $i, $iLC, $PStartTime);
$sysname = '1.3.6.1.2.1.1.5.0';

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;

$numin = scalar(@ARGV);
if ($numin != 3)
	{
		print "\nInvalid usage: Three arguments are required and you supplied $numin\n\n";
		print "Correct usage: perl $PROGRAM_NAME infile outfile pwd\n\n";
		print "InFile: A comma seperate file listing the target devices\n";
		print "OutFile: filename with complete path of where you want the results saved.\n";
		print "pwd: The standard snmp community string.\n\n";
		print "Ex: perl $PROGRAM_NAME /home/jsmith/devicelist.txt /home/jsmith/snmpout.txt public\n\n";
		exit();
	}
	
print "starting $PROGRAM_NAME at $mon/$mday/$year $hour:$min\n";
$PStartTime = time();

#$seq = int(rand(10));
$seq = 0;
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname-$seq.log";

while (-e $logfile)
{
	print "$logfile in use, increasing suffix\n";
	$seq ++;
	$logfile = "$progname-$seq.log";
}
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");
$t = Net::Telnet->new(  Timeout => 10, Errmode => "return" );
$InFile = $ARGV[0];
$outfile = $ARGV[1];
$comstr = $ARGV[2];

$InFile=~s/\\/\//g;

$outfile=~s/\\/\//g;

open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

$iLC = `wc -l $InFile`;
($iLC) = split(/ /,$iLC);
logentry ("infile contains $iLC hosts\n");

$strOut = "Device\tIP\tDNS_Name\tSysName\tSysDescr\tPing\tTelnet\tSSH\n";
logentry ("$strOut");
print OUT $strOut;

$i=0;

foreach $line (<IN>)
{
	undef $sname;
	chomp($line);
	$i++;
	($device,$IPAddr)  = split (/,/, $line);
	$Perc = ($i / $iLC) * 100;
	$Perc = sprintf("%.3f%%", $Perc);
	
	logentry("processing $device at address $IPAddr which is device $i out of $iLC or $Perc...\n");

	logentry("testing telnet...\n");
	$StartTime = time();
	PortTest ($IPAddr,23);
	$StopTime = time();
	$TelnetSec = $StopTime - $StartTime;
	$TelnetTest = $PortTest;
	logentry(" Telnet test: $TelnetTest ... Took $TelnetSec seconds...\n");
	logentry ("Opening a SNMP connection to $IPAddr\n");
	$StartTime = time();
	($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr, timeout => 10);
	if (!defined($session)) 
	{
	    $errmsg = sprintf("Connect ERROR: %s.\n", $error);
	    logentry ("$errmsg");
  }
	else
	{
		$result = $session->get_request($sysname);
		if (!defined($result)) 
		{
			 $error = $session->error;
		   $errmsg = "Sysname ERROR: $error.\n";
		   logentry ("$errmsg");
		}
		else
		{
			$sname = $result->{$sysname};
			logentry ("Sysname: $sname\n");
			$StopTime = time();
			$SNMPSec = $StopTime - $StartTime;
			logentry ("SNMP query took $SNMPSec Seconds\n");
		}
	}
	$strOut = "$device\t$IPAddr\t$sname\t$SNMPSec\t$TelnetTest\t$TelnetSec\n";
	logentry ("$strOut");
	print OUT $strOut;		  		
	$session->close;
}
$StopTime = time;
$isec = $StopTime - $PStartTime;
$imin = $isec/60;
$ihour = $imin/60;
$iDiff = $isec;
$iDays = int($iDiff/86400);
$iDiff -= $iDays * 86400;
$iHours = int($iDiff/3600);
$iDiff -= $iHours * 3600;
$iMins = int($iDiff/60);
$iSecs = $iDiff - $iMins * 60;

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);	
$mon = $mon + 1;			
logentry ("Stopped processing at $mon/$mday/$year $hour:$min\n" );
logentry ("Processing took $iDays days, $iHours hours, $iMins minutes and $iSecs seconds.\n");
logentry ("elapse time $isec seconds; $imin minutes; $ihour hours.\n");
logentry ("Done. Exiting normally!\n");
close(LOG);
exit 0;

sub logentry
	{
		my($outmsg) = @_;
		print $outmsg;
		print LOG $outmsg;
	}

sub PortTest
	{
		my($hostname, $port) = @_;
		if (defined($t->open(Host => $hostname, Port => $port)))
			{
				$PortTest="Success";
			}
		else
			{
				$PortTest="Fail";
			}
	}
