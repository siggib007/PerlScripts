use strict;
use Net::SNMP;
use DBI();
use Data::UUID;
use Sys::Hostname;
use English;
use Net::Ping::External qw(ping);

my ($comstr, $session, $error, $result, $logfile, $dbh, $strSQL, $tblName, $Where);
my (%getOIDs, $value, $errmsg, %outhash, $Tablekey, $OutKey, $sth, $iDevID, $x, $y);
my ($verbose, $LogLevel, $DBHost, $DBName, $DBUser, $DBpwd, $scriptFullName, %getOIDFields);
my ($DeviceName, $DeviceIP, $LogPath, $iDevCount, $CurrCount, $ug, $strUUID, $alive, $SNMPTest);
my ($host, $ScriptInst, $NumScripts, $Perc, $ElapseSec, $StartTime, $OIDResult, $key, $devType);
my (@tmp, $pathparts, $ShortName, $progname, %outTablehash, $sysObjectID, %tableOIDs, $Make);
my (%reshash, $id, $reskey, $slotnum, %xcvr, %outxcvr, %PortHash, %outPorts, %Ports);
my ($PartNo, $Vendor, $SN, $Rev, $Int, $sName, @Communities, @SNMPVersions, $snmpVer);
my (%getOIDResults, @strSplit, $SNMPTimeout, $VersionCount, $ComCount);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$mon ++;
$min = substr("0$min",-2);
$sec = substr("0$sec",-2);

$SNMPTimeout = 3;
$verbose    = 5;
$LogLevel   = 5;
$ScriptInst = 1;
$NumScripts = 1;

$SNMPVersions[0] = 2;
$SNMPVersions[1] = 1;

$LogPath = "/var/log/scripts/discovery";

$tblName = "tblDevices";
$Where   = " WHERE vcSNMP = 'Fail'";
#$Where   = " WHERE vcIPaddr like '10.40.184.%'";
#$Where   = " WHERE vcDNSName LIKE '%valere%'";
$DBHost  = "localhost";
$DBName  = "inventory";
$DBUser  = "script";
$DBpwd   = "test123";

$sysObjectID = "1.3.6.1.2.1.1.2.0";
$getOIDs{"sysName"}     = "1.3.6.1.2.1.1.5.0";
$getOIDs{"sysDescr"}    = "1.3.6.1.2.1.1.1.0";
$getOIDs{"sysObjectID"} = "1.3.6.1.2.1.1.2.0";
$getOIDs{"sysLocation"} = "1.3.6.1.2.1.1.6.0";

$getOIDFields{"sysName"}     = "vcSysName";
$getOIDFields{"sysDescr"}    = "vcSysDescr";
$getOIDFields{"sysObjectID"} = "vcSysObjectID";
$getOIDFields{"sysLocation"} = "vcsysLocation";
$LogPath = "/var/log/scripts/discovery";
$ug = new Data::UUID;
$strUUID = $ug->create_str();
$scriptFullName = $PROGRAM_NAME;
$scriptFullName =~ s/\\/\//g;	
@tmp = split(/\//,$scriptFullName);
$pathparts = scalar @tmp;
$ShortName = $tmp[$pathparts-1];
($progname) = split(/\./,$ShortName);

$logfile = "$LogPath/$progname-$ScriptInst-$mon-$mday-$year.log";

print "Logging to $logfile\n";

$host = hostname;
$StartTime = time();

open(LOG,">>",$logfile) || die "cannot open logfile $logfile for append: $!";
$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                      "$DBUser", "$DBpwd",
                      {'RaiseError' => 1});

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;

undef @Communities;

logentry ("Loading Community Strings...\n",0,0);
$strSQL = "SELECT vcCom FROM tblComStr ORDER BY dtAdded DESC";
logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref())
{
  $comstr = $ref->{'vcCom'};
  push @Communities, $comstr;
}

$VersionCount = scalar @SNMPVersions;
$ComCount = scalar @Communities;

logentry ("Checking how many IP's to inventory...\n",0,0);
$strSQL = "SELECT count(*) as IPCount FROM $tblName $Where";
logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref())
{
  $iDevCount = $ref->{'IPCount'};
}
logentry ("There are $iDevCount IP's to test SNMP ... \n",0,0);
logentry ("Creating a record in the status table...\n",0,0);

$strSQL = "INSERT INTO tblInvStatus (vcUUID,dtStart,vcHost,vcScript,iInst,iScriptCount,iTotalNo,dtUpdatedAt)";
$strSQL .= "VALUES ('$strUUID',now(),'$host','$progname',$ScriptInst,$NumScripts,$iDevCount,now());";
logentry ("$strSQL\n",3,2);
$dbh->do($strSQL);
logentry ("reading from database ...\n",0,0);

