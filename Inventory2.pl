use strict;
use net::SNMP;
use Win32::OLE 'in';

my ($devicename,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,$entPhysicalEntry,$id, $errmsg);
my (@Inv, %invitem, $inst, $type, $loc, $len, %PhysClass, %FRU, $dev, $dstTable, $StartTime, $isec, $imin, $t1, $t2);
my ($CN, $SrcRS, $dstRS, $SrcCmdText, $DBServer, $Cmd, $ComCmd, $CmdStr, $Device, $StopTime, $ihour, $Update1Cmd);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$DBServer = "by2netsql01";

#$SrcCmdText = "select DeviceName from Inventory.dbo.vwProdDeviceList";
$SrcCmdText = "Inventory.dbo.devicelist";
$dstTable = "Inventory.dbo.NetInvDetail";
$ComCmd = "select String from cmdb.dbo.ComStrings where StringType = 'Production'";
$Update1Cmd = "exec Inventory.dbo.spUpdateDevList";

$sysname = '1.3.6.1.2.1.1.5.0';
$ifDesc = '1.3.6.1.2.1.2.2.1.2';
$entPhysicalEntry = '1.3.6.1.2.1.47.1.1.1.1';

$PhysClass{1} = 'other';
$PhysClass{2} = 'unknown';
$PhysClass{3} = 'chassis';
$PhysClass{4} = 'backplane';
$PhysClass{5} = 'container';
$PhysClass{6} = 'powerSupply';
$PhysClass{7} = 'fan';
$PhysClass{8} = 'sensor';
$PhysClass{9} = 'module';
$PhysClass{10} = 'port';
$PhysClass{11} = 'stack';
$PhysClass{12} = 'cpu';

$FRU{1} = 'true';
$FRU{2} = 'false';

$StartTime = time;

