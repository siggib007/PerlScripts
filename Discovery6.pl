###############################################################################################
# Subnet Discovery script                                                                     #
# Author: Siggi Bjarnason                                                                     #
# Date Authored: 01/06/2011                                                                   #
# This script will take in a CSV file of subnets and scan each IP in each of those subnets    #
# testing to see if there is a device which responds to common management protocols.          #
# It will perform the following reachability/response tests against each IP                   #
# - ICMP echo request (i.e. ping)                                                             #
# - DNS reverse look-up (i.e. is the IP in DNS and what is the name)                          #
# - SNMP (SysName and SysDescr)                                                               #
# - In addition to TCP ports tests defined in PortTestArray.                                  #
# Only those IP which responds to at least one test successfully will be written in a         #
# tab delimited file, with results of each test in a seperate column.                         #
###############################################################################################

# Start User configurable value variable section
use strict;
my ($TelnetTimeout, $SNMPTimeout, %SMTPHosts, %PortTestArray, $from, $to, $subject, %getOIDs);

$to = 'siggi.bjarnason@clearwire.com';
$from = 'CNEscript@clearwire.com';
$subject = "Discovery job outcome";

$PortTestArray{22} = "SSH";
$PortTestArray{23} = "Telnet";
$PortTestArray{80} = "HTTP";
$PortTestArray{443} = "HTTPS";

$SMTPHosts{"WA-WAN-SMTP-1"}= "172.27.0.125";
$SMTPHosts{"WA-WAN-SMTP-2"}= "172.27.0.126";
$SMTPHosts{"NOCTools"}= "172.25.200.20";
$SMTPHosts{"Nachoman"}= "172.25.200.100";
$SMTPHosts{"localhost"}= "127.0.0.1";

$TelnetTimeout = 6;
$SNMPTimeout = 3;

$getOIDs{"sysName"}     = '1.3.6.1.2.1.1.5.0';
$getOIDs{"sysDescr"}    = '1.3.6.1.2.1.1.1.0';
$getOIDs{"sysObjectID"} = '1.3.6.1.2.1.1.2.0';

#start fixed values and script
use Socket;
use Net::SNMP;
use Net::Ping::External qw(ping);
use Net::Telnet 3.00;
use Net::SMTP;
use English;
use Sys::Hostname;

my ($comstr, $session, $error, $result, $logfile, $errmsg, $progname, $t, $quad, %getOIDResults, $OIDResult);
my ($strOut, $InFile, $outfile, $IPAddr, $line, $alive, $PortTest, $SSHTest, $x, $SNMPTestCount);
my ($DNSname, $iaddr, $Subnet, $SubnetEnd, @subnetquads, $devType, $i, $StartTime, $StopTime, $relay, $PortTestCount);
my ($isec, $imin, $ihour, $iDiff, $iDays, $iDiff, $iHours, $iDiff, $iMins, $iSecs, $Perc, $pwd, %PortTestResults);
my ($Make, @strSplit, $City, $Market, @body, $CurrIP, $seq, $TotalIP, $timeEst, $strTimeEst, $email);
my ($InUse, $key, $value, $relayname, $host, $verbose, $bValid, $goodpar, @lines, @inArray);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$CurrIP = 0;
$InFile = "";
$outfile = "";
$comstr = "";
$verbose = 0;
$strTimeEst = "";

$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$host = hostname;

$PortTestCount = scalar(keys %PortTestArray);
$SNMPTestCount = scalar(keys %getOIDs);

print "\nThis script will take in a CSV file of subnets and scan each IP in each of those subnets.\n";
print "It will perform the following reachability/response tests against each IP, including $PortTestCount Port tests\n";
print " - ICMP echo request (i.e. ping)\n";
print " - DNS reverse look-up (i.e. is the IP in DNS and what is the name)\n";
foreach $key (sort keys %PortTestArray) 
{
    print " - Port $key ($PortTestArray{$key})\n";
}
foreach $key (sort keys %getOIDs) 
{
    print " - SNMP $key\n";
}

print "Each IP that receives a response on at least one of the tests is written to a tab separate file.\n\n";
print "Use 'perl $PROGRAM_NAME help' for syntax of optional arguments\n\n\n";

