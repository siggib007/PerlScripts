use strict;

use DBI();
use Data::UUID;
use Sys::Hostname;
use English;
use POSIX;

my ($logfile, $dbh, $strSQL, $tblName, $Where, $sth, $LogPath, $ug, $strUUID, $strOut, $devType);
my ($verbose, $LogLevel, $DBHost, $DBName, $DBUser, $DBpwd, $scriptFullName, $x, $ResIn);
my ($host, $ScriptInst, $NumScripts, $Perc, $ElapseSec, $StartTime, $Outstr, $decIP, $strTimeElapse);
my (@tmp, $pathparts, $ShortName, $progname, $InFile, $line, $Subnet, $Market, $iCurrSubnet);
my ($strout, @output, $linecount, $rl, $IPAddr, $DNSName, %PortTest, $outfile, $SubnetTblName);
my ($DNSDumpFile, $DNSURL, $result, $nmap_cmd, %PortTestArray, $key, $goodpar, $StartLimit, $StopTime);
my ($isec, $imin, $ihour, $iDiff, $iDays, $iHours, $iMins, $iSecs, @lines, %PortFieldArray);
my ($DBin, $DBout, $SubNets, $SqlLimit, @inArray, $LimitCount, $inCount, $NetID, $SubNetCount);
my ($MarketFilter, $LocalScan, $nmap_base_cmd, $seq, $InUse);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$mon ++;
$min = substr("0$min",-2);
$sec = substr("0$sec",-2);

$DNSDumpFile = "/var/tmp/DNSDump.txt";
$DNSURL = "http://10.41.161.140/dns/hosts.php";

$LogPath = "/var/log/scripts/discovery";

$DBHost = "localhost";
$DBName = "inventory";
$SubnetTblName = "tblCIDRsubnets";
$DBUser = "script";
$DBpwd = "test123";

$nmap_base_cmd = "nmap -T4 -p";

$PortTestArray{22} = "SSH";
$PortTestArray{23} = "Telnet";
$PortTestArray{80} = "HTTP";
$PortTestArray{443} = "HTTPS";

$PortFieldArray{22} = "vcSSH";
$PortFieldArray{23} = "vcTelnet";
$PortFieldArray{80} = "vcHTTP";
$PortFieldArray{443} = "vcHTTPS";

$scriptFullName = $PROGRAM_NAME;
$scriptFullName =~ s/\\/\//g;
@tmp = split(/\//,$scriptFullName);
$pathparts = scalar @tmp;
$ShortName = $tmp[$pathparts-1];
($progname) = split(/\./,$ShortName);
$host = hostname;

$ug = new Data::UUID;
$strUUID  = $ug->create_str();

foreach $key (sort keys %PortTestArray)
{
	$nmap_base_cmd .= "$key,";
}
$nmap_base_cmd = substr $nmap_base_cmd,0,-1;


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
	if ($lines[0] eq "market")
	{
		$MarketFilter = $lines[1];
		$goodpar = "true";
		print "found market of $MarketFilter\n";
	}
	if ($lines[0] eq "local")
	{
		$LocalScan = "true";
		$goodpar = "true";
		print "found local scan directive\n";
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
	if ($lines[0] eq "limit")
	{
		$SqlLimit = $lines[1];
		$goodpar = "true";
		print "found SQL limit of $SqlLimit\n";
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
	if ($goodpar eq "false")
	{
		print "Invalid option $x \n\n";
		exit();
	}
}

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

$StartTime = time();

if ($MarketFilter ne "")
{
	$Where = " where vcMarket like '%$MarketFilter%'";
}

if ($LocalScan eq "true")
{
	$Where = " where vcScanFrom = '$host'";
}

$seq = 0;
$logfile = "$LogPath/$progname-$ScriptInst-$seq.log";
while (-e $logfile)
{
	print "$logfile in use, increasing suffix\n";
	$seq ++;
	$logfile = "$LogPath/$progname-$ScriptInst-$seq.log";
}

print "Logging to $logfile\n";
open(LOG,">>",$logfile) || die "cannot open logfile $logfile for append: $!";

if ($DBin eq "true" or $DBout eq "true")
{
	$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                      "$DBUser", "$DBpwd",
                      {'RaiseError' => 1});
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
		if ($line =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/{0,1}\d{0,2})[\s,;:|]+(.*)/)
		{
			push (@inArray, $1,$2);
			$SubNetCount++			
		}
	}
}
else
{
	logentry ("reading from database ... \n",0,0);
	if ($SubNets ne "")
	{
		$Where = " where iSubnetID in ($SubNets)";
	}
	$strSQL = "SELECT count(*) as SubNetCount FROM $SubnetTblName $Where";
	logentry ("$strSQL\n",3,2);
	$sth = $dbh->prepare($strSQL);
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref())
	{
		$inCount = $ref->{'SubNetCount'};
	}
	if ($NumScripts == 1 or $SubNets ne "")
	{
		$LimitCount = $inCount;
		$StartLimit = 0;
	}

	if ($SqlLimit eq "" and $SubNets eq "")
	{
		$LimitCount = ceil($inCount / $NumScripts);
		$StartLimit = ($ScriptInst - 1) * $LimitCount;
	}
	if ($SqlLimit ne "" and $SubNets eq "")
	{
		($StartLimit,$LimitCount)  = split (/,/, $SqlLimit);
	}

	$strSQL = "SELECT * FROM $SubnetTblName $Where limit $StartLimit, $LimitCount";
	logentry ("$strSQL\n",3,2);
	$sth = $dbh->prepare($strSQL);
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref())
	{
	  $Subnet = $ref->{'vcSubnet'};
	  $Market = $ref->{'vcMarket'};
	  $NetID = $ref->{'iSubnetID'};
	  $line = "$Subnet,$Market";
		push (@inArray, $line);
		$SubNetCount++
	}
}