print "Started processing at $mon/$mday/$year $hour:$min\n" ;
$CN    = new Win32::OLE "ADODB.Connection";
if (!defined($CN) or Win32::OLE->LastError() != 0 ) 
{
	print "Failed to create conenction object\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}

$SrcRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SrcRS) or Win32::OLE->LastError() != 0 ) 
{
	print "Failed to create source recordset object\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}
$dstRS = new Win32::OLE "ADODB.Recordset";
if (!defined($dstRS) or Win32::OLE->LastError() != 0 ) 
{
	print "failed to create a destination recordset object\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}
$Cmd   = new Win32::OLE "ADODB.Command";
if (!defined($Cmd) or Win32::OLE->LastError() != 0 ) 
{
	print "failed to create a command object\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}

$CN->{Provider} = "sqloledb";
$CN->{Properties}{"Data Source"}->{value} = $DBServer;
$CN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open Connection\n";
$CN->open; 
if (Win32::OLE->LastError() != 0 ) 
{
	print "cannot open source database connection\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}

$Cmd->{ActiveConnection} = $CN;
$Cmd->{CommandText} = $Update1Cmd;
$Cmd->{Execute}; 
if (Win32::OLE->LastError() != 0 ) 
{
	print "error while executing command: \n$Update1Cmd \n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}

print "fetching com string\n";
$SrcRS->Open ($ComCmd, $CN);
if (Win32::OLE->LastError() != 0 ) 
{
	print "Failed to fetch comstr\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}
$comstr = $SrcRS->{fields}{String}->{value};
$SrcRS->Close;
print "attempting to fetch source data\n";
$SrcRS->{LockType} = 3; #adLockOptimistic
$SrcRS->{CursorLocation} = 3; #adUseClient
$SrcRS->{"Sort"} = "dtAttempt";
$SrcRS->Open ($SrcCmdText, $CN); 

if (Win32::OLE->LastError() != 0 ) 
{
	print "Failed to fetch device list\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}

$dstRS->{LockType} = 3; #adLockOptimistic
$dstRS->{ActiveConnection} = $CN;
$dstRS->{Source} = $dstTable;
$dstRS->Open;
if (Win32::OLE->LastError() != 0 ) 
{
	print "Unable to open destination table\n".Win32::OLE->LastError();
	cleanup();
	exit 1;
}

while ( !$SrcRS->EOF )
{	
	$Device = $SrcRS->{fields}{vcDeviceName}->{value};
	#print time . "   deleting old values for $Device\n";
	$CmdStr = "delete from $dstTable where Device = '$Device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) 
	{
		print "error while executing command: \n$CmdStr \n".Win32::OLE->LastError();
		cleanup();
		exit 1;
	}
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);
	$mon = $mon + 1;

	$SrcRS->{fields}{dtAttempt}->{value} = "$mon/$mday/$year $hour:$min";
	#print time . "   Connecting to $Device\n";
	$t1 = time;
	($session,$error) = Net::SNMP->session(hostname => $Device, community => $comstr);
	if (!defined($session)) 
	{
		printf("Error: %s.\n", $error);
		$SrcRS->{fields}{vcMsg}->{value} = $error;
	}
	else	
	{
		#print time . "  Connected, getting sysname\n";
		$result = $session->get_request($sysname);
		$errmsg = "";
		if (!defined($result)) 
		{
			#$errmsg = $session->error;
			printf("Sysname ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcSysName}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = $session->error;
		}
		else
		{
			$SrcRS->{fields}{vcSysName}->{value} = "Success";
			$devicename = $result->{$sysname};
		}
		($dev) = split (/\./,$devicename);
		if ($dev eq "") 
		{
			$dev = $Device; 
			print "replaced sysname from db\n";
		}
		print time . "   Processing $dev\n";
		
		$result = $session->get_table($entPhysicalEntry);
		if (!defined($result)) 
		{
			printf("Inv ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcContain}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = $session->error;
		}
		else
		{
			$SrcRS->{fields}{vcContain}->{value} = "OK";
			$SrcRS->{fields}{dtSuccess}->{value} = "$mon/$mday/$year $hour:$min";			
			%reshash = %$result;
			foreach $key(sort(keys %reshash)) 
			{ 
				if ($reshash{$key} ne '')
				{
					$len = length($entPhysicalEntry);
					$id = 'entPhysicalEntry' . substr($key,$len);
					$loc = rindex ($key, '.');
					$inst = substr($key,$loc+1);
					$type = substr($key,$len+1,$loc-$len-1);
					$invitem{$inst}{$type} = $reshash{$key}
				}
			}
			#print time . "  saving to database\n";
			foreach $key(sort(keys %invitem))
			{		
				$dstRS->AddNew;
					if (Win32::OLE->LastError() != 0 ) 
					{
						print "error while adding record\n".Win32::OLE->LastError();
						cleanup();
						exit 1;
					}			
					$dstRS->{fields}{Device}->{value}         = $dev;
					$dstRS->{fields}{Instance}->{value}       = $key;
					$dstRS->{fields}{Description}->{value}    = $invitem{$key}{'2'};
					$dstRS->{fields}{ContainedName}->{value}  = $invitem{$invitem{$key}{'4'}}{'7'};
					$dstRS->{fields}{ContainedDescr}->{value} = $invitem{$invitem{$key}{'4'}}{'2'};
					$dstRS->{fields}{Type}->{value}           = $PhysClass{$invitem{$key}{'5'}};
					$dstRS->{fields}{subpos}->{value}         = $invitem{$key}{'6'};
					$dstRS->{fields}{ItemName}->{value}       = $invitem{$key}{'7'};
					$dstRS->{fields}{HardwareRev}->{value}    = $invitem{$key}{'8'};
					$dstRS->{fields}{FirmwareRev}->{value}    = $invitem{$key}{'9'};
					$dstRS->{fields}{SoftwareRev}->{value}    = $invitem{$key}{'10'};
					$dstRS->{fields}{SerialNum}->{value}      = $invitem{$key}{'11'};
					$dstRS->{fields}{Make}->{value}           = $invitem{$key}{'12'};
					$dstRS->{fields}{Model}->{value}          = $invitem{$key}{'13'};
					$dstRS->{fields}{FRU}->{value}            = $invitem{$key}{'16'};
					$dstRS->{fields}{MFGDate}->{value}        = $invitem{$key}{'17'};
					$dstRS->{fields}{Uris}->{value}           = $invitem{$key}{'18'};
					$dstRS->{fields}{TimeStamp}->{value}      = "$mon/$mday/$year $hour:$min";
				$dstRS->Update; 
				if (Win32::OLE->LastError() != 0 ) 
				{
					print "error while saving new record\n".Win32::OLE->LastError();
					cleanup();
					exit 1;
				}		
			}
			#print time . "   record saved\n";
		}	
	$session->close;
	}	
	$SrcRS->Update;
	$SrcRS->Movefirst;
	if (Win32::OLE->LastError() != 0 ) 
	{
		print "error while movefirst\n".Win32::OLE->LastError();
		cleanup();
		exit 1;
	}	
}
cleanup();
print "Completed successfully.\n";
exit 0;

sub cleanup
{
	$session->close;
	undef $session;
	$SrcRS->Close;
	undef $SrcRS;
	$dstRS->Close;
	undef $dstRS;
	undef $Cmd;
	$CN->Close;
	undef $CN;
	
	$StopTime = time;
	$isec = $StopTime - $StartTime;
	$imin = $isec/60;
	$ihour = $imin/60;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);	
	$mon = $mon + 1;
	print "Stopped processing at $mon/$mday/$year $hour:$min\n" ;
	print "elapse time $isec seconds; $imin minutes; $ihour hours.\n";
}