foreach $x (@ARGV)
{
	$goodpar = "false";
	@lines = split /=/, $x;
	if ($lines[0] eq "in")
	{
		$InFile = $lines[1];
		$InFile =~ s/\\/\//g;
		$goodpar = "true";
		print "found infile of $InFile\n";
	}
	if ($lines[0] eq "out")
	{
		$outfile = $lines[1];
		$outfile =~ s/\\/\//g;
		$goodpar = "true";
		print "found outfile of $outfile\n";
	}
	if ($lines[0] eq "pwd")
	{
		$comstr = $lines[1];
		$goodpar = "true";
		print "found comstr of $comstr\n";
	}
	if ($lines[0] eq "verbose")
	{
		$verbose = 1;
		$goodpar = "true";
		print "found verbosity level of verbose\n";
	}
	if ($lines[0] eq "email")
	{
		$email = $lines[1];
		if ($email eq "ok" or $email eq "no")
		{
			print "found email level of $email\n";
		}
		else
		{
			print "email parameter of $email is not recognized\n";
			$email = "";
		}
		$goodpar = "true";
	}
	if ($lines[0] eq "help")
	{
		$goodpar = "true";
		print "Usage: perl $PROGRAM_NAME in=infile out=outfile pwd=comstr [optional arugments]\n\n";
		print "InFile: A comma seperate file listing the target subnets\n";
		print "OutFile: filename, optionally with complete path, of where you want the tab seperated results saved.\n";
		print "comstr: The standard snmp community string.\n";
		print "Ex: perl $PROGRAM_NAME in=/home/jsmith/subnets.csv out=/home/jsmith/validdevices.txt public verbose\n\n";
		print "optional arguments:\n";
		print "verbose: output details about each test to the console,  by default only \n";
		print "         progress info is output to the console and details to a log\n\n";
		print "help: Prints out this message\n";
		print "format: describes how to properly compose and format the input file\n\n";
		print "email: Has two valid options: ok or no\n";
		print "       email=no: do not send email notification upon completion of script\n";
		print "       email=ok: do not confirm the address to which to send email notification upon completion of script\n";
		exit();
	}
	if ($lines[0] eq "format")
	{
		$goodpar = "true";
		print "Each line in the file should be a single subnet range and shall not exceed a /24 subnet\n";
		print "The format of the input file should be \n";
		print "Subnet start, Subnet End, City, Market\n\n";
		print "Subnet start: The first IP in a subnet to scan. Must be a valid non-multicast IP, with last octate between 1 and 254 inclusive\n";
		print "Subnet End: The last octate in the last IP of the subnet to be scanned. Must be larger than the last octate in subnet start\n";
		print "City: Description #1 for the log files. This serves no purpose other than label the subnet in the logs\n";
		print "Market: Description #1 for the log files. This serves no purpose other than label the subnet in the logs\n\n";
		print "For example to scan 10.41.107.1 through 10.41.107.10 and label it Seattle in Washington, the line should read like this\n";
		print "10.41.107.1,10,Washington,Seattle\n\n";
		exit();
	}
	if ($goodpar eq "false")
	{
		print "Invalid option $x  Try 'perl $PROGRAM_NAME help' for syntax\n\n";
	}
}

if ($InFile eq "")
{
	print "Please specify the name of the subnet list file:";
	$InFile = <STDIN>;
	chomp $InFile;
	$InFile =~ s/\\/\//g;
}

until (-e $InFile)
{
	print "The input file '$InFile' doesn't exists, please enter file name with complete path if nessisary:\n";
	$InFile = <STDIN>;
	chomp $InFile;
	$InFile =~ s/\\/\//g;	
}

if ($outfile eq "")
{
	print "Please specify output file name: ";
	$outfile = <STDIN>;
	chomp $outfile;
	$outfile =~ s/\\/\//g;
}
if ($comstr eq "")
{
	print "Please specify the standard SNMP community string that should be used: ";
	$comstr = <STDIN>;
	chomp $pwd;
}

print "starting $PROGRAM_NAME at $mon/$mday/$year $hour:$min\n";
$t = Net::Telnet->new( Timeout => $TelnetTimeout, Errmode => "return" );
$StartTime = time();
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
logentry ("initializing $PROGRAM_NAME ....\n",0);
logentry ("reading from $InFile ...\n",0);
logentry ("outputing to $outfile ... \n",0);


if ($email eq "no")
{
	logentry ("No email notification requested\n",0);
}
else
{
	while (($key,$value) = each %SMTPHosts) 
	{
		PortTest ($value,25);
		if ($PortTest eq "Success")
		{
			$relay = $value;
			$relayname = $key;
			logentry ("$key $value responds on port 25, using as relay server\n\n\n",0);
			last;
		}
		else
		{
			logentry ("$key $value does not respond on port 25.\n",1);
		}
	}
	
	if ($relay eq "")
	{
		print "None of the SMTP servers configured are responding. \n";
		print "Please provide a valid server name or IP or enter to disable email notification: \n";
		$relay = <STDIN>;
		chomp $relay;
		PortTest ($relay,25);
		until (($PortTest eq "Success") or ($relay eq ""))
		{
			print "$relay does not respond to SMTP. \n";
			print "Please provide a valid SMTP server name or IP or enter to disable email notification: \n";
			$relay = <STDIN>;
			chomp $relay;
			PortTest ($relay,25);
		}
	}
	
	if ($email ne "ok")
	{
		if ($to ne "")
		{
			print "This script has been preconfigured to send notification mail to \n$to\n";
			print "To accept that hit enter, or enter a new email address:";
			$line = <STDIN>;
			chomp $line;
			if ($line ne "")
			{
				$to = $line;
			}
		}
		else
		{
			print "No email address destination has been configure.\n Please enter a notification email address\n";
			print " or hit enter to disable email notification: ";
			$to = <STDIN>;
			chomp $to;
		}
	}
}
open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

