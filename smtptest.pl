use Net::Telnet 3.00;
use Net::SMTP;
use English;
use Sys::Hostname;

$host = hostname;

$SMTPHosts{"WA-WAN-SMTP-1"}= "172.27.0.125";
$SMTPHosts{"WA-WAN-SMTP-2"}= "172.27.0.126";
$SMTPHosts{"NOCTools"}= "172.25.200.20";
$SMTPHosts{"Nachoman"}= "172.25.200.100";
$SMTPHosts{"localhost"}= "127.0.0.1";

$t = Net::Telnet->new( Timeout => 6, Errmode => "return" );

$relay = "";
#$to = 'siggi.bjarnason@clearwire.com';
$to = "";
$from = 'CNEscript@clearwire.com';
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

while (($key,$value) = each %SMTPHosts) 
{
#	print "$key $value\n";
	PortTest ($value,25);
	if ($PortTest eq "Success")
	{
		$relay = $value;
		$relayname = $key;
		logentry ("$key $value responds on port 25, using as relay server\n");
		last;
	}
	else
	{
		logentry ("$key $value does not respond on port 25.\n");
	}
}
if ($relay eq "")
{
	print "None of the SMTP servers configured are responding. \n";
	print "Please provide a valid server name or IP or enter to disable email notification: \n";
	$relay = <STDIN>;
	chomp $relay;
	PortTest ($relay,25);
	until (($PortTest eq "Success") or ($relay eq ""))
	{
		print "$relay does not respond to SMTP. \n";
		print "Please provide a valid SMTP server name or IP or enter to disable email notification: \n";
		$relay = <STDIN>;
		chomp $relay;
		PortTest ($relay,25);
	}

}

if ($to ne "")
{
	print "This script has been preconfigured to send notification mail to \n$to\n";
	print "To accept that hit enter, or enter a new email address:";
	$line = <STDIN>;
	chomp $line;
	if ($line ne "")
	{
		$to = $line;
	}
}
else
{
	print "No email address destination has been configure.\n Please enter a notification email address\n";
	print " or hit enter to disable email notification: ";
	$to = <STDIN>;
	chomp $to;
}
if (($relay ne "") and ($to ne ""))
{
	logentry ("composing test mail body ..... \n");
	
	push @body, "Hello,\n";
	push @body, "This is a simple test of SMTP via perl. using single quotes for both address\n";
	push @body, "This is running under PID $PROCESS_ID by user $UID \n";
	push @body, "Running from host $host, sending mail via $relayname $relay \n";
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

sub PortTest
	{
		my($hostname, $port) = @_;
		if (defined($t->open(Host => $hostname, Port => $port)))
			{
				$PortTest="Success";
				$InUse = 1;
			}
		else
			{
				$PortTest="Fail";
			}
	}