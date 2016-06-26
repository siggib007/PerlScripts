use strict;
use net::SNMP;
use Win32::OLE 'in';
use Net::SMTP;

my ($devicename,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,$entPhysicalEntry,$id, $errmsg);
my (@Inv, %invitem, $inst, $type, $loc, $len, %PhysClass, %FRU, $dev, $dstTable, $StartTime, $isec, $imin, $t1, $t2);
my ($CN, $SrcRS, $dstRS, $SrcCmdText, $DBServer, $Cmd, $ComCmd, $CmdStr, $Device, $StopTime, $ihour, $Update1Cmd);
my ($CDPCmdText, $CDPrs,$rem, $tail, $finst, %cdpcach,$cdpCacheEntry, %ints, $rdevice);
my($to, $from, $subject, @body,$relay);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$DBServer = "by2netsql01";
$relay = "tk2smtp.phx.gbl";
$to = "siggib\@microsoft.com";
$from = "siggib\@microsoft.com";
$subject = "Inventory job outcome";
#$SrcCmdText = "select DeviceName from Inventory.dbo.vwProdDeviceList";
$SrcCmdText = "Inventory.dbo.devicelist";
$dstTable = "Inventory.dbo.NetInvDetail";
$CDPCmdText = "Inventory.dbo.CDPNeighbor";
$ComCmd = "select String from cmdb.dbo.ComStrings where StringType = 'Production'";
$Update1Cmd = "exec Inventory.dbo.spUpdateDevList";

$sysname = '1.3.6.1.2.1.1.5.0';
$ifDesc = '1.3.6.1.2.1.2.2.1.2';
$entPhysicalEntry = '1.3.6.1.2.1.47.1.1.1.1';
$cdpCacheEntry = '1.3.6.1.4.1.9.9.23.1.2.1.1';

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
	#print "Failed to create conenction object\n".Win32::OLE->LastError();
	cleanup("Failed to create conenction object\n".Win32::OLE->LastError(),1);
	exit 1;
}

$SrcRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SrcRS) or Win32::OLE->LastError() != 0 ) 
{
	#print "Failed to create source recordset object\n".Win32::OLE->LastError();
	cleanup("Failed to create source recordset object\n".Win32::OLE->LastError(),1);
	exit 1;
}
$dstRS = new Win32::OLE "ADODB.Recordset";
if (!defined($dstRS) or Win32::OLE->LastError() != 0 ) 
{
	#print "failed to create a destination recordset object\n".Win32::OLE->LastError();
	cleanup("failed to create a destination recordset object\n".Win32::OLE->LastError(),1);
	exit 1;
}
$CDPrs = new Win32::OLE "ADODB.Recordset";
if (!defined($dstRS) or Win32::OLE->LastError() != 0 ) 
{
	#print "failed to create a CDP recordset object\n".Win32::OLE->LastError();
	cleanup("failed to create a CDP recordset object\n".Win32::OLE->LastError(),1);
	exit 1;
}

$Cmd   = new Win32::OLE "ADODB.Command";
if (!defined($Cmd) or Win32::OLE->LastError() != 0 ) 
{
	#print "failed to create a command object\n".Win32::OLE->LastError();
	cleanup("failed to create a command object\n".Win32::OLE->LastError(),1);
	exit 1;
}

$CN->{Provider} = "sqloledb";
$CN->{Properties}{"Data Source"}->{value} = $DBServer;
$CN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open Connection\n";
$CN->open; 
if (Win32::OLE->LastError() != 0 ) 
{
	#print "cannot open source database connection\n".Win32::OLE->LastError();
	cleanup("cannot open source database connection\n".Win32::OLE->LastError(),1);
	exit 1;
}

$Cmd->{ActiveConnection} = $CN;
$Cmd->{CommandText} = $Update1Cmd;
$Cmd->{Execute}; 
if (Win32::OLE->LastError() != 0 ) 
{
	#print "error while executing command: \n$Update1Cmd \n".Win32::OLE->LastError();
	cleanup("error while executing command: \n$Update1Cmd \n".Win32::OLE->LastError(),1);
	exit 1;
}

print "fetching com string\n";
$SrcRS->Open ($ComCmd, $CN);
if (Win32::OLE->LastError() != 0 ) 
{
	#print "Failed to fetch comstr\n".Win32::OLE->LastError();
	cleanup("Failed to fetch comstr\n".Win32::OLE->LastError(),1);
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
	#print "Failed to fetch device list\n".Win32::OLE->LastError();
	cleanup("Failed to fetch device list\n".Win32::OLE->LastError(),1);
	exit 1;
}