$TotalIP = 0;


$strOut = "IP\tDNS_Name\tType\tMake\tPing\t";
foreach $key (sort keys %PortTestArray) 
{
	$strOut .=  "$PortTestArray{$key}\t";
}
foreach $key (sort keys %getOIDs) 
{
	$strOut .=  "$key\t";
}


$strOut = substr $strOut,0,-1;
$strOut .= "\n";
#logentry ("$strOut",1);
print OUT $strOut;
$i = 0;
foreach $line (<IN>)
{
	chomp($line);
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	if ($line ne "")
	{	
		($Subnet, $SubnetEnd, $City, $Market)  = split (/,/, $line);
		@subnetquads = split(/\./, $Subnet);
		foreach $quad (@subnetquads)
		{
			$bValid = "false";
			if (($quad >= 0) and ($quad <= 255))
			{
				$bValid = "true";
			}
			else
			{
				last;
			}
		}
		if (($subnetquads[0] == 0) or ($subnetquads[0] >= 224))
		{
			$bValid = "false";
		} 
		if (($subnetquads[3] == 0) or ($subnetquads[3] == 255))
		{
			$bValid = "false";
		} 
		if (($subnetquads[3] >= $SubnetEnd) or ($SubnetEnd > 254))
		{
			$bValid = "false";
		} 
		if ($bValid eq "true")
		{
			$inArray[$i] = $line;
			$TotalIP += $SubnetEnd - $subnetquads[3] + 1;
			$i++;
		}
		else
		{
			logentry("$line contains invalid subnet details and is being skipped\n\n\n",0);
		}
	}
}
$timeEst = ($PortTestCount * ($TelnetTimeout + 1)) + ($SNMPTestCount * $SNMPTimeout) + 10;
$isec = $timeEst * $TotalIP;
$imin = $isec/60;
$ihour = $imin/60;
$iDiff = $isec;
$iDays = int($iDiff/86400);
$iDiff -= $iDays * 86400;
$iHours = int($iDiff/3600);
$iDiff -= $iHours * 3600;
$iMins = int($iDiff/60);
$iSecs = $iDiff - $iMins * 60;

if ($iDays > 0)
{
	$strTimeEst .= "$iDays days, ";
}
if ($iHours > 0)
{
	$strTimeEst .= "$iHours hours, ";
}
if ($iMins > 0)
{
	$strTimeEst .= "$iMins minutes and ";
}
$strTimeEst .= "$iSecs seconds";

logentry ("infile contains $i subnets, for a total of $TotalIP IP's\n\n",0);
logentry ("with $PortTestCount Port tests configured and a timeout value of $TelnetTimeout seconds\n",0);
logentry ("plus $SNMPTestCount SNMP tests with a timeout value of $SNMPTimeout seconds and 10 second timeout on ping\n",0);
logentry ("each IP could take anywhere from 5 to $timeEst seconds.\n",0);
logentry ("with an infile containing $TotalIP IP's, it could be $strTimeEst until this is completed\n\n\n",0);

