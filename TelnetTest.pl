#!/perl/bin/perl
use Net::Telnet 3.00;
$login = "username";
$password ="pwd";
$hostname = "tuk-37t-1"; #@ARGV[0];
#$hostip = "10.205.67.19"; # @ARGV[1];
$prompt = '/'.$hostname.'>/';

$t = Net::Telnet->new(  Timeout => 60,
                        Prompt=> $prompt,
                        Errmode => 'die' );
$fh = $t->input_log('h:/perlscript/telnettest.log');
$fh1 = $t->dump_log('h:/perlscript/telnettestdump.log');


print "calling login for $hostname\nPrompt is set to $prompt\n";
login($hostname);
print "returned from login routine\n";
print "now executing show int using print & wait method\n";
$t->print("show ip int br");
($output, $match) = $t->waitfor($prompt);
print "now printing results\n";
print "Matched: $match\n$output\n)";
print "\n\nDone\n";
$t->close();

sub login
{
	print "inside login, attempting to open connection to *$_[0]*\n";
	$t->open($_[0]);
	$t->login($login,$password);
}

