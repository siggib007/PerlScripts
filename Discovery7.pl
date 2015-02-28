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
# pass the word "help" in as an argument to get usage instructions.                           #
###############################################################################################

# Start User configurable value variable section
use strict;
my ($TelnetTimeout, $SNMPTimeout, %SMTPHosts, %PortTestArray, $from, $to, $subject, %getOIDs, $LogPath);
my ($strSQL, $DBName, $DBHost, $DBUser, $DBpwd, $SubnetTblName, %PortFieldArray, %getOIDFields);

#$LogPath = "logs";
$LogPath = "/var/log/scripts/discovery";
$to = 'siggi.bjarnason@clearwire.com';
$from = 'CNEscript@clearwire.com';
$subject = "Discovery job outcome";

#$DBHost = "192.168.1.10";
$DBHost = "localhost";
$DBName = "inventory";
$SubnetTblName = "tblsubnets";
$DBUser = "script";
$DBpwd = "test123";

$PortTestArray{22} = "SSH";
$PortTestArray{23} = "Telnet";
$PortTestArray{80} = "HTTP";
$PortTestArray{443} = "HTTPS";

$getOIDs{"sysName"}     = "1.3.6.1.2.1.1.5.0";
$getOIDs{"sysDescr"}    = "1.3.6.1.2.1.1.1.0";
$getOIDs{"sysObjectID"} = "1.3.6.1.2.1.1.2.0";

$TelnetTimeout = 6;
$SNMPTimeout = 3;

$SMTPHosts{"WA-WAN-SMTP-1"}= "172.27.0.125";
$SMTPHosts{"WA-WAN-SMTP-2"}= "172.27.0.126";
$SMTPHosts{"NOCTools"}= "172.25.200.20";
$SMTPHosts{"Nachoman"}= "172.25.200.100";
$SMTPHosts{"localhost"}= "127.0.0.1";

$PortFieldArray{22} = "vcSSH";
$PortFieldArray{23} = "vcTelnet";
$PortFieldArray{80} = "vcHTTP";
$PortFieldArray{443} = "vcHTTPS";

$getOIDFields{"sysName"}     = "vcSysName";
$getOIDFields{"sysDescr"}    = "vcSysDescr";
$getOIDFields{"sysObjectID"} = "vcSysObjectID";

###############################################################################################
#End user configurable section.                                                               #
#Begin Script section. Do not modify below unless you know what you are doing.                #
###############################################################################################

#Script initialization 
use Socket;
use Net::SNMP;
use Net::Ping::External qw(ping);
use Net::Telnet 3.00;
use Net::SMTP;
use English;
use Sys::Hostname;
use DBI();
use POSIX;
use Data::UUID;

my ($comstr, $session, $error, $result, $logfile, $errmsg, $progname, $t, $quad, %getOIDResults, $OIDResult);
my ($strOut, $InFile, $outfile, $IPAddr, $line, $alive, $PortTest, $SNMPTest, $x, $SNMPTestCount, $SubNetCount);
my ($DNSname, $iaddr, $Subnet, $SubnetEnd, @subnetquads, $devType, $i, $StartTime, $StopTime, $relay, $iDevID);
my ($isec, $imin, $ihour, $iDiff, $iDays, $iDiff, $iHours, $iDiff, $iMins, $iSecs, $Perc, $pwd, %PortTestResults);
my ($Make, @strSplit, $City, $Market, @body, $CurrIP, $seq, $TotalIP, $timeEst, $strTimeEst, $email, $bValid);
my ($InUse, $key, $value, $relayname, $host, $verbose, $goodpar, @lines, @inArray, $sth, $dbh, $DBin, $DBout);
my ($inCount, $NumScripts, $StartLimit, $LimitCount, $ScriptInst, @OutValues, $LogLevel, $ResIn, $PortTestCount);
my ($strUUID, $strTimeElapse, $strEstdt, $ElapseSec, $iCurrSubnet, $ug, $scriptFullName, $ShortName, @tmp);
my ($pathparts, $SubNets, $Where);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$ug = new Data::UUID;
$strUUID  = $ug->create_str();

$CurrIP = 0;
$InFile = "";
$outfile = "";
$comstr = "";
$verbose = 0;
$strTimeEst = "";
$TotalIP = 0;
$SubNetCount = 0;
$LogLevel = 1;
$verbose = 1;
$relay = "";
$ScriptInst = 1;
$NumScripts = 1;
$iCurrSubnet = 0;

