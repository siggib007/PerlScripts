use strict;
use Socket;
use Net::SNMP;
use Net::Ping::External qw(ping);
use Net::Telnet 3.00;
use English;
use Sys::Hostname;
my ($device,$comstr,$session,$error,$sysname, $sysDescr, $result, $numin, $logfile, $errmsg, $progname, $t, $seq );
my ($sname, $sDescr, $strOut, $InFile, $outfile, $IPAddr, $line, $bError, $alive, $PortTest, $SSHTest, $TelnetTest);
my ($DNSname, $iaddr);

$sysname = '1.3.6.1.2.1.1.5.0';
$sysDescr = '1.3.6.1.2.1.1.1.0';

$numin = scalar(@ARGV);
if ($numin != 3)
	{
		print "\nInvalid usage: Three arguments are required and you supplied $numin\n\n";
		print "Correct usage: perl $PROGRAM_NAME infile outfile pwd\n\n";
		print "InFile: A comma seperate file listing the target devices\n";
		print "OutFile: filename with complete path of where you want the results saved.\n";
		print "pwd: The snmp community string for this device.\n\n";
		print "Ex: perl $PROGRAM_NAME /home/jsmith/devicelist.txt /home/jsmith/snmpout.txt public\n\n";
		exit();
	}
	
print "starting $PROGRAM_NAME\n";
$seq = int(rand(10));
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname-$seq.log";
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");
$t = Net::Telnet->new(  Timeout => 30, Errmode => "return" );
$InFile = $ARGV[0];
$outfile = $ARGV[1];
$comstr = $ARGV[2];

$InFile=~s/\\/\//g;

$outfile=~s/\\/\//g;

open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

$strOut = "Device\tIP\tDNS_Name\tSysName\tSysDescr\tPing\tTelnet\tSSH\n";
logentry ("$strOut");
print OUT $strOut;

foreach $line (<IN>)
{
	$bError = 0;
	chomp($line);
	($device,$IPAddr)  = split (/,/, $line);
	
	logentry("processing $device at address $IPAddr...\n");
  $iaddr = inet_aton($IPAddr);
  $DNSname  = gethostbyaddr($iaddr, AF_INET);
  if (! defined $DNSname) 
  {
  	$DNSname = "DNS Failure";
  }
	
	logentry(" pinging $IPAddr...\n");
	$alive = ping(host => $IPAddr);
	if ($alive)
	{
		$alive = "Success";
	}
	else
	{
		$alive = "Fail";
	}
	logentry(" Ping test: $alive\n testing telnet...\n");
	PortTest ($IPAddr,23);
	$TelnetTest = $PortTest;
	logentry(" Telnet test: $TelnetTest\n testing SSH...\n");
	PortTest ($IPAddr,22);
	$SSHTest = $PortTest;
	logentry (" SSH test: $SSHTest\n Opening a SNMP connection to $IPAddr\n");
	($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr);
	if (!defined($session)) {
	    $errmsg = sprintf("Connect ERROR: %s.\n", $error);
	    logentry ("$errmsg");
		  $strOut = "$device\t$IPAddr\t$DNSname\t$error\t\t$alive\t$TelnetTest\t$SSHTest\n";
		  logentry ("$strOut");
	    print OUT $strOut;
	    $bError = 1;
	   }
	else
	{
		$result = $session->get_request($sysname);
		   if (!defined($result)) {
		   	  $error = $session->error;
		      $errmsg = "Sysname ERROR: $error.\n";
		      logentry ("$errmsg");
			  $strOut = "$device\t$IPAddr\t$DNSname\t$error\t\t$alive\t$TelnetTest\t$SSHTest\n";
			  logentry ("$strOut");
	      	  print OUT $strOut;
	      	  $bError = 1;
		   }
		   else
		   {
			$sname = $result->{$sysname};
			logentry ("Sysname: $sname\n");
			
			$result = $session->get_request($sysDescr);
			   if (!defined($result)) {
  		   	      $error = $session->error;
		          $errmsg = "SysDescr ERROR: $error.\n";
		          logentry ("$errmsg");
			      $strOut = "$device\t$IPAddr\t$DNSname\t$sname\t$error\t$alive\t$TelnetTest\t$SSHTest\n";
			      logentry ("$strOut");
	      	      print OUT $strOut;
	      	      $bError = 1;
			   }
			$sDescr = $result->{$sysDescr};
			logentry ("SysDescr: $sDescr\n");
		  }
	}
	if ($bError == 0)
	{
		$strOut = "$device\t$IPAddr\t$DNSname\t$sname\t$sDescr\t$alive\t$TelnetTest\t$SSHTest\n";
		logentry ("$strOut");
		print OUT $strOut;		  
	}		
	$session->close;
}
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