$strSQL = "SELECT * FROM $tblName $Where";
logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref())
{
	undef $devType;
	undef $Make;
	$CurrCount++;
  $iDevID     = $ref->{'iDeviceID'};
  $DeviceName = $ref->{'vcSysName'};
  $DeviceIP   = $ref->{'vcIPaddr'};

	$Perc = ($CurrCount / $iDevCount) * 100;
	$Perc = sprintf("%.3f%%", $Perc);
	$ElapseSec = time() - $StartTime;
	$strSQL = "update tblInvStatus set dtUpdatedAt=now(), iCurNo = $CurrCount, iElapseSec = $ElapseSec, ";
	$strSQL .= "vcDevName = '$DeviceName', vcCurIP = '$DeviceIP' where vcUUID = '$strUUID';";
	logentry ("$strSQL\n",3,2);
	$dbh->do($strSQL);
	logentry("Pinging $DeviceIP ...\n",2,1);
	$alive = ping(host => $DeviceIP);
	if ($alive)
	{
		$alive = "Success";
		logentry(" Ping test: $DeviceIP responds to ping...\n",2,1);
	}
	else
	{
		logentry(" Ping test: $DeviceIP does not respond to ping...\n",2,1);
		$alive = "Fail";
	}
	logentry ("Opening SNMP connection to $DeviceName with the IP of $DeviceIP\n",2,1);
	logentry ("This is IP $CurrCount out of $iDevCount\n",2,1);
	SNMPVer: for ($x=0; $x < $VersionCount; $x++)
	{
		$snmpVer = $SNMPVersions[$x];
		SNMPCom: for ($y=0; $y < $ComCount; $y++)
		{
			$SNMPTest = "Fail";
			$comstr = $Communities[$y];
			logentry ("Attempting SNMP connection using version $snmpVer and comstring # $y\n",1,0);
			($session,$error) = Net::SNMP->session(	hostname  => $DeviceIP,
																							community => $comstr,
																							timeout   => $SNMPTimeout,
																							version   => $snmpVer);
			if (!defined($session))
			{
				printf("ERROR: %s.\n", $error);
			  next SNMPCom;
			}

			$result = $session->get_request($sysObjectID);
			if (!defined($result))
			{
				$error = $session->error;
				$errmsg = "SNMP ERROR: $error.";
				logentry ("$errmsg\n",1,0);
			  $session->close;
			  undef $session;
			  next SNMPCom;
			}
			else
			{
				logentry ("SNMP connection to $DeviceIP established using version $snmpVer and comstring # $y\n",1,0);
				logentry("deleting old comstr information from database ... \n",2,1);
				$strSQL = "delete from tblDevCom where iDeviceID=$iDevID";
				logentry ("$strSQL\n",3,2);
				$dbh->do($strSQL);
				logentry("Noting testing results in database ... \n",2,1);
				$strSQL = "INSERT INTO tblDevCom (iDeviceID, vcComStr, iSNMPVer, dtUpdate)";
				$strSQL .= "VALUES ('$iDevID', '$comstr', '$snmpVer', now());";
				logentry ("$strSQL\n",3,2);
				$dbh->do($strSQL);
				$SNMPTest = "Success";
				last SNMPVer;
			}
		}
	}
	if (!defined($session))
	{
		logentry ("$DeviceIP does not respond to any known Community string and version combination\n",2,1);
		$strSQL = "update tblDevices set vcPing = '$alive', vcSNMP = '$SNMPTest', ";
		$strSQL .= "vcUpdatedby = '$host', dtUpdatedAt = now() where iDeviceID = $iDevID; ";
		logentry ("$strSQL\n",3,2);
		$dbh->do($strSQL);
	}
	else
	{
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
		logentry ("Done processing $DeviceIP, updating database .. \n",2,1);
		$strSQL = "update tblDevices set vcType = '$devType', vcMake = '$Make', vcPing = '$alive', vcSNMP = '$SNMPTest', ";
		foreach $key (sort keys %getOIDResults)
		{
			$strSQL .=  "$getOIDFields{$key} = '$getOIDResults{$key}', ";
		}
		$strSQL .= "vcUpdatedby = '$host', dtUpdatedAt = now() where iDeviceID = $iDevID; ";
		logentry ("$strSQL\n",3,2);
		$dbh->do($strSQL);
	}
}

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
