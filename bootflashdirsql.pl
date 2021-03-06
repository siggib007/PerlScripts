use strict;
use net::SNMP;
use Win32::OLE 'in';
use Net::SMTP;

my ($device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,@hkeys,$entPhysicalEntry,$id,$outfile);
my ($FlashFileEntry, $ConfigRegEntry, %FlashFiles, $tail, $type, $outstr, $inst, %FileStatus, %FileType, $curReg);
my ($Bootimg, $NextReg, $sqlcmd, $DBServer,$relay, $to, $from, $subject, $CN, $SrcRS, $ConfRegRS, %hComStr, $CmdStr);
my ($FlashContTable, $FlashContRS, $ConfRegTable,$ComCmd, $StartTime, $StopTime, @body, $Cmd, $ErrRS, $ErrTable);
my ($FlashInst, $FlashName, $ciscoFlashDeviceEntry, $len, %FlashDev, $value);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$DBServer = "by2netsql01";
$relay = "tk2smtp.phx.gbl";
$to = "siggib\@microsoft.com";
$from = "siggib\@microsoft.com";
$subject = "Boot Flash Dir";

$ComCmd = "select StringType, String from cmdb.dbo.ComStrings order by iStringID";
$sqlcmd = 'select deviceName from Inventory.dbo.vwNewNonGold4948';
$ConfRegTable = "Inventory.dbo.ConfRegs";
$FlashContTable = "Inventory.dbo.FlashContent";
$ErrTable = "Inventory.dbo.ErrLog";

$FileStatus{1} = "Deleted";
$FileStatus{2} = "InvalidCheckSum";
$FileStatus{3} = "Valid";

$FileType{1} = "Unknown";
$FileType{2} = "Config";
$FileType{3} = "Image";
$FileType{4} = "Directory";
$FileType{5} = "Crashinfo";

$sysname = '1.3.6.1.2.1.1.5.0';
$FlashFileEntry = '1.3.6.1.4.1.9.9.10.1.1.4.2.1.1';
$ConfigRegEntry = '1.3.6.1.4.1.9.9.195.1.2.1';
$ciscoFlashDeviceEntry = '1.3.6.1.4.1.9.9.10.1.1.2.1';

$outfile = "h:/perlscript/bootflashdir.log";

$StartTime = time;

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

logentry( "Started processing at $mon/$mday/$year $hour:$min\n") ;
$CN    = new Win32::OLE "ADODB.Connection";
if (!defined($CN) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create conenction object\n".Win32::OLE->LastError(),1);}

$SrcRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SrcRS) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create source recordset object\n".Win32::OLE->LastError(),1);}