if ($DBout ne "true")
{
	open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
	logentry ("outputing to $outfile ... \n",0,0);
	$strOut = "IP\tDecIP\tMarket\tSite\tDNS_Name\tType";
	foreach $key (sort keys %PortTestArray)
	{
		$strOut .=  "$PortTestArray{$key}\t";
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

if ($DBin eq "true" or $DBout eq "true")
{
	$strSQL = "INSERT INTO tblStatus (vcUUID,iSubnetCount,iIPCount,dtStart,vcHost,iInst,iScriptCount,dtUpdatedAt)";
	$strSQL .= "VALUES ('$strUUID',$SubNetCount,$SubNetCount,now(),'$host',$ScriptInst,$NumScripts,now());";
	logentry ("$strSQL\n",3,2);
	$dbh->do($strSQL);
}

$Outstr = "";

if (-e $DNSDumpFile)
{
	if (-M $DNSDumpFile > 1)
	{
		logentry ("Refreshing DNS Dump\n",0,0);
		$result = `wget -O $DNSDumpFile $DNSURL 2>&1`;
		logentry ("DNS Dump complete\n$result\n",3,2);
	}
	else
	{
		print "$DNSDumpFile exists and is younger than a day\n";
	}
}
else
{
	logentry ("Fetching DNS Dump for the first time\n",0,0);
	$result = `wget -O $DNSDumpFile $DNSURL 2>&1`;
	logentry ("DNS Dump complete\n$result\n",3,2);
}

foreach $line (@inArray)
{
	$iCurrSubnet ++;
	undef @output;
	($Subnet,$Market) = split(/,/,$line);
	logentry ("Starting nmap scan on $Subnet for $Market which is market $iCurrSubnet out of $SubNetCount\n",1,0);
	$ElapseSec = time() - $StartTime;
	if ($DBin eq "true" or $DBout eq "true")
	{
		$strSQL = "update tblStatus set dtUpdatedAt=now(), iElapseSec = $ElapseSec, ";
		$strSQL .= "iCurrSubnet = $iCurrSubnet, iCurrIPNo = $iCurrSubnet, ";
		$strSQL .= "vcMarket = '$Market' where vcUUID = '$strUUID';";
		logentry ("$strSQL\n",3,2);
		$dbh->do($strSQL);
	}
	$nmap_cmd = "$nmap_base_cmd $Subnet";
	logentry ("nmap command: $nmap_cmd\n",3,2);
	$strout = `$nmap_cmd`;
	@output = split(/\n/,$strout);
	$linecount = scalar @output;
	logentry ("starting analysis on $linecount lines of output\n",2,1);
	foreach $rl (@output)
	{
		logentry ("ResponseLine:$rl\n",4,3);
		if ($rl=~/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)
		{
			if ($IPAddr ne "")
			{
				if ($InUse == 1)
				{
					logentry ("Writing results to $ResIn \n",2,1);
					SaveResults();
				}
				else
				{
					if ($DBin eq "true" or $DBout eq "true")
					{
						if ($DNSName ne "Reverse DNS Failure")
						{
							$strSQL = "delete from tblDeadDNS where vcIPAddr='$IPAddr';";
							logentry ("$strSQL\n",3,2);
							$dbh->do($strSQL);
							$strSQL = "insert tblDeadDNS (vcIPAddr, vcDNSName, dtTimeStamp) VALUES ('$IPAddr','$DNSName',now());";
 							logentry ("$strSQL\n",3,2);
							$dbh->do($strSQL);
						}
					}
				}
				$InUse = 0;
				logentry ("found new IP address $1\n",3,2);
				$IPAddr = $1;
				logentry ("Calculating decimal value\n",3,2);
				$decIP = IP2Dec($IPAddr);
				logentry ("Doing DNS lookup against the DNS dump\n",3,2);
				$DNSName = DNSLookup($IPAddr);
			}
			else
			{
				logentry ("Found the first IP of $1\n",3,2);
				$IPAddr = $1;
				logentry ("Calculating decimal value\n",3,2);
				$decIP = IP2Dec($IPAddr);
				logentry ("Doing DNS lookup against the DNS dump\n",3,2);
				$DNSName = DNSLookup($IPAddr);
			}
		}
		if ($rl=~/(\d{1,3})\/tcp\s*(\S*)/)
		{
			logentry ("Found Port $1 $2\n",3,2);
			if ($2 eq "open")
			{
				$PortTest{$1} = "Success";
				$InUse = 1;
			}
			if ($2 eq "closed")
			{
				$PortTest{$1} = "Fail";
			}
			if ($2 eq "filtered")
			{
				$PortTest{$1} = "Fail";
			}
		}
		if ($rl=~/Nmap finished:/)
		{
			logentry ("$rl\n",2,1);
		}
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
logentry ("Processing $SubNetCount subnet's took $strTimeElapse",0,0);
logentry ("or a total of $isec seconds.\n",0,0);
logentry ("elapse time $isec seconds; $imin minutes; $ihour hours.\n",3,2);
logentry ("Done. Exiting normally!\n",0,0);


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

sub IP2Dec
{
	my ($Subnet) = @_;
	my (@subnetquads, $hexIP, $decIP );
	logentry ("calculating decimal value of $Subnet\n",3,2);
	@subnetquads = split(/\./, $Subnet);
	$hexIP  = sprintf "%02x%02x%02x%02x", $subnetquads[0], $subnetquads[1], $subnetquads[2], $subnetquads[3];
	$decIP  = hex($hexIP);
	logentry ("Hex: $hexIP\tdecIP: $decIP\n",3,2);
	return $decIP;
}

sub DNSLookup
{
	my ($ipaddr) = @_;
	my ($cmd, $result, @parts, @strSplit );
	$devType = "";
	logentry ("Searching the DNS Dump file for: $ipaddr\n",3,2);
	$cmd = "grep -iw $ipaddr $DNSDumpFile";
	logentry ("using command: $cmd\n",3,2);
	$result = `$cmd`;
	chomp $result;
	logentry ("result: $result\n",3,2);
	@parts = split /\t/, $result;
	if ($parts[1] ne "")
	{
 		@strSplit = split(/-/,$parts[1]);
 		$devType = $strSplit[2] . " " . $strSplit[3];
		return $parts[1];
	}
	else
	{
		return "Reverse DNS Failure";
	}
}

sub SaveResults
{
	my ($iDevID, $strSQL, @OutValues, $key, $Outstr, $Market, $Site);
	if ($DNSName ne "Reverse DNS Failure")
	{
		$DNSName = uc $DNSName;
		$DNSName =~ /(.{6})(W1|\d{4})/;
		$Market = $1;
		$Site = $2;
	}
	if ($DBout ne "true")
	{
		$Outstr = "$IPAddr\t$decIP\t$Market\t$Site\t$DNSName\t";
		foreach $x (sort keys %PortTest)
		{
			$Outstr .= "$PortTest{$x}\t";
		}
		$Outstr = substr $Outstr,0,-1;
		$Outstr .= "\n";
		print OUT $Outstr;	
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
			$strSQL = "INSERT INTO tblDevices (vcIPaddr,iIPAddr,vcMarket,vcSite,vcDNSName,vcType,";
			foreach $key (sort keys %PortTest)
			{
				$strSQL .=  $PortFieldArray{$key} . ",";
			}
			$strSQL .= "vcUpdatedby,dtUpdatedAt) ";
			$strSQL .= " VALUES ('$IPAddr','$decIP','$Market','$Site','$DNSName','$devType',";
			foreach $x (sort keys %PortTest)
			{
				$strSQL .= "'$PortTest{$x}',";
			}
			$strSQL .= "'$host',now());";
			logentry ("$strSQL\n",3,2);
			$dbh->do($strSQL);
		}
		else
		{
			$strSQL = "update tblDevices set iIPAddr = $decIP, vcMarket = '$Market', vcSite = '$Site', ";
			$strSQL .= "vcDNSName = '$DNSName', vcType = '$devType', ";
			foreach $key (sort keys %PortTest)
			{
				$strSQL .=  "$PortFieldArray{$key} = '$PortTest{$key}', ";
			}
			$strSQL .= "vcUpdatedby = '$host', dtUpdatedAt = now() where iDeviceID = $iDevID; ";
			logentry ("$strSQL\n",3,2);
			$dbh->do($strSQL);
		}
	}
}