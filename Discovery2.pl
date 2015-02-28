use strict;
use Socket;
use Net::SNMP;
use Net::Ping::External qw(ping);
use Net::Telnet 3.00;
use Net::SMTP;
use English;
use Sys::Hostname;
my ($comstr,$session,$error,$sysname, $sysDescr, $result, $numin, $logfile, $errmsg, $progname, $t);
my ($sname, $sDescr, $strOut, $InFile, $outfile, $IPAddr, $line, $bError, $alive, $PortTest, $SSHTest);
my ($DNSname, $iaddr, $Subnet, $Q1, $Q2, $Q3, $Q4, $devType, $i, $StartTime, $StopTime, $relay, $to);
my ($isec, $imin, $ihour, $iDiff, $iDays, $iDiff, $iHours, $iDiff, $iMins, $iSecs, $TelnetTest, $Perc);
my ($from, $iLC, $Make, @strSplit, $City, $Market, $subject, @body, $CurrIP, $seq, $TotalIP,$HTTPTest);
my ($HTTPSTest, $InUse, %SMTPHosts, $key, $value, $relayname, $host);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$host = hostname;

$SMTPHosts{"WA-WAN-SMTP-1"}= "172.27.0.125";
$SMTPHosts{"WA-WAN-SMTP-2"}= "172.27.0.126";
$SMTPHosts{"NOCTools"}= "172.25.200.20";
$SMTPHosts{"Nachoman"}= "172.25.200.100";
$SMTPHosts{"localhost"}= "127.0.0.1";

$to = "siggi.bjarnason\@clearwire.com";
$from = "siggi.bjarnason\@clearwire.com";
$subject = "Discovery job outcome";

$sysname = '1.3.6.1.2.1.1.5.0';
$sysDescr = '1.3.6.1.2.1.1.1.0';
$CurrIP = 0;

$numin = scalar(@ARGV);
if ($numin != 3)
{
	print "\nInvalid usage: Three arguments are required and you supplied $numin\n\n";
	print "Correct usage: perl $PROGRAM_NAME infile outfile pwd\n\n";
	print "InFile: A comma seperate file listing the target subnets\n";
	print "OutFile: filename with complete path of where you want the results saved.\n";
	print "pwd: The standard snmp community string.\n\n";
	print "Ex: perl $PROGRAM_NAME /home/jsmith/subnets.csv /home/jsmith/validdevices.txt public\n\n";
	exit();
}
	
print "starting $PROGRAM_NAME at $mon/$mday/$year $hour:$min\n";
$StartTime = time();
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
$t = Net::Telnet->new( Timeout => 6, Errmode => "return" );
$InFile = $ARGV[0];
$outfile = $ARGV[1];
$comstr = $ARGV[2];
$iLC = `wc -l $InFile`;
($iLC) = split(/ /,$iLC);
$TotalIP = $iLC * 254;
while (($key,$value) = each %SMTPHosts) 
{
#	print "$key $value\n";
	PortTest ($value,25);
	if ($PortTest eq "Success")
	{
		$relay = $value;
		$relayname = $key;
		logentry ("$key $value responds on port 25, using as relay server\n\n\n");
		last;
	}
	else
	{
		logentry ("$key $value does not respond on port 25.\n");
	}
}

logentry ("infile contains $iLC 24bit subnets, which is $TotalIP IP's\n");

$InFile =~ s/\\/\//g;

$outfile =~ s/\\/\//g;

open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

$strOut = "IP\tDNS_Name\tSysName\tType\tMake\tPing\tTelnet\tSSH\tPort80\tPort443\tSysDescr\n";
logentry ("$strOut");
print OUT $strOut;

