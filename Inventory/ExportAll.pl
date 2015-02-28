use strict;
use DBI();
use Sys::Hostname;
use English;
use MIME::Lite;

my ($logfile, $LogPath, $dbh, $strSQL, $tblName, $tblWhere, $strFields, @Fields, $OutFileName, $ToEmail);
my ($DBHost, $DBName, $DBUser, $DBpwd, $scriptFullName, $strFrom, @Headers, $x, $OutFilePath, $strResp);
my ($verbose, $LogLevel, $host, $ElapseSec, $StartTime, $sth, $strExportSQL, $FieldCount, $ExportWhere);
my (@tmp,$pathparts,$ShortName,$progname, $strExportLabel, $strHeaders, $key, $sth2, $ZipPathName, $strCmd);
my ($FromEmail, $ToEmail, $EmailSubject, $SMTPHost, $EmailBody, $EmailType, $InFile, $MIMETypeFile);
my (@EmailAttach, %MIMELookup, $goodpar, $LocationID, $email, @lines, $line, $CCEmail);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$mon ++;
$min = substr("0$min",-2);
$sec = substr("0$sec",-2);

$verbose    = 2;
$LogLevel   = 2;

$ToEmail = 'Siggi Bjarnason <siggi.bjarnason@clearwire.com>';
$CCEmail = 'Siggi Bjarnason <siggi.bjarnason@clearwire.com>';
$FromEmail = 'BH Performance Audit <BHscript@clearwire.com>';
$EmailSubject = "Telco/Pop/Transport Audit";
$EmailType = "HTML";
$EmailBody = "Please find enclosed today’s Transport Audit files. ";
$EmailBody .= "The data is refreshed daily and can be accessed on ";
$EmailBody .= "http://172.27.0.131/ while connected to NOC-WI. ";
$EmailBody .= "Please let me know if you have any questions.";
$SMTPHost= "172.27.0.125";

$InFile = "/var/tmp/AuditBody.htm";
$MIMETypeFile = "/var/tmp/MimeTypes.csv";

$LogPath = "/var/log/scripts/discovery";
$OutFilePath = "/home/data/tmp";
$ZipPathName = "/home/data/Audit-$mon-$mday-$year-$hour-$min-$sec.zip";
$tblName = "tblExports";
$tblWhere   = "";
$DBHost  = "localhost";
$DBName  = "inventory";
$DBUser  = "script";
$DBpwd   = "test123";
$EmailAttach[0] = $ZipPathName;
$ExportWhere = "";
$LocationID = "";

$scriptFullName = $PROGRAM_NAME;
$scriptFullName =~ s/\\/\//g;	
@tmp = split(/\//,$scriptFullName);
$pathparts = scalar @tmp;
$ShortName = $tmp[$pathparts-1];
($progname) = split(/\./,$ShortName);

$logfile = "$LogPath/$progname-$mon-$mday-$year.log";

$host = hostname;
$StartTime = time();

print "Logging to $logfile\n";
open(LOG,">>",$logfile) || die "cannot open logfile $logfile for append: $!";

$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                      "$DBUser", "$DBpwd",
                      {'RaiseError' => 1});

foreach $x (@ARGV)
{
	$goodpar = "false";
	$x = lc $x;
	$x =~ s/^\s+//;
	$x =~ s/\s+$//;
	@lines = split /=/, $x;
	if ($lines[0] eq "ew")
	{
		$ExportWhere = $lines[1];
		$goodpar = "true";
		logentry ("found export where clause of $ExportWhere\n",0,0);
	}
	if ($lines[0] eq "locid")
	{
		$LocationID = $lines[1];
		if ($LocationID =~ /^\d+$/)
		{
			$goodpar = "true";
			logentry ("found Location ID of $LocationID\n",0,0);
		}
		else
		{
			logentry ("Location ID of $LocationID is invalid as it has to be an integer\n",0,0);
		}
	}
	if ($lines[0] eq "email")
	{
		$email = "ok";
		if ($email eq "ok" )
		{
			logentry ("found email level of $email\n",0,0);
		}
		else
		{
			$ToEmail = $lines[1];
			logentry ("Found email address of $ToEmail\n",0,0);
		}
		$goodpar = "true";
	}
	if ($goodpar eq "false")
	{
		logentry ("Invalid option $x \n\n",0,0);
		exit();
	}
}

if ($email ne "ok")
{
	if ($ToEmail ne "")
	{
		print "This script has been preconfigured to send output via email to \n$ToEmail";
		if ($CCEmail ne "")
		{
			print " and copy $CCEmail";
		}
		print "\nTo accept that press enter, or type in a new email address:";
		$line = <STDIN>;
		chomp $line;
		if ($line ne "")
		{
			$ToEmail = $line;
			$CCEmail ='';
		}
	}
	else
	{
		print "No email address destination has been configure to send the output to.\n";
		print "Please enter a notification email address\n";
		$ToEmail = <STDIN>;
		chomp $ToEmail;
	}
}
	
