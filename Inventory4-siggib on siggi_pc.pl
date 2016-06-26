use strict;
use net::SNMP;
use Win32::OLE 'in';
use Net::SMTP;

my ($devicename,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,$entPhysicalEntry,$id, $errmsg, %TrueFalse);
my (@Inv, %invitem, $inst, $type, $loc, $len, %PhysClass, %FRU, $dev, $dstTable, $StartTime, $isec, $imin);
my ($CN, $SrcRS, $dstRS, $SrcCmdText, $DBServer, $Cmd, $ComCmd, $CmdStr, $Device, $StopTime, $ihour, $Update1Cmd);
my ($CDPCmdText, $CDPrs,$rem, $tail, $finst, %cdpcach,$cdpCacheEntry, %ints, $rdevice, $ciscoFlashDeviceEntry);
my ($to, $from, $subject, @body, $relay, %FlashDev, $Flashrs, $FlashCmdText, %hComStr);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$DBServer = "by2netsql01";
$relay = "tk2smtp.phx.gbl";
$to = "siggib\@microsoft.com";
$from = "siggib\@microsoft.com";
$subject = "Inventory job outcome";
$SrcCmdText = "Inventory.dbo.devicelist";
$dstTable = "Inventory.dbo.NetInvDetail";
$CDPCmdText = "Inventory.dbo.CDPNeighbor";
$FlashCmdText = "Inventory.dbo.FlashDevices";
$ComCmd = "select StringType, String from cmdb.dbo.ComStrings";
$Update1Cmd = "exec Inventory.dbo.spUpdateDevList";

$sysname = '1.3.6.1.2.1.1.5.0';
$ifDesc = '1.3.6.1.2.1.2.2.1.2';
$entPhysicalEntry = '1.3.6.1.2.1.47.1.1.1.1';
$cdpCacheEntry = '1.3.6.1.4.1.9.9.23.1.2.1.1';
$ciscoFlashDeviceEntry = '1.3.6.1.4.1.9.9.10.1.1.2.1';

$TrueFalse{1} = 'true';
$TrueFalse{2} = 'false';

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
if (!defined($CN) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create conenction object\n".Win32::OLE->LastError(),1);}

$SrcRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SrcRS) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create source recordset object\n".Win32::OLE->LastError(),1);}

