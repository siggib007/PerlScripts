use strict;
use Net::SNMP;
use DBI();
use Data::UUID;
use Sys::Hostname;
use English;

my ($comstr, $session, $error, $result, $logfile, $dbh, $strSQL, $tblName, $Where);
my (%getOIDs, $value, $errmsg, %outhash, $Tablekey, $OutKey, $sth, $iDevID, $sName);
my ($verbose, $LogLevel, $DBHost, $DBName, $DBUser, $DBpwd, $scriptFullName, $SysDescr);
my ($DeviceName, $DeviceIP, $LogPath, $iDevCount, $CurrCount, $ug, $strUUID, $SysLoc);
my ($host, $ScriptInst, $NumScripts, $Perc, $ElapseSec, $StartTime, $OIDResult, $SysObjID);
my (@tmp, $pathparts, $ShortName, $progname, %outTablehash, $sysname, %tableOIDs, $HashCount);
my (%reshash, $id, $reskey, $spacepos, $strModel, $strDescr, $strSN, $strVersion, $strMake);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$mon ++;
$min = substr("0$min",-2);
$sec = substr("0$sec",-2);

$verbose    = 0;
$LogLevel   = 5;
$ScriptInst = 1;
$NumScripts = 1;

$comstr = 'ctipublic';

$LogPath = "/var/log/scripts/discovery";

$tblName = "tblDevices";
$Where   = "vcDNSName LIKE '%ekn%'";
$DBHost  = "localhost";
$DBName  = "inventory";
$DBUser  = "script";
$DBpwd   = "test123";

$sysname = '1.3.6.1.2.1.1.5.0';

$getOIDs{"ChassisDet"}    = "1.3.6.1.4.1.20044.7.6.8.0";
$getOIDs{"ChassisSW"}     = "1.3.6.1.4.1.20044.7.6.2.0";
$getOIDs{"ChassisFan"}    = "1.3.6.1.4.1.20044.7.6.9.0";
$getOIDs{"ChassisMGMT"}   = "1.3.6.1.4.1.20044.7.6.1.0";
$getOIDs{"sysDescr"}      = "1.3.6.1.2.1.1.1.0";
$getOIDs{"sysObjectID"}   = "1.3.6.1.2.1.1.2.0";
$getOIDs{"sysLocation"}   = "1.3.6.1.2.1.1.6.0";

$tableOIDs{"ModuleInfo"}  = "1.3.6.1.4.1.20044.7.6.7.1.2";

$CurrCount  = 0;

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

logentry ("Checking how many IP's to inventory...\n",0,0);
$strSQL = "SELECT count(*) as IPCount FROM $tblName WHERE $Where";
logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) 
{
  $iDevCount = $ref->{'IPCount'}; 
}
logentry ("There are $iDevCount IP's to be inventoried ... \n",0,0);
logentry ("Creating a record in the status table...\n",0,0);

$strSQL = "INSERT INTO tblInvStatus (vcUUID,dtStart,vcHost,vcScript,iInst,iScriptCount,iTotalNo,dtUpdatedAt)";
$strSQL .= "VALUES ('$strUUID',now(),'$host','$progname',$ScriptInst,$NumScripts,$iDevCount,now());";
logentry ("$strSQL\n",3,2);
$dbh->do($strSQL);
logentry ("reading from database ...\n",0,0);

