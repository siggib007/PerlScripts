use Net::SSH::W32Perl;
$user = "cwuser";
$pass ="CW2Work?";
$host = @ARGV[0];

$cmd = "show ver";

print "Connecting to $host\n";
my $ssh = new Net::SSH::W32Perl($host);
print "Login in...\n";
$ssh->login($user, $pass);
print "executing $cmd\n";
my($stdout, $stderr, $exit) = $ssh->cmd($cmd);
print "Done here is the results\n";
print $stdout