$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$host = hostname;
$scriptFullName = $PROGRAM_NAME;
$scriptFullName =~ s/\\/\//g;	
@tmp = split(/\//,$scriptFullName);
$pathparts = scalar @tmp;
$ShortName = $tmp[$pathparts-1];

$PortTestCount = scalar(keys %PortTestArray);
$SNMPTestCount = scalar(keys %getOIDs);

#Start script section

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

print "Each IP that receives a response on at least one of the tests is written to a tab separate output file.\n\n";
print "Usage: perl $ShortName [in=infile | dbin] [out=outfile | dbout] pwd=comstr [arugments]\n\n";

foreach $x (@ARGV)
{
	$goodpar = "false";
	@lines = split /=/, $x;
	if ($lines[0] eq "dbin")
	{
		$DBin = "true";
		$goodpar = "true";
		($ScriptInst,$NumScripts) = split /,/,$lines[1];
		print "found database input directive with $ScriptInst,$NumScripts\n";
	}
	if ($lines[0] eq "in")
	{
		$InFile = $lines[1];
		$InFile =~ s/\\/\//g;
		$goodpar = "true";
		print "found infile of $InFile\n";
	}
	if ($lines[0] eq "dbout")
	{
		$DBout = "true";
		$goodpar = "true";
		print "found database output directive\n";
	}
	if ($lines[0] eq "out")
	{
		$outfile = $lines[1];
		$outfile =~ s/\\/\//g;
		$goodpar = "true";
		print "found outfile of $outfile\n";
	}
	if ($lines[0] eq "net")
	{
		$SubNets = $lines[1];
		$goodpar = "true";
		print "found subnets of $SubNets\n";
	}
	if ($lines[0] eq "pwd")
	{
		$comstr = $lines[1];
		$goodpar = "true";
		print "found comstr of $comstr\n";
	}
	if ($lines[0] eq "con")
	{
		$verbose = $lines[1];
		$goodpar = "true";
		print "found console log level of $verbose\n";
	}
	if ($lines[0] eq "log")
	{
		$LogLevel = $lines[1];
		$goodpar = "true";
		print "found file log level of $LogLevel\n";
	}
	if ($lines[0] eq "table")
	{
		$SubnetTblName = $lines[1];
		$goodpar = "true";
		print "found subnet table of $LogLevel\n";
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
		print "InFile: A comma seperate file listing the target subnets\n";
		print "OutFile: filename, optionally with complete path, of where you want the tab seperated results saved.\n";
		print "comstr: The standard snmp community string.\n";
		print "dbin: Take input from a preconfigured database table.\n";
		print "      Optionally can be followed by two comma seperated numbers\n";
		print "      for example: dbin=3,10\n";
		print "      This means that this script is script 3 of 10 scripts currently running.\n";
		print "      So split the input list into 10 pieces and process piece 3.\n";
		print "dbout: save the results to a preconfigured database table\n\n";
		print "Ex: perl $ShortName in=/home/jsmith/subnets.csv out=/home/jsmith/validdevices.txt public con=0 log=2\n";
		print "Ex: perl $ShortName dbin dbout public con=0 log=2\n";
		print "Ex: perl $ShortName in=/home/jsmith/subnets.csv dbout public con=0 log=2\n\n";
		print "optional arguments:\n\n";
		print "help: Prints out this message\n\n";
		print "con: The level of details to output about each test to the console\n";
		print "         0: Only basic startup information is written to the console\n";
		print "         1: (default) Minimal log information, just progress info\n";
		print "         2: Normal log information, including test information from each test\n";
		print "         3: Debug log information, all details including headers, SQL statements, \n";
		print "             what's written to output files, etc.\n\n";
		print "log: The amount of details to write to the logs: \n";
		print "     0: Minimal log information, just progress info\n";
		print "     1: (default) Normal log information, including test information from each test\n";
		print "     2: Debug log information, all details including headers, SQL statements, \n";
		print "        what's written to output files, etc.\n\n";
		print "format: describes how to properly compose and format the comma seperate target subnet input file\n\n";
		print "email: Has two valid options: ok or no\n";
		print "       email=no: do not send email notification upon completion of script\n";
		print "       email=ok: do not confirm the address to which to send email notification upon completion of script\n\n";
		print "table: specifies name of database table or view to pull from\n";
		print "net:   specifies comma seperate list of subnetID's to query, use in conjunction with dbin\n";
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
		print "Invalid option $x \n\n";
		exit();
	}
}

print "Use 'perl $ShortName help' for more usage details including optional arguments\n\n\n";

if ($ScriptInst == "")
{
	$ScriptInst = 1;
}
if ($NumScripts == "")
{
	$NumScripts = 1;
}

if ($ScriptInst > $NumScripts)
{
	print "This is script $ScriptInst out of $NumScripts, which doesn't make sense. Exiting\n";
	exit();
}

if ($ScriptInst <1 or $NumScripts < 1)
{
	print "This is script $ScriptInst out of $NumScripts, which doesn't make sense. Both numbers need to be greater than zero Exiting\n";
	exit();
}

if ($LogLevel < 0 or $LogLevel > 2)
{
	print "File Log level of $LogLevel is not valid, resetting to default\n";
	$LogLevel = 1;
}

if ($verbose < 0 or $verbose > 3)
{
	print "Console Log level of $verbose is not valid, resetting to default\n";
	$verbose = 1;
}

if ($DBin ne "true")
{
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
}

if ($DBout ne "true")
{
	if ($outfile eq "")
	{
		print "Please specify output file name: ";
		$outfile = <STDIN>;
		chomp $outfile;
		$outfile =~ s/\\/\//g;
	}
}

if ($comstr eq "")
{
	print "Please specify the standard SNMP community string that should be used: ";
	$comstr = <STDIN>;
	chomp $pwd;
}

$StartTime = time();

$seq = 0;
($progname) = split(/\./,$ShortName);
$logfile = "$LogPath/$progname-$ScriptInst-$seq.log";
while (-e $logfile)
{
	print "$logfile in use, increasing suffix\n";
	$seq ++;
	$logfile = "$LogPath/$progname-$ScriptInst-$seq.log";
}
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("starting $ShortName at $mon/$mday/$year $hour:$min\n\n",0,0);
logentry ("Script $ScriptInst out of $NumScripts\n\n",0,0);

if ($DBin eq "true" or $DBout eq "true")
{
	$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                      "$DBUser", "$DBpwd",
                      {'RaiseError' => 1});
}

