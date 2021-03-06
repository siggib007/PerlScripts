use Net::SMTP;
use English;
use Sys::Hostname;

$host = hostname;


$relay = "randy";
$to = 's@bjarnason.us';
$from = 's@siggiandmarly.net';
$subject = "SMTP test email";

$seq = 0;
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname-$seq.log";
while (-e $logfile)
{
	print "$logfile in use, increasing suffix\n";
	$seq ++;
	$logfile = "$progname-$seq.log";
}
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");


if (($relay ne "") and ($to ne ""))
{
	logentry ("composing test mail body ..... \n");
	
	push @body, "<html>\n<head>\n</head>\n<body>\n";
	push @body, "Hello,<br>\n";
	push @body, "<p>This is a simple test of SMTP via perl. using single quotes for both address. \n";
	push @body, "This is running under PID $PROCESS_ID by user $UID</p> \n";
	push @body, "<p>Running from host $host, sending mail via $relayname $relay </p>\n";
	push @body, "</body>\n</html>\n";
	logentry ("Now sending the test mail via $relayname $relay .... \n");

	send_mail();
}
else
{
	logentry ("No SMTP server configured or no notification email provided, can't send email\n");
}
logentry ("Done!!!\n");

close(LOG);
exit 0;


sub send_mail 
{
my ($smtp, $body);
	
	$smtp = Net::SMTP->new($relay, Debug => 0); # Set Debug to 1 if you have any problems
	if (!defined($smtp))
	{
		logentry ("Failed to open mail session to $relay\n");
		close (LOG) or warn "error while closing log file $logfile: $!" ;		
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
		$smtp->datasend("Content-Type: text/html; charset=ISO-8859-1\n");
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
		my($outmsg) = @_;
		
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year = $year+1900;
		$min = substr("0$min",-2);
		$mon = $mon + 1;
		$sec = substr("0$sec",-2);
		
		print "$mon/$mday/$year $hour:$min:$sec $outmsg";
		print LOG "$mon/$mday/$year $hour:$min:$sec $outmsg";
	}