if ($LocationID ne "")
{
	$strSQL = "SELECT * FROM tblLocationTypes where iLocationID = '$LocationID' limit 1";
	logentry ("$strSQL\n",3,2);
	$sth = $dbh->prepare($strSQL);
	$sth->execute();
	my $ref = $sth->fetchrow_hashref();
	$ExportWhere = $ref->{'vcWhere'}; 
}

if ($ExportWhere ne "")
{
	$ExportWhere = " where $ExportWhere";
}
else
{
	print "No filter on export files found, do you want to export all records?";
	$line = <STDIN>;
	chomp $line;
	$line = lc $line;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	unless ($line =~ /y.*/)
	{
		exit;
	}	
}

$strSQL = "SELECT * FROM $tblName $tblWhere";

logentry ("$strSQL\n",3,2);
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) 
{
  $strExportLabel = $ref->{'vcExportLabel'}; 
  $strFields = $ref->{'vcFields'}; 
  $strFrom = $ref->{'vcFrom'}; 
  $strHeaders = $ref->{'vcHeaders'};
	$strFields =~ s/, /,/g;	
	$strHeaders =~ s/, /,/g;	
	@Fields = split(/,/,$strFields);
	@Headers = split(/,/,$strHeaders);
	$FieldCount = scalar @Fields;
	$OutFileName = "$OutFilePath/$strExportLabel $mon-$mday-$year-$hour-$min-$sec.csv";
	logentry ("Exporting to $OutFileName\n",2,1);
  $strExportSQL = "select ";	
	for ($x=0; $x < $FieldCount; $x++)
	{
		$strExportSQL .= "'$Headers[$x]', ";
	}
	$strExportSQL = substr ($strExportSQL,0,-2);
  $strExportSQL .= " union (select ";	
	for ($x=0; $x < $FieldCount; $x++)
	{
		$strExportSQL .= "ifnull($Fields[$x],''), ";
	}
	$strExportSQL = substr ($strExportSQL,0,-2);
	$strExportSQL .= " into outfile '$OutFileName' FIELDS TERMINATED BY ',' ENCLOSED BY '\"'";
	$strExportSQL .= " from $strFrom $ExportWhere);";
	logentry ("$strExportSQL\n",3,2);
	$sth2 = $dbh->prepare($strExportSQL);
  $sth2->execute();
}
logentry ("Zipping output files up\n",2,1);
$strCmd = "zip -jm $ZipPathName $OutFilePath/* 2>&1";
logentry ("$strCmd\n",2,1);
$strResp = `$strCmd`;
logentry ("Results of Zip Operation:\n$strResp\n",2,1);
logentry ("Emailing results\n",2,1);
InitializeMIME();
MimeMail();
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

sub MimeMail
{
	my ($msg, @PathParts, $PartCount, $Filename, $Attachment, $Ext, $Base, $Type);
	
	$msg = MIME::Lite->new(
	    From    => $FromEmail,
	    To      => $ToEmail,
	    Cc      => $CCEmail,
	    Subject => $EmailSubject,
	    Type    => 'multipart/mixed'
	);
	
	$msg->attach(
	    Type     => $EmailType,
	    Data     => $EmailBody
	);
	
	foreach $Attachment (@EmailAttach)
	{
		$Attachment =~ s/\\/\//g;
		@PathParts = split(/\//,$Attachment);
		$PartCount = scalar @PathParts;
		$Filename = $PathParts[$PartCount-1];
		($Base, $Ext) = split(/\./,$Filename);
		$Type = $MIMELookup{$Ext};
		$msg->attach
		(
		    Type     => $Type,
		    Path     => $Attachment,
		    Filename => $Filename,
		    Disposition => 'attachment'
		);
	}
	### use Net:SMTP to do the sending
	$msg->send('smtp',$SMTPHost, Debug=>0 );
}

sub InitializeMIME
{
	$MIMETypeFile =~ s/\\/\//g;

	my ($Ext, $Type, $line);
	open(IN,"<",$MIMETypeFile) || die "cannot open InFile $MIMETypeFile for read: $!";
	foreach $line (<IN>)
	{
		chomp $line;
		($Ext,$Type) = split(/,/,$line);	
		$MIMELookup{$Ext} = $Type;
	}
	$InFile =~ s/\\/\//g;
	
	if ($InFile ne "")
	{
		if (-e $InFile)
		{
			$EmailBody = "";
			open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";
			foreach $line (<IN>)
			{
				$EmailBody .= $line;
			}
			close IN;
		}
		else
		{
			print "Can't find $InFile, using static EmailBody! \n";
		}
	}	
}