$dstRS->{LockType} = 3; #adLockOptimistic
$dstRS->{ActiveConnection} = $CN;
$dstRS->{Source} = $dstTable;
$dstRS->Open;

if (Win32::OLE->LastError() != 0 ) 
{
	#print "Unable to open destination table\n".Win32::OLE->LastError();
	cleanup("Unable to open destination table\n".Win32::OLE->LastError(),1);
	exit 1;
}

$CDPrs->{LockType} = 3; #adLockOptimistic
$CDPrs->{ActiveConnection} = $CN;
$CDPrs->{Source} = $CDPCmdText;
$CDPrs->Open;

if (Win32::OLE->LastError() != 0 ) 
{
	#print "Unable to open CDP table\n".Win32::OLE->LastError();
	cleanup("Unable to open CDP table\n".Win32::OLE->LastError(),1);
	exit 1;
}

while ( !$SrcRS->EOF )
{	
	undef %cdpcach;
	undef %invitem;
	$Device = $SrcRS->{fields}{vcDeviceName}->{value};
	#print time . "   deleting old values for $Device\n";
	$CmdStr = "delete from $dstTable where Device = '$Device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) 
	{
		#print "error while executing command: \n$CmdStr \n".Win32::OLE->LastError();
		cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);
		exit 1;
	}
	$CmdStr = "delete from $CDPCmdText where lDevice = '$Device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) 
	{
		#print "error while executing command: \n$CmdStr \n".Win32::OLE->LastError();
		cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);
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
		printf("Connect Error: %s.\n", $error);
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
		$result = $session->get_table($ifDesc);
		if (!defined($result)) 
		{
			printf("IFDesc ERROR: %s.\n", $session->error);
			$SrcRS->{fields}{vcifDesc}->{value} = "Failed";
			$SrcRS->{fields}{vcMsg}->{value} = $session->error;
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
			$SrcRS->{fields}{vcMsg}->{value} = $session->error;
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
					if (Win32::OLE->LastError() != 0 ) 
					{
						#print "error while adding record to cdp table\n".Win32::OLE->LastError();
						cleanup("error while adding record to cdp table\n".Win32::OLE->LastError(),1);
						exit 1;
					}			
					$CDPrs->{fields}{lDevice}->{value}      = $dev;
					$CDPrs->{fields}{lInterface}->{value}   = $ints{$rem};
					$CDPrs->{fields}{RDevice}->{value}      = $rdevice;
					$CDPrs->{fields}{RDeviceIP}->{value}    = $cdpcach{$key}{'4'};
					$CDPrs->{fields}{RDeviceModel}->{value} = $cdpcach{$key}{'8'};
					$CDPrs->{fields}{ROSversion}->{value}   = $cdpcach{$key}{'5'};
					$CDPrs->{fields}{RInterface}->{value}   = $cdpcach{$key}{'7'};
				$CDPrs->Update; 
				if (Win32::OLE->LastError() != 0 ) 
				{
					#print "error while saving new CDP record\n".Win32::OLE->LastError();
					cleanup("error while saving new CDP record\n".Win32::OLE->LastError(),1);
					exit 1;
				}			
			}
		}			
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
						#print "error while adding record to inv table\n".Win32::OLE->LastError();
						cleanup("error while adding record to inv table\n".Win32::OLE->LastError(),1);
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
					#print "error while saving new Inv record\n".Win32::OLE->LastError();
					cleanup("error while saving new Inv record\n".Win32::OLE->LastError(),1);
					exit 1;
				}		
			}
			#print time . "   record saved\n";
		}
		$session->close;
	}	
	$SrcRS->Update;
	$SrcRS->Requery;
	$SrcRS->Movefirst;
	if (Win32::OLE->LastError() != 0 ) 
	{
		print "error while movefirst\n".Win32::OLE->LastError();
		cleanup("error while movefirst\n".Win32::OLE->LastError(),1);
		exit 1;
	}	
}
cleanup("Completed successfully.",0);
#print "Completed successfully.\n";
exit 0;

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
	undef $Cmd;
	if (defined($dstRS))
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

  $smtp->mail($from) ;
  $smtp->to($to) ;

  $smtp->data() ;
  $smtp->datasend("To: $to\n") ;
  $smtp->datasend("From: $from\n") ;
  $smtp->datasend("Subject: $subject\n") ;
  $smtp->datasend("\n") ;

#----- This part loops through your file and puts all the lines into your mail one by one
  foreach $body (@body) {
    $smtp->datasend("$body") ;
  }
  $smtp->dataend() ;
  $smtp->quit() ;
}
