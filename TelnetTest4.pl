#!/perl/bin/perl
use Net::Telnet 3.00;
$login = "username";
$password ="password";
#$hostname = "tuk-37t-3"; #@ARGV[0];
$hostname = @ARGV[0];
$Model = @ARGV[1];
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
print "Attempting to login to $hostname\nPrompt is set to $prompt\nModel:$Model\n";
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
	if ($Model == "1900")
		{
			@ret = $t->waitfor('/Menu/');
			if (scalar @ret == 0)
				{
					$errormsg = $t->errmsg;
					print "1900ErrOnMenu: $errormsg\n";
				}
			else
				{
					print "At 1900 menu, bringing up CLI\n";
					$t->print("k");
					print "sent K to go to CLI, waiting for CLI to come up\n";
					@ret = $t->waitfor($prompt);
					if (scalar @ret == 0)
						{
							$errormsg = $t->errmsg;
							($output, $match) = @ret;
							print "1900ErrOnCLI: $errormsg\n";
							print "Match:$match\nOutput:$output\n";
						}
					else
						{
							($output, $match) = @ret;
							print ("Successfully logged into a 1900\n");
						}
					}
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
			}
		}  
		print "now sending new line to check for proper prompt using print & wait method\n";
		$t->print("");
		($output, $match) = $t->waitfor($prompt);
		print "now printing results\n";
		print "Matched: $match\n$output\n";
		print "\n\nDone\n";
}
$t->close();