$ConfRegRS = new Win32::OLE "ADODB.Recordset";
if (!defined($ConfRegRS) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a ConfReg recordset object\n".Win32::OLE->LastError(),1);}

$FlashContRS = new Win32::OLE "ADODB.Recordset";
if (!defined($FlashContRS) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a FlashCont recordset object\n".Win32::OLE->LastError(),1);}

$ErrRS = new Win32::OLE "ADODB.Recordset";
if (!defined($FlashContRS) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a error recordset object\n".Win32::OLE->LastError(),1);}

$Cmd   = new Win32::OLE "ADODB.Command";
if (!defined($Cmd) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a command object\n".Win32::OLE->LastError(),1);}

$CN->{Provider} = "sqloledb";
$CN->{Properties}{"Data Source"}->{value} = $DBServer;
$CN->{Properties}{"Integrated Security"}->{value} = "SSPI";

logentry( "Attempting to open Connection\n");
$CN->open; 
if (Win32::OLE->LastError() != 0 ) { cleanup("cannot open source database connection\n".Win32::OLE->LastError(),1);}

logentry( "fetching com string\n");
$SrcRS->Open ($ComCmd, $CN);
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch comstr\n".Win32::OLE->LastError(),1);}
undef %hComStr;
while ( !$SrcRS->EOF )
{
	$hComStr{$SrcRS->{fields}{StringType}->{value}} = $SrcRS->{fields}{String}->{value};
	#print $SrcRS->{fields}{StringType}->{value} . "=>" . $SrcRS->{fields}{String}->{value} . "\n";
	$SrcRS->MoveNext;
}
$SrcRS->Close;

foreach $key(keys %hComStr)
{
	$comstr = $hComStr{$key};
	#print "$key -> $comstr\n";
}

$comstr = $hComStr{'Production'};

logentry( "attempting to fetch source data\n");
$SrcRS->Open ($sqlcmd, $CN); 
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch device list\n".Win32::OLE->LastError(),1);}

logentry( "attempting to open ConfReg destination table\n");
$ConfRegRS->{LockType} = 3; #adLockOptimistic
$ConfRegRS->{ActiveConnection} = $CN;
$ConfRegRS->{Source} = $ConfRegTable;
$ConfRegRS->Open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Unable to open ConfReg destination table\n".Win32::OLE->LastError(),1);}

logentry( "attempting to open FlashCont destination table\n");
$FlashContRS->{LockType} = 3; #adLockOptimistic
$FlashContRS->{ActiveConnection} = $CN;
$FlashContRS->{Source} = $FlashContTable;
$FlashContRS->Open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Unable to open FlashCont destination table\n".Win32::OLE->LastError(),1);}

logentry( "attempting to open errlog destination table\n");
$ErrRS->{LockType} = 3; #adLockOptimistic
$ErrRS->{ActiveConnection} = $CN;
$ErrRS->{Source} = $ErrTable;
$ErrRS->Open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Unable to open errlog destination table\n".Win32::OLE->LastError(),1);}

$Cmd->{ActiveConnection} = $CN;

while ( !$SrcRS->EOF )
{
	$device = $SrcRS->{fields}{devicename}->{value};
	logentry( "Device: $device\n");	
	
	$CmdStr = "delete from $ConfRegTable where DeviceName = '$device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);}
	
	$CmdStr = "delete from $FlashContTable where DeviceName = '$device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);}

	$CmdStr = "delete from $ErrTable where DeviceName = '$device'";
	$Cmd->{CommandText} = $CmdStr;
	$Cmd->{Execute}; 
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while executing command: \n$CmdStr \n".Win32::OLE->LastError(),1);}

	($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr);
	if (!defined($session)) 
	{
	      deviceskip ("Session ERROR: " . $error);
	}
	if ($error ne '')
	{
		deviceskip ("Session ERROR: " . $error);
	}
	
	$result = $session->get_request($sysname);
	#if (0)
	{
		if (!defined($result))
		{
			logentry("Production string didn't work, trying others\n");
			foreach $key(keys %hComStr)
			{
				logentry("Trying $key string\n");
				$comstr = $hComStr{$key};
				#print "$key => $comstr\n";
				if (defined($result)) 
				{
					$session->close;
					undef $session;		
				}
				($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr);
				if (!defined($session)) 
				{
					logentry("$key string didn't work during connect, trying next.\n");
					next;
				}			
				$result = $session->get_request($sysname);
				if (defined($result)) 
				{
					logentry("$key string worked\n");
					last;
				}
				else
				{
					logentry("$key string didn't work during get, trying next.\n");
				}
			}
		}
	}
	if (!defined($result))
	{
		deviceskip ("Sysname ERROR: " . $session->error);
	}
	$outstr = "Device Name: " . $result->{$sysname} . "\n";
	logentry($outstr);
	$result = $session->get_table($ciscoFlashDeviceEntry);
	if (!defined($result))
	{
		deviceskip ("FlashDevice ERROR: " . $session->error);
	}

	%reshash = %$result;
	foreach $key(sort(keys %reshash)) 
	{ 
		if ($reshash{$key} ne '')
		{
			$len = length($ciscoFlashDeviceEntry);
			$tail = substr($key,$len+1);
			($type,$inst) = split(/\./,$tail);
			$FlashDev{$inst}{$type} = $reshash{$key};
			$value=$reshash{$key};
		}
	}

	$result = $session->get_table($ConfigRegEntry);
	if (!defined($result))
	{
		deviceskip ("ConfReg ERROR: " . $session->error);
	}
	%reshash = %$result;
	$curReg = "$ConfigRegEntry.1.1000";
	$NextReg = "$ConfigRegEntry.2.1000";
	$Bootimg = "$ConfigRegEntry.3.1000";

	$ConfRegRS->AddNew;
	if (Win32::OLE->LastError() != 0 ) { cleanup("error while adding record to ConfReg table\n".Win32::OLE->LastError(),1);}
		$ConfRegRS->{fields}{DeviceName}->{value} = $device;
		$ConfRegRS->{fields}{CurReg}->{value}     = $reshash{$curReg};
		$ConfRegRS->{fields}{NextReg}->{value}    = $reshash{$NextReg};
		$ConfRegRS->{fields}{BootImg}->{value}    = $reshash{$Bootimg};
	$ConfRegRS->Update; 
	if (Win32::OLE->LastError() != 0 ) {cleanup("error while saving new ConfReg record\n".Win32::OLE->LastError(),1);}
	
	$outstr = "Current registry: " . $reshash{$curReg} . "\nNext registry: " . $reshash{$NextReg} . "\nBootImage: " . 
				$reshash{$Bootimg} . "\n\nContents of flash:\n";
	
	logentry($outstr);
	
	$result = $session->get_table($FlashFileEntry);
	if (!defined($result))
	{
		deviceskip ("Flash Dir ERROR: " . $session->error);
	}
	
	%reshash = %$result;
	foreach $key(sort(keys %reshash)) 
	{ 
		if ($reshash{$key} ne '')
		{
			$tail = substr($key,length($FlashFileEntry)+1);
			($type, $FlashInst) = split(/\./,$tail);
			$inst = substr($tail,length($type));
			if ($type eq '5')
			{
				$FlashFiles{$inst}{$type} = $FlashDev{$FlashInst}{'7'} . ":" . $reshash{$key};
			}
			else
			{
				$FlashFiles{$inst}{$type} = $reshash{$key};	
			}
		}
	}
		
	foreach $key(sort(keys %FlashFiles))
	{
		$outstr	= $FlashFiles{$key}{'5'} . "\t" . $FlashFiles{$key}{'2'} . "\t" . $FileType{$FlashFiles{$key}{'6'}} . "\t" . $FlashFiles{$key}{'3'} . "\t" . $FileStatus{$FlashFiles{$key}{'4'}} . "\n";
		logentry( $outstr);
		$FlashContRS->AddNew;
		if (Win32::OLE->LastError() != 0 ) { cleanup("error while adding record to FlashCont\n".Win32::OLE->LastError(),1);}
			$FlashContRS->{fields}{DeviceName}->{value}      = $device;
			$FlashContRS->{fields}{FileName}->{value}     = $FlashFiles{$key}{'5'};
			$FlashContRS->{fields}{FileSize}->{value}   = $FlashFiles{$key}{'2'};
			$FlashContRS->{fields}{FileType}->{value}      = $FileType{$FlashFiles{$key}{'6'}};
			$FlashContRS->{fields}{FileHash}->{value}    = $FlashFiles{$key}{'3'};
			$FlashContRS->{fields}{FileStatus}->{value} = $FileStatus{$FlashFiles{$key}{'4'}};
		$FlashContRS->Update; 
		if (Win32::OLE->LastError() != 0 ) {cleanup("error while saving new FlashCont\n".Win32::OLE->LastError(),1);}	
	}
	$session->close;
	undef $session;
	undef %FlashFiles;
	$SrcRS->MoveNext;
	logentry("\n\n\n");
}
cleanup('Done',0);

sub cleanup
{
	my($closemsg,$exitcode) = @_;
	my($isec, $imin, $ihour, $body);	
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
	if (defined($ConfRegRS))
	{		
		$ConfRegRS->Close;
		undef $ConfRegRS;
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
	push @body, "$closemsg\n";
	push @body, "\nStopped processing at $mon/$mday/$year $hour:$min\n";
	push @body, "elapse time $isec seconds; $imin minutes; $ihour hours.\n";
	push @body, "exiting with exit code $exitcode\n";
	foreach $body (@body) 
	{
		logentry($body);
	}
	send_mail();
	close(OUT);	
	exit $exitcode;
}

sub send_mail 
{
my ($smtp, $body);
	
	$smtp = Net::SMTP->new($relay, Debug => 0); # Set Debug to 1 if you have any problems
	if (!defined($smtp))
	{
		logentry( "Failed to open mail session to $relay\n");
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

sub logentry
{
	my($strmsg) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);	
	$mon = $mon + 1;
	
	print "$mon/$mday/$year $hour:$min  $strmsg";
	print OUT "$mon/$mday/$year $hour:$min  $strmsg";
}	

sub deviceskip
{
	my($strmsg) = @_;
	my($errmsg);
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);	
	$mon = $mon + 1;
	
	$strmsg =~ s/\n/ /g;
	$strmsg =~ s/\'//g;
	$errmsg = "$strmsg. Skipping device";
	logentry ("$errmsg\n");
	$ErrRS->AddNew;
	if (Win32::OLE->LastError() != 0 ) { cleanup("Error while adding record to ErrLog table\n".Win32::OLE->LastError(),1);}
		$ErrRS->{fields}{DeviceName}->{value}  = $device;
		$ErrRS->{fields}{ErrMsg}->{value}      = $errmsg;
		$ErrRS->{fields}{dtTimeStamp}->{value} = "$mon/$mday/$year $hour:$min";
	$ErrRS->Update; 
	if (Win32::OLE->LastError() != 0 ) {cleanup("Error while saving \"$errmsg\" to a new ErrLog record\n".Win32::OLE->LastError(),1);}	
	if (defined($session))
	{
		$session->close;
		undef $session;
	}
	$SrcRS->MoveNext;
	next;
}