foreach $line (@inArray)
{
	($Subnet, $SubnetEnd, $City, $Market)  = split (/,/, $line);
	@subnetquads = split(/\./, $Subnet);
	$Subnet .= " - " . $SubnetEnd;
	logentry("processing subnet $Subnet for $Market in $City...\n",0);
	for ($i = $subnetquads[3]; $i <= $SubnetEnd; $i++) 
	{
		undef $devType;
		undef $Make;
		undef %PortTestResults;
		undef %getOIDResults;
		$InUse = 0;
		$IPAddr = $subnetquads[0] . "." . $subnetquads[1] . "." . $subnetquads[2] .  "." . $i;
		$CurrIP ++;
		$Perc = ($CurrIP / $TotalIP) * 100;
		$Perc = sprintf("%.3f%%", $Perc);
		logentry("processing address $IPAddr for $Market in $City which is IP $CurrIP out of $TotalIP which is $Perc...\n",0);
		logentry("Pinging $IPAddr ...\n",1);
		$alive = ping(host => $IPAddr);
		if ($alive)
		{
			$alive = "Success";
			logentry(" Ping test: $IPAddr responds to ping...\n",1);	
			$InUse = 1;
		}
		else
		{
			logentry(" Ping test: $IPAddr does not respond to ping...\n",1);	
			$alive = "Fail";
		}
		logentry ("Attempting to resolve $IPAddr in DNS ... \n",1);
  	$iaddr = inet_aton($IPAddr);
  	$DNSname  = gethostbyaddr($iaddr, AF_INET);
  	if (! defined $DNSname) 
  	{
  		$DNSname = "Reverse DNS Failure";
  		logentry("$DNSname\n",1);
  	}
  	else
  	{
  		@strSplit = split(/-/,$DNSname);
  		$devType = $strSplit[2] . " " . $strSplit[3];
  		logentry ("Reverse DNS Successful, DNSName: $DNSname\n",1);
  		logentry ("DNS DevType: $devType\n",1);
  		$InUse = 1;
  	}

		foreach $key (sort keys %PortTestArray)  
		{
			$value = $PortTestArray{$key};
			logentry(" testing $value ...\n",1);
			PortTest ($IPAddr,$key);
			$PortTestResults{$key} = $PortTest;
			logentry(" $value test: $PortTest\n",1);
		}

		logentry (" Opening a SNMP connection to $IPAddr\n",1);
		($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr, timeout => $SNMPTimeout);
		if (!defined($session)) 
		{
			$errmsg = sprintf("Connect ERROR: %s.", $error);
			logentry ("$errmsg\n",1);
		}
		else
		{
			$error = "";
			$errmsg = "";
			logentry (" SNMP connection to $IPAddr established\n",1);
			foreach $key (sort keys %getOIDs)  
			{
				$value = $getOIDs{$key};
				logentry("Issuing a SNMP get for $key ... \n",1);
				$result = $session->get_request($value);
		 		if (!defined($result)) 
		 		{
		 			$error = $session->error;
		 			$errmsg = "SNMP ERROR: $error.";
		 			logentry ("$errmsg\n",1);
	   			$getOIDResults{$key} = $errmsg;
	   			last;
		 		}
		 		else
		 		{
		 			$OIDResult  = $result->{$value};
					$OIDResult =~ s/\n/ /g;
					$OIDResult =~ s/\t/ /g;
					$OIDResult =~ s/\r/ /g;
		 			logentry ("$key: $OIDResult\n",1);
		 			$getOIDResults{$key} = $OIDResult;
		 			$InUse = 1;
		 		}
			}
			if (!defined($devType) and $getOIDResults{"sysName"} !~ /.*ERROR.*/)
			{
	  		@strSplit = split(/-/,$getOIDResults{"sysName"});
  			$devType = $strSplit[2] . " " . $strSplit[3];
  			logentry ("SysName DevType: $devType\n",1);
  		}
			if ($getOIDResults{"sysDescr"} !~ /.*ERROR.*/)
			{
				($Make) = split (/ /, $getOIDResults{"sysDescr"});
			}
		}
		logentry ("Done processing $IPAddr .. \n",1);
		$strOut = "$IPAddr\t$DNSname\t$devType\t$Make\t$alive\t";
		foreach $key (sort keys %PortTestResults) 
		{
			$strOut .=  "$PortTestResults{$key}\t";
		}
		foreach $key (sort keys %getOIDResults) 
		{
			$strOut .=  "$getOIDResults{$key}\t";
		}		
		$strOut = substr $strOut,0,-1;
		$strOut .= "\n";
		logentry ("$strOut",1);
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
logentry ("Stopped processing at $mon/$mday/$year $hour:$min\n",0 );
logentry ("Processing took $iDays days, $iHours hours, $iMins minutes and $iSecs seconds.\n",0);
logentry ("elapse time $isec seconds; $imin minutes; $ihour hours.\n",0);
logentry ("Done. Exiting normally!\n",0);

if (($relay ne "") and ($to ne ""))
{
	push @body, "$host has completed processing $InFile and the results are stored in $outfile\n";
	push @body, "\nStopped processing at $mon/$mday/$year $hour:$min\n";
	push @body, "Processing took $iDays days, $iHours hours, $iMins minutes and $iSecs seconds.\n";
	push @body, "elapse time $isec seconds; $imin minutes; $ihour hours.\n";
	send_mail();
}
else
{
	logentry ("No SMTP server configured or no notification email provided, can't send email\n");
}

close(LOG);
exit 0;

sub logentry
	{
		my($outmsg, $LogLevel) = @_;
		
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year = $year+1900;
		$min = substr("0$min",-2);
		$mon = $mon + 1;
		$sec = substr("0$sec",-2);
		
		if ($LogLevel <= $verbose)
		{
			print "$mon/$mday/$year $hour:$min:$sec $outmsg";
		}
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
