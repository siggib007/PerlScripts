use MIME::Lite;
$InFile = "C:/Scripts/PerlScript/Inventory/AuditBody.htm";
$MIMETypeFile = "C:/Scripts/PerlScript/MimeTypes.csv";
$EmailBody = "<html><Body><h3>Attached is the audit in a zip file</h3></Body></HTML>";
$EmailType = "HTML";
$FromEmail = 'SuperGeeks <siggi@supergeek.us>';
$ToEmail = 'Siggi Bjarnason <siggi.bjarnason@clearwire.com>';
$EmailSubject = "Transport Audit";
$SMTPHost= "172.27.0.125";
$EmailAttach[0] = "/home/data/Audit.zip";
$EmailAttach[1] = "C:/usr/NetInv.zip";
$EmailAttach[2] = "C:/usr/Crontab.txt";
$EmailAttach[3] = "C:/WebRoot/img/WMSmileyConstruction.gif";

InitializeMIME();
MimeMail();

print "Done";
    
sub MimeMail
{
	my ($msg, @PathParts, $PartCount, $Filename, $Attachment, $Ext, $Base, $Type);
	
	$msg = MIME::Lite->new(
	    From    => $FromEmail,
	    To      => $ToEmail,
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