$t = Net::Telnet->new( Timeout => $TelnetTimeout, Errmode => "return" );


if ($email eq "no")
{
	logentry ("No email notification requested\n",0,0);
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
			logentry ("$key $value responds on port 25, using as relay server\n\n\n",0,0);
			last;
		}
		else
		{
			logentry ("$key $value does not respond on port 25.\n",2,1);
		}
	}
	
	if ($relay eq "")
	{
		print "None of the SMTP servers configured are responding. \n";
		print "Please provide a valid server name or IP or press enter to disable email notification: \n";
		$relay = <STDIN>;
		chomp $relay;
		if ($relay ne "")
		{
			PortTest ($relay,25);
			until ($PortTest eq "Success")
			{
				print "$relay does not respond to SMTP. \n";
				print "Please provide a valid SMTP server name or IP or press enter to disable email notification: \n";
				$relay = <STDIN>;
				chomp $relay;
				PortTest ($relay,25);
			}
		}
	}
	
	if ($email ne "ok")
	{
		if ($to ne "")
		{
			print "This script has been preconfigured to send notification mail to \n$to\n";
			print "To accept that press enter, or type in a new email address:";
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
			print " or press enter to disable email notification: ";
			$to = <STDIN>;
			chomp $to;
		}
	}
}

if ($DBin ne "true")
{
	open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";
	logentry ("reading from $InFile ...\n",0,0);
	foreach $line (<IN>)
	{
		chomp($line);
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		if ($line ne "")
		{	
			($Subnet, $SubnetEnd, $City, $Market)  = split (/,/, $line);
	  	$bValid = SubnetValidate ($Subnet, $SubnetEnd, $City, $Market);
	  	if ($bValid eq "true")
	  	{
				$SubNetCount++
	  	}
		}
	}
}
else
{
	logentry ("reading from database ... \n",0,0);
	if ($SubNets ne "")
	{
		$Where = " where iSubnetID in ($SubNets) ";
	}
	else
	{
		$Where = "";
	}
	$strSQL = "SELECT count(*) as SubNetCount FROM $SubnetTblName";
	$sth = $dbh->prepare($strSQL);
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref()) 
	{
		$inCount = $ref->{'SubNetCount'};
	}
