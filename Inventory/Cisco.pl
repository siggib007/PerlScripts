use strict;
use Net::SNMP;
use DBI();
use Data::UUID;
use Sys::Hostname;
use English;

my ($comstr,$session,$error,$result,$logfile, $dbh, $strSQL, $tblName, $Where);
my (%getOIDs, $value, $errmsg, %outhash, $Tablekey, $OutKey, $sth, $iDevID );
my ($verbose, $LogLevel, $DBHost, $DBName, $DBUser, $DBpwd, $scriptFullName);
my ($DeviceName, $DeviceIP, $LogPath, $iDevCount, $CurrCount, $ug, $strUUID);
my ($host, $ScriptInst, $NumScripts, $Perc, $ElapseSec, $StartTime, $OIDResult);
my (@tmp,$pathparts,$ShortName,$progname, %outTablehash, $sysname, %tableOIDs);
my (%reshash, $id, $reskey, $slotnum, %xcvr, %outxcvr, %PortHash, %outPorts, %Ports);
my ($PartNo, $Vendor, $SN, $Rev, $Int, $sName);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$mon ++;
$min = substr("0$min",-2);
$sec = substr("0$sec",-2);

$verbose    = 2;
$LogLevel   = 5;
$ScriptInst = 1;
$NumScripts = 1;

$comstr = 'ctipublic';

$LogPath = "/var/log/scripts/discovery";

$tblName = "tblDevices";
$Where   = " WHERE vcDNSName LIKE '%cis%'";
$DBHost  = "localhost";
$DBName  = "inventory";
$DBUser  = "script";
$DBpwd   = "test123";

$sysname = "1.3.6.1.2.1.1.5.0";

$getOIDs{"sysDescr"}      = "1.3.6.1.2.1.1.1.0";
$getOIDs{"sysObjectID"}   = "1.3.6.1.2.1.1.2.0";
$getOIDs{"sysLocation"}   = "1.3.6.1.2.1.1.6.0";
$getOIDs{"sysname"}       = "1.3.6.1.2.1.1.5.0";


$tableOIDs{"ModuleDescription"} = "1.3.6.1.2.1.47.1.1.1.1.2";
$tableOIDs{"ModuleClass"}       = "1.3.6.1.2.1.47.1.1.1.1.5";
$tableOIDs{"ModuleName"}        = "1.3.6.1.2.1.47.1.1.1.1.7";
$tableOIDs{"ModuleHwVersion"}   = "1.3.6.1.2.1.47.1.1.1.1.8";
$tableOIDs{"ModuleFwVersion"}   = "1.3.6.1.2.1.47.1.1.1.1.9";
$tableOIDs{"ModuleSwVersion"}   = "1.3.6.1.2.1.47.1.1.1.1.10";
$tableOIDs{"ModuleSerialNum"}   = "1.3.6.1.2.1.47.1.1.1.1.11";
$tableOIDs{"ModuleVendor"}      = "1.3.6.1.2.1.47.1.1.1.1.12";
$tableOIDs{"ModuleModel"}       = "1.3.6.1.2.1.47.1.1.1.1.13";
$tableOIDs{"ModuleFRU"}         = "1.3.6.1.2.1.47.1.1.1.1.16";

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
$strSQL = "SELECT count(*) as IPCount FROM $tblName $Where";
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