$dstRS = new Win32::OLE "ADODB.Recordset";
if (!defined($dstRS) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a destination recordset object\n".Win32::OLE->LastError(),1);}

$CDPrs = new Win32::OLE "ADODB.Recordset";
if (!defined($CDPrs) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a CDP recordset object\n".Win32::OLE->LastError(),1);}

$Flashrs = new Win32::OLE "ADODB.Recordset";
if (!defined($Flashrs) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a CDP recordset object\n".Win32::OLE->LastError(),1);}

$Cmd   = new Win32::OLE "ADODB.Command";
if (!defined($Cmd) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a command object\n".Win32::OLE->LastError(),1);}

$CN->{Provider} = "sqloledb";
$CN->{Properties}{"Data Source"}->{value} = $DBServer;
$CN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open Connection\n";
$CN->open; 
if (Win32::OLE->LastError() != 0 ) { cleanup("cannot open source database connection\n".Win32::OLE->LastError(),1);}

$Cmd->{ActiveConnection} = $CN;
$Cmd->{CommandText} = $Update1Cmd;
$Cmd->{Execute}; 
if (Win32::OLE->LastError() != 0 ){ cleanup("error while executing command: \n$Update1Cmd \n".Win32::OLE->LastError(),1);}

print "fetching com string\n";
$SrcRS->Open ($ComCmd, $CN);
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch comstr\n".Win32::OLE->LastError(),1);}
while ( !$SrcRS->EOF )
{
	$hComStr{$SrcRS->{fields}{StringType}->{value}} = $SrcRS->{fields}{String}->{value};
	$SrcRS->MoveNext;
}

#$comstr = $SrcRS->{fields}{String}->{value};
$SrcRS->Close;

print "attempting to fetch source data\n";
$SrcRS->{LockType} = 3; #adLockOptimistic
$SrcRS->{CursorLocation} = 3; #adUseClient
$SrcRS->{"Sort"} = "dtAttempt";
$SrcRS->Open ($SrcCmdText, $CN); 
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch device list\n".Win32::OLE->LastError(),1);}

$dstRS->{LockType} = 3; #adLockOptimistic
$dstRS->{ActiveConnection} = $CN;
$dstRS->{Source} = $dstTable;
$dstRS->Open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Unable to open destination table\n".Win32::OLE->LastError(),1);}

$CDPrs->{LockType} = 3; #adLockOptimistic
$CDPrs->{ActiveConnection} = $CN;
$CDPrs->{Source} = $CDPCmdText;
$CDPrs->Open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Unable to open CDP table\n".Win32::OLE->LastError(),1);}

$Flashrs->{LockType} = 3; #adLockOptimistic
$Flashrs->{ActiveConnection} = $CN;
$Flashrs->{Source} = $FlashCmdText;
$Flashrs->Open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Unable to open CDP table\n".Win32::OLE->LastError(),1);}

while ( !$SrcRS->EOF )
{	
	undef %cdpcach;
	undef %invitem;
	$Device = $SrcRS->{fields}{vcDeviceName}->{value};
	print "Device: $Device\t";
	if ($Device =~ m/sch/i)
	{
		print "Search Device\t";
		$comstr = $hComStr{'Search'};
	}
	else
	{
		print "Other device\t";
		$comstr = $hComStr{'Production'};
	}
	#print "Comstr: $comstr\n";
	print "\n";
	$CmdStr = "delete from $dstTable where Device = '$Device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);}
	
	$CmdStr = "delete from $CDPCmdText where lDevice = '$Device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);}	

	$CmdStr = "delete from $FlashCmdText where vcDeviceName = '$Device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);}	

	
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);
	$mon = $mon + 1;

	$SrcRS->{fields}{dtAttempt}->{value} = "$mon/$mday/$year $hour:$min";
	($session,$error) = Net::SNMP->session(hostname => $Device, community => $comstr);
	if (!defined($session)) 
	{
		printf("Connect Error: %s.\n", $error);
		$SrcRS->{fields}{vcMsg}->{value} = "Connect: $error";
	}
	else	
	{
		$SrcRS->{fields}{vcMsg}->{value} = "";
		$result = $session->get_request($sysname);
		$errmsg = "";
		if (!defined($result)) 
		{
			printf("Sysname ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcSysName}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = "Sysname: $session->error";
			$devicename = $Device;
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
		$result = $session->get_table($ifDesc);
		if (!defined($result)) 
		{
			printf("IFDesc ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcifDesc}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = "ifdesc: $session->error";
		}
		else
		{
			$SrcRS->{fields}{vcifDesc}->{value} = "Success";
			%reshash = %$result;			
			foreach $key(sort(keys %reshash)) 
			{ 
				$len = length($ifDesc);
				$id = substr($key,$len+1);
				$ints{$id} = $reshash{$key};
			}
		}
		$result = $session->get_table($cdpCacheEntry);
		if (!defined($result)) 
		{
			printf("CDP ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcCDP}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = "cdp: $session->error";
		}
		else
		{
			$SrcRS->{fields}{vcCDP}->{value} = "Success";
			%reshash = %$result;
			foreach $key(sort(keys %reshash)) 
			{ 
				if ($reshash{$key} ne '')
				{
					$len = length($cdpCacheEntry);
					$tail = substr($key,$len+1);
					$id = 'cdpCacheEntry' . $tail;
					($type,$rem,$inst) = split(/\./,$tail);
					$finst = join('.',$rem,$inst);
					$cdpcach{$finst}{$type} = $reshash{$key}
				}
			}
			foreach $key(sort(keys %cdpcach))
			{
				($rem,$inst) = split(/\./,$key);
				$cdpcach{$key}{'5'} =~ s/\n/ /g;
				$rdevice = $cdpcach{$key}{'6'};
				$rdevice = substr($rdevice,index($rdevice,"(")+1);
				$rdevice =~ s/\)//g;
				$rdevice =~ s/\(//g;
				($rdevice) = split (/\./,$rdevice);
				$CDPrs->AddNew;
				if (Win32::OLE->LastError() != 0 ) { cleanup("error while adding record to cdp table\n".Win32::OLE->LastError(),1);}
					
					$CDPrs->{fields}{lDevice}->{value}      = $dev;
					$CDPrs->{fields}{lInterface}->{value}   = $ints{$rem};
					$CDPrs->{fields}{RDevice}->{value}      = $rdevice;
					$CDPrs->{fields}{RDeviceIP}->{value}    = $cdpcach{$key}{'4'};
					$CDPrs->{fields}{RDeviceModel}->{value} = $cdpcach{$key}{'8'};
					$CDPrs->{fields}{ROSversion}->{value}   = $cdpcach{$key}{'5'};
					$CDPrs->{fields}{RInterface}->{value}   = $cdpcach{$key}{'7'};
				$CDPrs->Update; 
				if (Win32::OLE->LastError() != 0 ) {cleanup("error while saving new CDP record\n".Win32::OLE->LastError(),1);}
			}
		}	
		
		$result = $session->get_table($ciscoFlashDeviceEntry);
		if (!defined($result)) 
		{
			printf("Flash ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcFlash}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = "Flash: $session->error";
		}
		else
		{
			$SrcRS->{fields}{vcFlash}->{value} = "Success";
			%reshash = %$result;
			foreach $key(sort(keys %reshash)) 
			{ 
				if ($reshash{$key} ne '')
				{
					$len = length($ciscoFlashDeviceEntry);
					$tail = substr($key,$len+1);
					($type,$inst) = split(/\./,$tail);
					$FlashDev{$inst}{$type} = $reshash{$key}
				}
			}
			foreach $key(sort(keys %FlashDev))
			{
				$Flashrs->AddNew;
				if (Win32::OLE->LastError() != 0 ) {cleanup("error while adding record to cdp table\n".Win32::OLE->LastError(),1);
								}			
					$Flashrs->{fields}{vcDeviceName}->{value} = $dev;
					$Flashrs->{fields}{vcFlashName}->{value}  = $FlashDev{$key}{'7'};
					$Flashrs->{fields}{vcDescr}->{value}      = $FlashDev{$key}{'8'};
					$Flashrs->{fields}{isize}->{value}        = $FlashDev{$key}{'2'};
					$Flashrs->{fields}{removable}->{value}    = $TrueFalse{$FlashDev{$key}{'13'}};
				$Flashrs->Update; 
				if (Win32::OLE->LastError() != 0 ) { cleanup("error while saving new CDP record\n".Win32::OLE->LastError(),1);}			
			}
		}
	
		$result = $session->get_table($entPhysicalEntry);
		if (!defined($result)) 
		{
			printf("Inv ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcContain}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = "Inv: $session->error";
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
			foreach $key(sort(keys %invitem))
			{		
				$dstRS->AddNew;
				if (Win32::OLE->LastError() != 0 ) { cleanup("error while adding record to inv table\n".Win32::OLE->LastError(),1);}			
				
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
				if (Win32::OLE->LastError() != 0 ) { cleanup("error while saving new Inv record\n".Win32::OLE->LastError(),1);}
			}
		}
		$session->close;
	}
	$CmdStr = "exec inventory.dbo.spInsertCDP";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 		
	$SrcRS->Update;
	$SrcRS->Requery;
	$SrcRS->Movefirst;
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while movefirst\n".Win32::OLE->LastError(),1);}	
}
cleanup("Completed successfully.",0);

sub cleanup
{
	my($closemsg,$exitcode) = @_;
	if ($exitcode eq '')
	{
		$exitcode = 3;
	}
	if (defined($session))
	{
		$session->close;
		undef $session;
	}
	if (defined($SrcRS))
	{	
		$SrcRS->Close;
		undef $SrcRS;
	}
	if (defined($dstRS))
	{		
		$dstRS->Close;
		undef $dstRS;
	}

	if (defined($CDPrs))
	{		
		$CDPrs->Close;
		undef $CDPrs;
	}

	if (defined($Flashrs))
	{		
		$Flashrs->Close;
		undef $Flashrs;
	}

	undef $Cmd;
	if (defined($CN))
	{			
		$CN->Close;
		undef $CN;
	}
	$StopTime = time;
	$isec = $StopTime - $StartTime;
	$imin = $isec/60;
	$ihour = $imin/60;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);	
	$mon = $mon + 1;
	print "\n";
	push @body, "$closemsg\n";
	push @body, "\nStopped processing at $mon/$mday/$year $hour:$min\n";
	push @body, "elapse time $isec seconds; $imin minutes; $ihour hours.\n";
	push @body, "exiting with exit code $exitcode\n";
	print @body;
	send_mail();
	exit $exitcode;
}

sub send_mail 
{
my ($smtp, $body);
	
	$smtp = Net::SMTP->new($relay, Debug => 0); # Set Debug to 1 if you have any problems
	if (!defined($smtp))
	{
		print "Failed to open mail session to $relay\n";
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