#	if ($inCount < $NumScripts)
#	{
#		print "Can't split $inCount amongst $NumScripts. You should have no more than $inCount scripts for this load.";
#		print "Exiting...\n";
#		exit();
#	}
	if ($NumScripts == 1)
	{
		$LimitCount = $inCount;
		$StartLimit = 0;
	}
	else
	{
		$LimitCount = ceil($inCount / $NumScripts);
		$StartLimit = ($ScriptInst - 1) * $LimitCount;
	}
	$strSQL = "SELECT * FROM $SubnetTblName $Where limit $StartLimit, $LimitCount";
	logentry ("$strSQL\n",3,2);
	$sth = $dbh->prepare($strSQL);
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref()) 
	{
	  $Subnet = $ref->{'vcSubnet'}; 
	  $SubnetEnd = $ref->{'iSubnetEnd'}; 
	  $City = $ref->{'vcRegion'}; 
	  $Market = $ref->{'vcMarket'};
	  $bValid = SubnetValidate ($Subnet, $SubnetEnd, $City, $Market);
	  if ($bValid eq "true")
	  {
			$SubNetCount++
	  }
	}
}

if ($DBout ne "true")
{
	open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
	logentry ("outputing to $outfile ... \n",0,0);
	$strOut = "IP\tDNS_Name\tType\tMake\tPing\tSNMP\t";
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

	logentry ("$strOut",3,2);
	print OUT $strOut;
	$ResIn = $outfile;
}
else
{
	logentry ("outputing to database ... \n",0,0);
	$ResIn = "database";
}


$i = 0;
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

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($StartTime + $isec);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$sec = substr("0$sec",-2);
$strEstdt = "$year-$mon-$mday $hour:$min:$sec";
$strSQL = "INSERT INTO tblStatus (vcUUID,iSubnetCount,iIPCount,dtStart,dtEstEnd,vcHost,iInst,iScriptCount,dtUpdatedAt)";
$strSQL .= "VALUES ('$strUUID',$SubNetCount,$TotalIP,now(),'$strEstdt','$host',$ScriptInst,$NumScripts,now());";
logentry ("$strSQL\n",3,2);
$dbh->do($strSQL);

logentry ("infile contains $SubNetCount subnets, for a total of $TotalIP IP's\n\n",0,0);
logentry ("with $PortTestCount Port tests configured and a timeout value of $TelnetTimeout seconds\n",0,0);
logentry ("plus $SNMPTestCount SNMP tests with a timeout value of $SNMPTimeout seconds and 10 second timeout on ping\n",0,0);
logentry ("each IP could take anywhere from 5 to $timeEst seconds.\n",0,0);
logentry ("with an infile containing $TotalIP IP's, it could be $strTimeEst until this is completed\n\n\n",0,0);