foreach $line (<IN>)
{
	chomp($line);
	($Subnet, $City, $Market)  = split (/,/, $line);
	logentry("processing subnet $Subnet for $Market in $City...\n");
	($Q1, $Q2, $Q3, $Q4) = split(/\./, $Subnet);
	for ($i = 1; $i < 255; $i++) 
	{
		$bError = 0;
		undef $devType;
		undef $Make;
		undef $sname;
		undef $sDescr;
		$InUse = 0;
		$IPAddr = $Q1 . "." . $Q2 . "." . $Q3 .  "." . $i;
		$CurrIP ++;
		$Perc = ($CurrIP / $TotalIP) * 100;
		$Perc = sprintf("%.3f%%", $Perc);
		logentry("processing address $IPAddr for $Market in $City which is IP $CurrIP out of $TotalIP which is $Perc...\n");
		$alive = ping(host => $IPAddr);
		if ($alive)
		{
			$alive = "Success";
			logentry(" Ping test: $IPAddr responds to ping...\n");	
			$InUse = 1;
		}
		else
		{
			$alive = "Fail";
		}
		
  	$iaddr = inet_aton($IPAddr);
  	$DNSname  = gethostbyaddr($iaddr, AF_INET);
  	if (! defined $DNSname) 
  	{
  		$DNSname = "Reverse DNS Failure";
  	}
  	else
  	{
  		@strSplit = split(/-/,$DNSname);
  		$devType = $strSplit[2] . " " . $strSplit[3];
  		logentry ("DNS DevType: $devType\n");
  		$InUse = 1;
  	}
		logentry(" testing telnet...\n");
		PortTest ($IPAddr,23);
		$TelnetTest = $PortTest;
		logentry(" Telnet test: $TelnetTest\n");
		logentry(" testing port 80...\n");
		PortTest ($IPAddr,80);
		$HTTPTest = $PortTest;
		logentry(" port 80 test: $HTTPTest\n");
		logentry(" testing port 443...\n");
		PortTest ($IPAddr,443);
		$HTTPSTest = $PortTest;
		logentry(" Port 443 test: $HTTPSTest\n");
		logentry(" testing SSH...\n");
		PortTest ($IPAddr,22);
		$SSHTest = $PortTest;
		logentry (" SSH test: $SSHTest\n Opening a SNMP connection to $IPAddr\n");
		($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr, timeout => 3);
		if (!defined($session)) 
		{
			$errmsg = sprintf("Connect ERROR: %s.", $error);
			logentry ("$errmsg\n");
			$bError = 1;
			$sname = $errmsg;
		}
		else
		{
			$result = $session->get_request($sysname);
		  if (!defined($result)) 
		  {
		  	$error = $session->error;
		  	$errmsg = "Sysname ERROR: $error.";
		  	logentry ("$errmsg\n");
	    	$bError = 1;
	    	$sname = $errmsg;
		  }
		  else
		  {
				$sname = $result->{$sysname};
				logentry ("Sysname: $sname\n");
				if (!defined($devType))
				{
	  			@strSplit = split(/-/,$sname);
  				$devType = $strSplit[2] . " " . $strSplit[3];
  				logentry ("SysName DevType: $devType\n");
  			}
				$InUse = 1;
				$result = $session->get_request($sysDescr);
		  	if (!defined($result)) 
		  	{
  	  		$error = $session->error;
		  	  $errmsg = "SysDescr ERROR: $error.\n";
		  	  logentry ("$errmsg");
	    	  $bError = 1;
	    	  $sDescr = $errmsg;
		  	}
				$sDescr = $result->{$sysDescr};
				$sDescr =~ s/\n/ /g;
				$sDescr =~ s/\t/ /g;
				$sDescr =~ s/\r/ /g;
				($Make) = split (/ /, $sDescr);
				logentry ("SysDescr: $sDescr\n");
		 	}
		}
		$strOut = "$IPAddr\t$DNSname\t$sname\t$devType\t$Make\t$alive\t$TelnetTest\t$HTTPTest\t$HTTPSTest\t$SSHTest\t$sDescr\n";
		logentry ("$strOut");
		if ($InUse == 1)
		{
			print OUT $strOut;
		}
		$session->close;
		
	}
}
$StopTime = time;
$isec = $StopTime - $StartTime;
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

push @body, "$host has completed processing $InFile and the results are stored in $outfile\n";
push @body, "\nStopped processing at $mon/$mday/$year $hour:$min\n";
push @body, "Processing took $iDays days, $iHours hours, $iMins minutes and $iSecs seconds.\n";
push @body, "elapse time $isec seconds; $imin minutes; $ihour hours.\n";
send_mail();

close(LOG);
exit 0;

sub logentry
	{
		my($outmsg) = @_;
		
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year = $year+1900;
		$min = substr("0$min",-2);
		$mon = $mon + 1;
		$sec = substr("0$sec",-2);
		
		print "$mon/$mday/$year $hour:$min:$sec $outmsg";
		print LOG "$mon/$mday/$year $hour:$min:$sec $outmsg";
	}

sub PortTest
	{
		my($hostname, $port) = @_;
		if (defined($t->open(Host => $hostname, Port => $port)))
			{
				$PortTest="Success";
				$InUse = 1;
			}
		else
			{
				$PortTest="Fail";
			}
	}

sub send_mail 
{
my ($smtp, $body);
	
	$smtp = Net::SMTP->new($relay, Debug => 0); # Set Debug to 1 if you have any problems
	if (!defined($smtp))
	{
		logentry ("Failed to open mail session to $relay\n");
		close (LOG) or warn "error while closing log file $logfile: $!" ;		
		exit 4;
	}
	else
	{
		$smtp->mail($from) ;
		$smtp->to($to) ;
		
		$smtp->data() ;
		$smtp->datasend("To: $to\n") ;
		$smtp->datasend("From: $from\n") ;
		$smtp->datasend("Subject: $subject\n") ;
		$smtp->datasend("\n") ;
		
		foreach $body (@body) 
		{
			$smtp->datasend("$body") ;
		}
		$smtp->dataend() ;
		$smtp->quit() ;
	}
	undef $smtp;
}	
