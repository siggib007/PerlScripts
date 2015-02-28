use Net::SSH::Expect;
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
print "\n\nConnecting to $host\n";
my $ssh = Net::SSH::Expect->new (
            host => $host,
            log_stdout => 1, 
            password=> $password, 
            user => $login, 
            raw_pty => 1);
#print "starting the SSH proccess...\n";
$ssh->run_ssh() or die "SSH process couldn't start: $!";
$ssh->waitfor('password:');
#$before = $ssh->before();
#$match = $ssh->match();
#$after = $ssh->after();
#print $before . $match . $after . "\n";
$ssh->send($password);
#$output = $ssh->peek(2);
#print "$output";
$ssh->waitfor('#');

#print "$cmd\n";
my $stdout = $ssh->exec($cmd);
print "$stdout\n";
#print "Done here is the results\n";
#print $stdout
$ssh-close();