foreach $line (@inArray)
{
	$iCurrSubnet ++;
	($Subnet, $SubnetEnd, $City, $Market)  = split (/,/, $line);
	@subnetquads = split(/\./, $Subnet);
	$Subnet .= " - " . $SubnetEnd;
	logentry("processing subnet $Subnet for $Market in $City...\n",1,0);
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
		$ElapseSec = time() - $StartTime;
		$strSQL = "update tblStatus set dtUpdatedAt=now(), iCurrIPNo = $CurrIP, iElapseSec = $ElapseSec, iCurrSubnet = $iCurrSubnet, ";
		$strSQL .= "vcMarket = '$Market', vcCity = '$City' where vcUUID = '$strUUID';";		
		logentry ("$strSQL\n",3,2);
		$dbh->do($strSQL);		
		logentry("processing address $IPAddr for $Market in $City which is IP $CurrIP out of $TotalIP which is $Perc...\n",1,0);
		logentry("Pinging $IPAddr ...\n",2,1);
		$alive = ping(host => $IPAddr);
		if ($alive)
		{
			$alive = "Success";
			logentry(" Ping test: $IPAddr responds to ping...\n",2,1);	
			$InUse = 1;
		}
		else
		{
			logentry(" Ping test: $IPAddr does not respond to ping...\n",2,1);	
			$alive = "Fail";
		}
		logentry ("Attempting to resolve $IPAddr in DNS ... \n",2,1);
  	$iaddr = inet_aton($IPAddr);
  	$DNSname  = gethostbyaddr($iaddr, AF_INET);
  	if (! defined $DNSname) 
  	{
  		$DNSname = "Reverse DNS Failure";
  		logentry("$DNSname\n",2,1);
  	}
  	else
  	{
  		@strSplit = split(/-/,$DNSname);
  		$devType = $strSplit[2] . " " . $strSplit[3];
  		logentry ("Reverse DNS Successful, DNSName: $DNSname\n",2,1);
  		logentry ("DNS DevType: $devType\n",2,1);
#  		$InUse = 1;
  	}

		foreach $key (sort keys %PortTestArray)  
		{
			$value = $PortTestArray{$key};
			logentry(" testing $value ...\n",2,1);
			PortTest ($IPAddr,$key);
			$PortTestResults{$key} = $PortTest;
			logentry(" $value test: $PortTest\n",2,1);
		}

		logentry (" Opening a SNMP connection to $IPAddr\n",2,1);
		($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr, timeout => $SNMPTimeout);
		if (!defined($session)) 
		{
			$errmsg = sprintf("Connect ERROR: %s.", $error);
			logentry ("$errmsg\n",2,1);
			$SNMPTest = "Fail";
		}
		else
		{
			$error = "";
			$errmsg = "";
			logentry (" SNMP connection to $IPAddr established\n",2,1);
			foreach $key (sort keys %getOIDs)  
			{
				$value = $getOIDs{$key};
				logentry("Issuing a SNMP get for $key ... \n",2,1);
				$result = $session->get_request($value);
		 		if (!defined($result)) 
		 		{
		 			$error = $session->error;
		 			$errmsg = "SNMP ERROR: $error.";
		 			logentry ("$errmsg\n",2,1);
	   			$getOIDResults{$key} = $errmsg;
	   			$SNMPTest = "Fail";
	   			last;
		 		}
		 		else
		 		{
		 			$OIDResult = $result->{$value};
					$OIDResult =~ s/\n/ /g;
					$OIDResult =~ s/\t/ /g;
					$OIDResult =~ s/\r/ /g;
					$OIDResult =~ s/\'/\'/g;
		 			logentry ("$key: $OIDResult\n",2,1);
		 			$getOIDResults{$key} = $OIDResult;
		 			$InUse = 1;
		 			$SNMPTest = "Success";
		 		}
			}
			if (!defined($devType) and $getOIDResults{"sysName"} !~ /.*ERROR.*/)
			{
	  		@strSplit = split(/-/,$getOIDResults{"sysName"});
  			$devType = $strSplit[2] . " " . $strSplit[3];
  			logentry ("SysName DevType: $devType\n",2,1);
  		}
			if ($getOIDResults{"sysDescr"} !~ /.*ERROR.*/)
			{
				($Make) = split (/ /, $getOIDResults{"sysDescr"});
			}
		}
		logentry ("Done processing $IPAddr .. \n",2,1);
		$strOut = "$IPAddr\t$DNSname\t$devType\t$Make\t$alive\t$SNMPTest\t";
		foreach $key (sort keys %PortTestArray) 
		{
			$strOut .=  $PortTestResults{$key} . "\t";
		}
		foreach $key (sort keys %getOIDs) 
		{
			$strOut .=  $getOIDResults{$key} . "\t";
		}		
		$strOut = substr $strOut,0,-1;
		$strOut .= "\n";
		logentry ("$strOut",3,2);
		if ($InUse == 1)
		{
			if ($DBout ne "true")
			{
				print OUT $strOut;
			}
			else
			{
				$iDevID = "";
				$strSQL = "SELECT iDeviceID from tblDevices where vcIPaddr = '$IPAddr';";
				logentry ("$strSQL\n",3,2);
				$sth = $dbh->prepare($strSQL);
				$sth->execute();
				while (my $ref = $sth->fetchrow_hashref()) 
				{
					$iDevID = $ref->{'iDeviceID'};
					logentry ("Fetched Devid\n",3,2);
				}
				logentry ("iDevID=*$iDevID*\n",3,2);				
				if ($iDevID eq "")
				{
					chomp $strOut;
					@OutValues = split (/\t/,$strOut);
					$strSQL = "INSERT INTO tblDevices (vcIPaddr,vcDNSName,vcType,vcMake,vcPing,vcSNMP,";
					foreach $key (sort keys %PortTestResults) 
					{
						$strSQL .=  $PortFieldArray{$key} . ",";
					}
					foreach $key (sort keys %getOIDResults) 
					{
						$strSQL .=  $getOIDFields{$key} . ",";
					}		
					$strSQL .= "vcUpdatedby,dtUpdatedAt) ";
					$strSQL .= " VALUES (";
					foreach $key (@OutValues)
					{
						$strSQL .= "'$key',";
					}
					$strSQL .= "'$host',now());";
					logentry ("$strSQL\n",3,2);
					$dbh->do($strSQL);
				}
				else
				{
					$strSQL = "update tblDevices set vcDNSName = '$DNSname', vcType = '$devType', vcMake = '$Make', ";
					$strSQL .= "vcPing = '$alive', vcSNMP = '$SNMPTest', ";
					foreach $key (sort keys %PortTestResults) 
					{
						$strSQL .=  "$PortFieldArray{$key} = '$PortTestResults{$key}', ";
					}
					foreach $key (sort keys %getOIDResults) 
					{
						$strSQL .=  "$getOIDFields{$key} = '$getOIDResults{$key}', ";
					}		
					$strSQL .= "vcUpdatedby = '$host', dtUpdatedAt = now() where iDeviceID = $iDevID; ";
					logentry ("$strSQL\n",3,2);
					$dbh->do($strSQL);				
				}
			}
		}
		$session->close;		
	}
	logentry("Done processing subnet $Subnet for $Market in $City...\n",1,0); 
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

