use Net::SSH::Perl;
use Term::ReadKey;
use English;

print "Please specify hostname or IP address: ";
$host = <STDIN>;
chomp $host;

print "Please enter your username for login to $host: ";
$login = <STDIN>;
chomp $login;

print "Please enter the password for $login\@$host: ";
ReadMode('noecho');
$password = ReadLine(0);
chomp $password;
ReadMode 'normal';

print "\nPlease specify command to execute on host $host: ";
$cmd = <STDIN>;
chomp $cmd;


#$cmd = "show ver";
print "Connecting to $host\n";
my $ssh = Net::SSH::Perl->new($host);
print "Login in...\n";
$ssh->login($login, $password);
print "executing $cmd\n";
my($stdout, $stderr, $exit) = $ssh->cmd($cmd);
print "Done. Exit Code was $exit and stderr contains: $stderr\n here is the output:\n$stdout\n";
