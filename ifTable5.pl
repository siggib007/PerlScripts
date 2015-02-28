use strict;
use Net::SNMP;
use DBI();
use Data::UUID;
use Sys::Hostname;

my ($comstr,$session,$error,$sysname,$result,%reshash,@hkeys,$id,$logfile, $dbh, $strSQL);
my (%tableOIDs, $value, $errmsg, %outhash, $Tablekey, $reskey, $devname, $OutKey, $sth, $iDevID );
my (%AdminStatusCode, %OperStatusCode, $verbose, $LogLevel, $DBHost, $DBName, $DBUser, $DBpwd);
my ($DeviceName, $DeviceIP, $line, $LogPath, $iDevCount, $CurrCount, $ug, $strUUID);
my ($host, $ScriptInst, $NumScripts, $Perc, $ElapseSec, $StartTime, $host, $OIDResult);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$mon ++;
$min = substr("0$min",-2);
$sec = substr("0$sec",-2);

$verbose    = 2;
$LogLevel   = 1;

$ScriptInst = 1;
$NumScripts = 1;

$comstr = 'ctipublic';

$LogPath = "/var/log/scripts/discovery";

$logfile = "$LogPath/ifTable$mon-$mday-$year.log";

$DBHost = "localhost";
$DBName = "inventory";
$DBUser = "script";
$DBpwd = "test123";

$tableOIDs{"ifDesc"}        = "1.3.6.1.2.1.2.2.1.2";
$tableOIDs{"ifSpeed"}       = "1.3.6.1.2.1.2.2.1.5";
$tableOIDs{"ifPhysAddress"} = "1.3.6.1.2.1.2.2.1.6";
$tableOIDs{"ifAdminStatus"} = "1.3.6.1.2.1.2.2.1.7";
$tableOIDs{"ifOperStatus"}  = "1.3.6.1.2.1.2.2.1.8";

$sysname = '1.3.6.1.2.1.1.5.0';

$AdminStatusCode{1} = 'up';
$AdminStatusCode{2} = 'down';
$AdminStatusCode{3} = 'testing';

$OperStatusCode{1} = 'up';
$OperStatusCode{2} = 'down';
$OperStatusCode{3} = 'testing';
$OperStatusCode{4} = 'unknown';
$OperStatusCode{5} = 'dormant';
$OperStatusCode{6} = 'notPresent';
$OperStatusCode{7} = 'lowerLayerDown';

$CurrCount  = 0;

$ug = new Data::UUID;
$strUUID = $ug->create_str();

$host = hostname;
$StartTime = time();

open(LOG,">>",$logfile) || die "cannot open logfile $logfile for append: $!";
$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                      "$DBUser", "$DBpwd",
                      {'RaiseError' => 1});

logentry ("Checking how many IP's to inventory...\n",0,0);
$strSQL = "SELECT count(*) as IPCount FROM tblDevices WHERE vcSNMP = 'success'";
logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) 
{
  $iDevCount = $ref->{'IPCount'}; 
}
logentry ("There are $iDevCount IP's to be inventoried for interface info ... \n",0,0);
logentry ("Creating a record in the status table...\n",0,0);

$strSQL = "INSERT INTO tblInvStatus (vcUUID,dtStart,vcHost,vcScript,iInst,iScriptCount,iTotalNo,dtUpdatedAt)";
$strSQL .= "VALUES ('$strUUID',now(),'$host','interface',$ScriptInst,$NumScripts,$iDevCount,now());";
logentry ("$strSQL\n",3,2);
$dbh->do($strSQL);
logentry ("reading from database ...\n",0,0);

$strSQL = "SELECT iDeviceID,vcSysName,vcIPaddr FROM tblDevices WHERE vcSNMP = 'success'";
logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) 
{
	undef %outhash;
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

	logentry ("Opening SNMP connection to $DeviceName with the IP of $DeviceIP\n",1,0);
	logentry ("This is IP $CurrCount out of $iDevCount\n",1,0);
	($session,$error) = Net::SNMP->session(hostname => $DeviceIP, community => $comstr, timeout => 10);
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
	$devname = $result->{$sysname};
	logentry ("device name is $devname\n",2,1);

	foreach $Tablekey (sort keys %tableOIDs)  
	{
		$value = $tableOIDs{$Tablekey};
		logentry("Issuing a SNMP walk for $Tablekey ... \n",2,1);
		$result = $session->get_table($value);
		if (!defined($result)) 
		{
			$error = $session->error;
			$errmsg = "SNMP ERROR: $error.";
			logentry ("$errmsg\n",1,0);
#			last;
		}
		else
		{
			%reshash = %$result;
			foreach $reskey(sort(keys %reshash)) 
			{
				$id = substr($reskey,length($value)+1);
		 		$OIDResult = $reshash{$reskey};
		 		logentry ("OIDResultRaw: $OIDResult\n",4,3);
				$OIDResult =~ s/^\s+//;
				$OIDResult =~ s/\s+$//;
				$OIDResult =~ s/\n/ /g;
				$OIDResult =~ s/\t/ /g;
				$OIDResult =~ s/\r/ /g;
				$OIDResult =~ s/\'//g;
		 		logentry ("OIDResultClean: $OIDResult\n",4,3);
				$outhash{$id}{$Tablekey} = $OIDResult;
			}
		}
	}
	logentry("deleting old results from database ... \n",2,1);
	$strSQL = "delete from tblInterfaces where iDeviceID=$iDevID";
	logentry ("$strSQL\n",3,2);
	$dbh->do($strSQL);
	logentry("Writing results to database ... \n",2,1);
	
	foreach $OutKey (sort keys %outhash)
	{
		$strSQL = "INSERT INTO tblInterfaces (iDeviceID, iIndex, vcInterface, iSpeed, vcMacAddr, vcAdminStatus, vcOpStatus, dtUpdatedAt) ";
		$strSQL .= "VALUES ('$iDevID' , '$OutKey', '$outhash{$OutKey}{ifDesc}', '$outhash{$OutKey}{ifSpeed}', '$outhash{$OutKey}{ifPhysAddress}',";
		$strSQL .= "'$AdminStatusCode{$outhash{$OutKey}{ifAdminStatus}}', '$OperStatusCode{$outhash{$OutKey}{ifOperStatus}}', NOW());";
		logentry ("$strSQL\n",3,2);
		eval 
		{
			$dbh->do($strSQL);
		};
		logentry("ERROR while writing results to database:\n $strSQL\n $@\n",1,0) if $@;
	}
	$session->close;
}

logentry("Done !!! \n",2,1);
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