if ($iDays > 0)
{
	$strTimeElapse .= "$iDays days, ";
}
if ($iHours > 0)
{
	$strTimeElapse .= "$iHours hours, ";
}
if ($iMins > 0)
{
	$strTimeElapse .= "$iMins minutes and ";
}
$strTimeElapse .= "$iSecs seconds";

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);	
$mon = $mon + 1;			
logentry ("Done processing $ShortName $ScriptInst out of $NumScripts at $mon/$mday/$year $hour:$min\n",0,0);
logentry ("Processing $TotalIP IP's took $strTimeElapse",0,0);
logentry ("or a total of $isec seconds.\n",0,0);
logentry ("elapse time $isec seconds; $imin minutes; $ihour hours.\n",3,2);
logentry ("Done. Exiting normally!\n",0,0);

if (($relay ne "") and ($to ne ""))
{
	push @body, "$host has completed processing $ShortName $ScriptInst out of $NumScripts and the results are stored in $ResIn\n";
	push @body, "\nStopped processing at $mon/$mday/$year $hour:$min\n";
	push @body, "Processing $TotalIP IP's took $strTimeElapse,";
	push @body, " or a total of $isec seconds.\n";
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
		my($outmsg, $ConLevel, $FileLevel) = @_;
		
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year = $year+1900;
		$min = substr("0$min",-2);
		$mon = $mon + 1;
		$sec = substr("0$sec",-2);
		
		if ($ConLevel <= $verbose)
		{
			print "$mon/$mday/$year $hour:$min:$sec $outmsg";
		}
		if ($FileLevel <= $LogLevel)
		{
			print LOG "$mon/$mday/$year $hour:$min:$sec $outmsg";
		}
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

sub SubnetValidate
{
	my ($Subnet, $SubnetEnd, $City, $Market) = @_;
	my ($QuadCount, $quad, @subnetquads, $bValid, $line);
	@subnetquads = split(/\./, $Subnet);
	$QuadCount = scalar(@subnetquads);
	if ($QuadCount == 4)
	{
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
	}
	else
	{
		$bValid = "false";
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
		$line = "$Subnet, $SubnetEnd, $City, $Market";
		push (@inArray, $line);
#		$inArray[$i] = "$Subnet, $SubnetEnd, $City, $Market";
		$TotalIP += $SubnetEnd - $subnetquads[3] + 1;
	}
	else
	{
		logentry("$line contains invalid subnet details and is being skipped\n\n\n",0);
	}
	return $bValid;
}	