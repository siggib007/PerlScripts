#!/perl/bin/perl
use Net::Telnet 3.00;
$login = "username";
$password ="pwd?";
#$hostname = "tuk-37t-3"; #@ARGV[0];
$hostname = @ARGV[0];
#$prompt = '/'.$hostname.'#/';
#$prompt = @ARGV[1];
#$prompt = '/#/';
#'/name:|>|\#|console login:/'
$prompt = '/\#|\>/';
$t = Net::Telnet->new(  Timeout => 10,
                        Prompt=> $prompt,
                        Errmode => "return" );
$fh = $t->input_log('c:/perlscript/logs/telnettest.log');
$fh1 = $t->dump_log('c:/perlscript/logs/telnettestdump.log');
print "Attempting to login to $hostname\nPrompt is set to $prompt\n";
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
		print "now printing results\n";
		print "Matched: $match\n$output\n";
		print "\n\nDone\n";
	}
	$t->close();
}
