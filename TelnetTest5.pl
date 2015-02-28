use Net::Telnet 3.00;
use Term::ReadKey;
use English;

$numin = scalar(@ARGV);
if ($numin != 1)
{
	print "\nInvalid usage: hostname or IP is required and you didn't supply it.\n\n";
	print "Correct usage: perl $PROGRAM_NAME hostname\n\n";
	print "hostname: an IP address or DNS hostname to connect to\n";
	print "Ex: perl $PROGRAM_NAME 10.10.10.10\n\n";
	print "Exiting abnormally.\n";
	exit(5);
}

$hostname = @ARGV[0];
$prompt = '/\#|\>/';
print "Please enter your username for login to $hostname: ";
$login = <STDIN>;
chomp $login;
print "Please enter the password for $login\@$hostname: ";
ReadMode('noecho');
$password = ReadLine(0);
chomp $password;
ReadMode 'normal';

$t = Net::Telnet->new(  Timeout => 10,
                        Prompt=> $prompt,
                        Errmode => "return" );
$fh = $t->input_log('c:/perlscript/logs/telnettest5.log');
$fh1 = $t->dump_log('c:/perlscript/logs/telnettestdump5.log');
print "\nAttempting to login to $hostname\nPrompt is set to $prompt\n";
#$errormsg = $t->errmsg();
#$ret = scalar $t;
#print "Open returned:$ret:\nError: $errormsg\n";
if (!defined($t->open($hostname)))
{
	$errormsg = $t->errmsg();
	print "Failed to connect to $hostname: $errormsg\n";
}
else
{
	@ret = $t->login($login,$password);
	if (scalar @ret == 0)
	{
		print "failed to login\n";
	}
	else
	{	
		print "Login complete\n";
		print "now sending new line to check for proper prompt using print & wait method\n";
		$t->print("");
		($output, $match) = $t->waitfor($prompt);
		$output = substr $output, 2;
		$lineprompt = $output . $match;
		print "Prompt is: $lineprompt\n";
		print "now executing show pbt tunnel using print & wait method\n";
		$t->print("pbt en show");
		($output, $match) = $t->waitfor($prompt);
		$output = substr $output, 1;
		print "now printing results\n$output$match\n";
		print "\nDone\n";
	}
	$t->close();
}
