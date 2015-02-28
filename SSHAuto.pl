use Net::SSH::Perl;
use Term::ReadKey;
use English;
$cmd = "show chassis hardware";
$InFile = "";
$outfile = "";
$login = "";

if ($InFile eq "")
{
	print "Please specify the name of the IP Address list file:";
	$InFile = <STDIN>;
	chomp $InFile;
	$InFile =~ s/\\/\//g;
}

until (-e $InFile)
{
	print "The input file '$InFile' doesn't exists, please enter file name with complete path if nessisary:\n";
	$InFile = <STDIN>;
	chomp $InFile;
	$InFile =~ s/\\/\//g;
}

if ($outfile eq "")
{
	print "Please specify output file name: ";
	$outfile = <STDIN>;
	chomp $outfile;
	$outfile =~ s/\\/\//g;
}

if ($outfile eq "")
{
	print "Please enter your username: ";
	$login = <STDIN>;
	chomp $login;
}

print "Please enter your password: ";
ReadMode('noecho');
$password = ReadLine(0);
chomp $password;
ReadMode 'normal';
open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
print "outputing to $outfile ... \n";

print "reading from $InFile ...\n";
open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";

foreach $host (<IN>)
{
	chomp($host);
	$host =~ s/^\s+//;
	$host =~ s/\s+$//;
	if ($host ne "")
	{	
		print "Connecting to $host\n";
		my $ssh = Net::SSH::Perl->new($host);
		print "Login in...\n";
		$ssh->login($login, $password);
		print "executing $cmd\n";
		my($stdout, $stderr, $exit) = $ssh->cmd($cmd);
		print "Done. Exit Code was $exit and stderr contains: $stderr\n ";
		print OUT "$host\n$stdout\n";
	}
}