$strSQL = "SELECT * FROM $tblName WHERE $Where";
logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) 
{
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

	logentry ("Opening SNMP connection to $DeviceName with the IP of $DeviceIP\n",2,1);
	logentry ("This is IP $CurrCount out of $iDevCount\n",2,1);
	($session,$error) = Net::SNMP->session(hostname => $DeviceIP, community => $comstr, timeout => 10, version => 2);
	if (!defined($session)) 
	{
		printf("ERROR: %s.\n", $error);
	  next;
	}

	$result = $session->get_request($sysname);
	if (!defined($result)) 
	{
		$error = $session->error;
		$errmsg = "SNMP ERROR: $error.";
		logentry ("$errmsg\n",1,0);
	  $session->close;
	  next;
	}
	else
	{
		$sName = $result->{$value}
	}
	
	foreach $Tablekey (sort keys %getOIDs)  
	{
		$value = $getOIDs{$Tablekey};
		logentry("Issuing a SNMP get for $Tablekey ... \n",2,1);
		$result = $session->get_request($value);
		if (!defined($result)) 
		{
			$error = $session->error;
			$errmsg = "SNMP ERROR: $error.";
			logentry ("$errmsg\n",2,1);
		}
		else
		{
			$OIDResult = $result->{$value};
			if ($OIDResult =~ /^0x[0-9,A-F]*/)
			{
				$OIDResult = pack("H*",$OIDResult);
			}
	 		logentry ("OIDResultRaw for $Tablekey: $OIDResult\n",3,2);
			$OIDResult =~ s/\"//;
			$OIDResult =~ s/^\s+//;
			$OIDResult =~ s/\s+$//;
			$OIDResult =~ s/\t/ /g;
			$OIDResult =~ s/\r/\n/g;
			$OIDResult =~ s/\n\n/\n/g;
			$OIDResult =~ s/ {2,}/ /g;
			$OIDResult =~ s/\'/\'/g;
	 		logentry ("OIDResultClean for $Tablekey: $OIDResult\n",3,2);
			$outhash{$Tablekey} = $OIDResult;
		}
	}
	
	foreach $Tablekey (sort keys %tableOIDs)  
	{
		$value = $tableOIDs{$Tablekey};
		logentry("Issuing a SNMP walk for $Tablekey ... \n",2,1);
		$result = $session->get_table(baseoid => $value,maxrepetitions => 1);
		if (!defined($result)) 
		{
			$error = $session->error;
			$errmsg = "SNMP ERROR while walking $Tablekey $value: $error.";
			logentry ("$errmsg\n",1,0);
		}
		else
		{
			%reshash = %$result;
			$HashCount = scalar %reshash;
			logentry("Processing $HashCount results for $Tablekey ... \n",2,1);
			foreach $reskey(sort(keys %reshash)) 
			{
				$id = substr($reskey,length($value)+1);
		 		$OIDResult = $reshash{$reskey};
				if ($OIDResult =~ /^0x[0-9,A-F]*/)
				{
					$OIDResult = pack("H*",$OIDResult);
				}
		 		logentry ("OIDResultRaw for $Tablekey: \n$OIDResult\n",4,3);
				$OIDResult =~ s/\"//;
				$OIDResult =~ s/^\s+//;
				$OIDResult =~ s/\s+$//;
				$OIDResult =~ s/\t/ /g;
				$OIDResult =~ s/\r/\n/g;
				$OIDResult =~ s/\n\n/\n/g;
				$OIDResult =~ s/ {2,}/ /g;
				$OIDResult =~ s/\'/\'/g;
#		 		logentry ("OIDResultClean for $id / $Tablekey: \n$OIDResult\n",4,3);
				$outTablehash{$id}{$Tablekey} = $OIDResult;
				logentry ("outTablehash{$id}{$Tablekey} = $outTablehash{$id}{$Tablekey}\n",4,3);
			}
		}
	}
	
	logentry("Writing results to database ... \n",2,1);
	
	$outhash{ChassisDet}=~/Vendor : (.*)\n.*Mnemonic : (.*)\n.*\n.*Serial Number : (.*)/;
	$strModel = $2;
	$strSN = $3;
	$strMake = $1;
	$outhash{ChassisSW}=~/Release Name : Release (.*)/;
	$strVersion = $1;
	$strSQL  = "update tblDevices set vcSerialNo='$strSN', vcModel='$strModel',";
	$strSQL .= "vcVersion='$strVersion',vcUpdatedby='$host',vcMake='$strMake',";
	$strSQL .= "vcSysName='$sName',vcSysDescr='$outhash{sysDescr}',vcSNMP='Success',";
	$strSQL .= "vcsysLocation='$outhash{sysLocation}',vcSysObjectID='$outhash{sysObjectID}',";
	$strSQL .= "dtUpdatedAt=now() where iDeviceID = $iDevID;";
	logentry ("$strSQL\n",3,2);
	eval
	{
		$dbh->do($strSQL);
	};
	logentry ("ERROR while writing device details to database:\n $strSQL\n $@\n",1,0) if $@;

	logentry("deleting old module information from database ... \n",2,1);
	$strSQL = "delete from tblModules where iDeviceID=$iDevID";
	logentry ("$strSQL\n",3,2);
	$dbh->do($strSQL);

	foreach $OutKey (sort keys %outTablehash)
	{
		if ($outTablehash{$OutKey}{ModuleInfo}=~ /Mnemonic : (.*)\n.*Part Number : (.*)\n.*Version Number : (.*)/)
		{
			$strDescr = $1;
			$strModel = $2;
			$strVersion = $3
		}
		if ($outTablehash{$OutKey}{ModuleInfo}=~ /Part Number: (.*)\n.*Mnemonic: (.*)\n.*Version Number: (.*)/)
		{
			$strDescr = $2;
			$strModel = $1;
			$strVersion = $3
		}
		$strSQL = "INSERT INTO tblModules (iDeviceID, vcSlotNum, vcDescription, vcPartNumber, vcHWVersion, dtUpdatedAt) ";
		$strSQL .= "VALUES ('$iDevID' , '$OutKey', '$strDescr', '$strModel','$strVersion',NOW());";
		logentry ("$strSQL\n",3,2);
		eval 
		{
			$dbh->do($strSQL);
		};
		logentry("ERROR while writing module info to database:\n $strSQL\n $@\n",1,0) if $@;
	}
	$outhash{ChassisMGMT}=~/Mnemonic : (.*)\n.*Part Number : (.*)\n.*Serial Number : (.*)/;
	$strDescr = $1;
	$strModel = $2;
	$strSN = $3;
	$strSQL = "INSERT INTO tblModules (iDeviceID, vcSlotNum, vcDescription, vcPartNumber, vcSerialNo, dtUpdatedAt) ";
	$strSQL .= "VALUES ('$iDevID' , 'mgmt', '$strDescr', '$strModel','$strSN',NOW());";
	logentry ("$strSQL\n",3,2);
	eval 
	{
		$dbh->do($strSQL);
	};
	logentry("ERROR while writing module info to database:\n $strSQL\n $@\n",1,0) if $@;
	$outhash{ChassisFan}=~/Mnemonic : (.*)\n.*Part Number : (.*)\n.*Serial Number : (.*)/;
	$strDescr = $1;
	$strModel = $2;
	$strSN = $3;
	$strSQL = "INSERT INTO tblModules (iDeviceID, vcSlotNum, vcDescription, vcPartNumber, vcSerialNo, dtUpdatedAt) ";
	$strSQL .= "VALUES ('$iDevID' , 'fan', '$strDescr', '$strModel','$strSN',NOW());";
	logentry ("$strSQL\n",3,2);
	eval 
	{
		$dbh->do($strSQL);
	};
	logentry("ERROR while writing module info to database:\n $strSQL\n $@\n",1,0) if $@;
	
	$session->close;
}

logentry("Done !!! \n",0,0);
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
