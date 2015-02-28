use Net::SSH::W32Perl;
$user = "cwuser";
$pass ="CW2Work?";
$host = @ARGV[0];

$cmd = "show ver";

my $ssh = Net::SSH::W32Perl->new($host,debug => 0);
print "Connecting to $host\n";
print "Login in...\n";
$ssh->login($user, $pass);
print "executing $cmd\n";
my($stdout, $stderr, $exit) = $ssh->cmd($cmd);
print "Done here is the results\n";
print "Standard out: $stdout\nStandard Error: $stderr\nExit code: $exit\n";