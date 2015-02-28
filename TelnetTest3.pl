#!/perl/bin/perl
use Net::Telnet 3.00;
use English;

$numin = scalar(@ARGV);
if ($numin != 1)
{
	print "\nInvalid usage: hostname or IP is required and you didn't supply it.\n\n";
	print "Correct usage: perl $PROGRAM_NAME hostname\n\n";
	print "hostname: an IP address or DNS hostname ot connect to\n";
	print "Ex: perl $PROGRAM_NAME 10.10.10.10\n\n";
	print "Exiting abnormally.\n";
	exit(5);
}

$hostname = @ARGV[0];
$Port = 23;
$t = Net::Telnet->new(  Timeout => 10,
                        Errmode => "return" );
$fh = $t->input_log('c:/perlscript/logs/telnettest23.log');
$fh1 = $t->dump_log('c:/perlscript/logs/telnettestdump23.log');
print "Attempting to login to $hostname\n\n";
if (!defined($t->open(Host => $hostname, Port => $Port)))
{
	$errormsg = $t->errmsg();
	print "Failed to connect to $hostname: $errormsg\n";
}
else
{
	$output = $t->get();
	print "Established a connection\n";
	print "reading from connection then disconnecting:\n$output\n";
	$t->close();
	print "\nDone\n";
}
undef $t;