$strSQL = "SELECT * FROM $tblName $Where";
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
	else
	{
		$sName = $result->{$value};
		logentry ("sysName is: $sName\n",3,2);
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

	undef %outTablehash;
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
		 		logentry ("OIDResultClean for $id / $Tablekey: $OIDResult\n",4,3);
				$outTablehash{$id}{$Tablekey} = $OIDResult;
				logentry ("outTablehash{$id}{$Tablekey} = $outTablehash{$id}{$Tablekey}\n",4,3);
			}
		}
	}
	
	$strSQL  = "update tblDevices set vcUpdatedby='$host',";
	$strSQL .= "vcSysName='$outhash{sysname}',vcSysDescr='$outhash{sysDescr}',vcSNMP='Success',";
	$strSQL .= "vcsysLocation='$outhash{sysLocation}',vcSysObjectID='$outhash{sysObjectID}',";
	$strSQL .= "dtUpdatedAt=now() where iDeviceID = $iDevID;";
	logentry ("$strSQL\n",3,2);
	eval
	{
		$dbh->do($strSQL);
	};
	logentry ("ERROR while writing device details to database:\n $strSQL\n $@\n",1,0) if $@;
	
	logentry("deleting old tranceiver information from database ... \n",2,1);
	$strSQL = "delete from tblXcvr where iDeviceID=$iDevID";
	logentry ("$strSQL\n",3,2);
	$dbh->do($strSQL);
	
	logentry("deleting old module information from database ... \n",2,1);
	$strSQL = "delete from tblModules where iDeviceID=$iDevID";
	logentry ("$strSQL\n",3,2);
	$dbh->do($strSQL);

	logentry("Writing results to database ... \n",2,1);

	foreach $OutKey (sort keys %outTablehash)
	{
		if ($outTablehash{$OutKey}{"ModuleFRU"} == 1)
		{
			if ($outTablehash{$OutKey}{"ModuleClass"}  == 3)
			{
				$strSQL  = "update tblDevices set vcSerialNo='$outTablehash{$OutKey}{ModuleSerialNum}',";
				$strSQL .= "vcModel='$outTablehash{$OutKey}{ModuleModel}',vcUpdatedby='$host',";
				$strSQL .= "dtUpdatedAt=now() where iDeviceID = $iDevID;";
				logentry ("$strSQL\n",3,2);
				eval
				{
					$dbh->do($strSQL);
				};
				logentry("ERROR while writing device details to database:\n $strSQL\n $@\n",1,0) if $@;
			}
			if ($outTablehash{$OutKey}{"ModuleClass"}  == 9 or $outTablehash{$OutKey}{"ModuleClass"}  == 6)
			{
				if ($outTablehash{$OutKey}{"ModuleName"} =~ /Transceiver/)
				{
					$Int = $outTablehash{$OutKey}{"ModuleName"};
					$Int =~ s/Transceiver //;
					
					if ($outTablehash{$OutKey}{"ModuleModel"} eq "")
					{
						@tmp = split(/ /,$outTablehash{$OutKey}{ModuleDescription});
						$PartNo = $tmp[1];
					}
					else
					{
						$PartNo = $outTablehash{$OutKey}{"ModuleModel"};
					}
					
					if ($outTablehash{$OutKey}{"ModuleVendor"} eq "")
					{
						@tmp = split(/ /,$outTablehash{$OutKey}{ModuleDescription});
						$Vendor = $tmp[1];
					}
					else
					{
						$Vendor = $outTablehash{$OutKey}{"ModuleVendor"};
					}						
					
					if ($outTablehash{$OutKey}{"ModuleSerialNum"} eq "")
					{
						@tmp = split(/ /,$outTablehash{$OutKey}{ModuleDescription});
						$SN = $tmp[1];
					}
					else
					{
						$SN = $outTablehash{$OutKey}{"ModuleSerialNum"};
					}
					
					$Rev = $outTablehash{$OutKey}{"ModuleHwVersion"};
					$strSQL = "INSERT INTO tblXcvr (iDeviceID, vcSNMPid, vcInt, vcVendorName, vcRevNum, vcSerialNum, vcPartNumber, dtUpdatedAt) ";
					$strSQL .= "VALUES ('$iDevID','$OutKey','$Int','$Vendor','$Rev','$SN','$PartNo',NOW());";
					logentry ("$strSQL\n",3,2);
					eval 
					{
						$dbh->do($strSQL);
					};
					logentry("ERROR while writing module info to database:\n $strSQL\n $@\n",1,0) if $@;					
				}
				else
				{
					if ($outTablehash{$OutKey}{ModuleDescription} !~ /VTT|Clock/)
					{
						$strSQL = "INSERT INTO tblModules (iDeviceID, vcSlotNum, vcDescription, vcPartNumber, vcSerialNo, ";
						$strSQL .= "vcHWVersion, vcSWVersion,dtUpdatedAt) ";
						$strSQL .= "VALUES ('$iDevID','$outTablehash{$OutKey}{ModuleName}', '$outTablehash{$OutKey}{ModuleDescription}', ";
						$strSQL .= "'$outTablehash{$OutKey}{ModuleModel}','$outTablehash{$OutKey}{ModuleSerialNum}',";
						$strSQL .= "'$outTablehash{$OutKey}{ModuleHwVersion}','$outTablehash{$OutKey}{ModuleSwVersion}',NOW());";
						logentry ("$strSQL\n",3,2);
						eval 
						{
							$dbh->do($strSQL);
						};
						logentry("ERROR while writing module info to database:\n $strSQL\n $@\n",1,0) if $@;
					}
				}
		  }
		}
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
