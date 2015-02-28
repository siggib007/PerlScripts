use strict;
use net::SNMP;
use Win32::OLE 'in';
use Net::SMTP;

my ($device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,@hkeys,$entPhysicalEntry,$id,$outfile);
my ($tail, $type, $outstr, $inst, $FlashTable, $systemname, %Removable, $systemname);
my ($sqlcmd, $DBServer,$relay, $to, $from, $subject, $CN, $SrcRS, %hComStr, $CmdStr);
my ($FlashInvRS,$ComCmd, $StartTime, $StopTime, @body, $Cmd, $ErrRS, $ErrTable);
my ($FlashInst, $FlashName, $ciscoFlashDeviceEntry, $len, %FlashDev, $value);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$DBServer = "by2netsql01";
$relay = "tk2smtp.phx.gbl";
$to = "siggib\@microsoft.com";
$from = "siggib\@microsoft.com";
$subject = "Flash Inv";

$ComCmd = "select StringType, String from cmdb.dbo.ComStrings order by iStringID";
$sqlcmd = 'select distinct devicename from Inventory.dbo.vwsup2_720';
$FlashTable = "Inventory.dbo.FlashInv";
$ErrTable = "Inventory.dbo.ErrLog";

$Removable{1} = "True";
$Removable{2} = "False";

$sysname = '1.3.6.1.2.1.1.5.0';
$ciscoFlashDeviceEntry = '1.3.6.1.4.1.9.9.10.1.1.2.1';

$outfile = "e:/siggib/FlashInv.log";

$StartTime = time;

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

logentry( "Started processing at $mon/$mday/$year $hour:$min\n") ;
$CN    = new Win32::OLE "ADODB.Connection";
if (!defined($CN) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create conenction object\n".Win32::OLE->LastError(),1);}

$SrcRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SrcRS) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create source recordset object\n".Win32::OLE->LastError(),1);}

$FlashInvRS = new Win32::OLE "ADODB.Recordset";
if (!defined($FlashInvRS) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a FlashCont recordset object\n".Win32::OLE->LastError(),1);}

$ErrRS = new Win32::OLE "ADODB.Recordset";
if (!defined($FlashInvRS) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a error recordset object\n".Win32::OLE->LastError(),1);}

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

logentry( "attempting to open FlashInv destination table\n");
$FlashInvRS->{LockType} = 3; #adLockOptimistic
$FlashInvRS->{ActiveConnection} = $CN;
$FlashInvRS->{Source} = $FlashTable;
$FlashInvRS->Open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Unable to open $FlashTable destination table\n".Win32::OLE->LastError(),1);}

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
	
	$CmdStr = "delete from $FlashTable where vcDevName = '$device'";
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
	$systemname = $result->{$sysname};
	$outstr = "Device Name: " . $systemname . "\n";
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


		
	foreach $key(sort(keys %FlashDev))
	{
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

		$year = $year+1900;
		$min = substr("0$min",-2);
		$mon = $mon + 1;	
		
		$outstr	= $FlashDev{$key}{'7'} . "\t" . $FlashDev{$key}{'8'} . "\t" . $Removable{$FlashDev{$key}{'13'}} . "\t" . $FlashDev{$key}{'2'} . "\t" . "\n";
		logentry( $outstr);
		$FlashInvRS->AddNew;
		if (Win32::OLE->LastError() != 0 ) { cleanup("error while adding record to FlashInv\n".Win32::OLE->LastError(),1);}
			$FlashInvRS->{fields}{vcDeviceName}->{value}      = $systemname;
			$FlashInvRS->{fields}{vcFlashName}->{value}     = $FlashDev{$key}{'7'};
			$FlashInvRS->{fields}{vcflashdescr}->{value}   = $FlashDev{$key}{'8'};
			$FlashInvRS->{fields}{bFlashRemoveable}->{value}      = $Removable{$FlashDev{$key}{'13'}};
			$FlashInvRS->{fields}{iFlashSize}->{value}    = $FlashDev{$key}{'2'};
			$FlashInvRS->{fields}{iFlashMinPartition}->{value} = $FlashDev{$key}{'3'};
			$FlashInvRS->{fields}{iFlashMaxPartion}->{value} = $FlashDev{$key}{'4'};
			$FlashInvRS->{fields}{iFlashPartionSize}->{value} = $FlashDev{$key}{'5'};
			$FlashInvRS->{fields}{iFlashChipCount}->{value} = $FlashDev{$key}{'6'};
			$FlashInvRS->{fields}{vcDevName}->{value} = $device;
			$FlashInvRS->{fields}{iSNMPIndexID}->{value} = $key;
			$FlashInvRS->{fields}{dtTimeStamp}->{value} = "$mon/$mday/$year $hour:$min";
		$FlashInvRS->Update; 
		if (Win32::OLE->LastError() != 0 ) {cleanup("error while saving new FlashCont\n".Win32::OLE->LastError(),1);}	
	}
	undef (%FlashDev);
	$session->close;
	undef $session;
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