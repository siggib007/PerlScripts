use strict;
use Net::Telnet 3.00;
use Term::ReadKey;
use English;

my (@lines, $x, $hostname, $login, $dir, $goodpar, $password, $prompt, $t, $errormsg, $output, $match);
my ($outfile, $outfileR, $numlines, @lineparts, $i, @pbtService, @subport, @ret, $promptname, $lineprompt);

$hostname = "";
$login = "";
$dir = "";

print "\nThis script will login to a specified Ciena 5305 gater information about PBT services and sub ports\n";
print "then it will generate an augment file and a roll back file to configure performance management containers\n";
print "for each PBT Service and subport. Use 'perl $PROGRAM_NAME help' for syntax of optional arguments\n\n\n";
foreach $x (@ARGV)
{
	$goodpar = "false";
	@lines = split /=/, $x;
	if ($lines[0] eq "host")
	{
		$hostname = $lines[1];
		$goodpar = "true";
		print "found hostname of $hostname\n";
	}
	if ($lines[0] eq "user")
	{
		$login = $lines[1];
		$goodpar = "true";
		print "found username of $login\n";
	}
	if ($lines[0] eq "dir")
	{
		$dir = $lines[1];
		$dir =~ s/\\/\//g;
		if (substr ($dir,-1) ne "/")
		{ 
			$dir .= "/";
		}
		$goodpar = "true";
		print "found destination directory of $dir\n";
	}
	if ($lines[0] eq "help")
	{
		$goodpar = "true";
		print "Usage: perl $PROGRAM_NAME options\n\n";
		print "The following options can be used in any order\n";
		print "help: Prints this output and exits\n";
		print "host=hostname: DNS name or IP address of a Ciena 5305 you need PM containers for.\n";
		print "user=username: login user name.\n";
		print "dir=dirname: relative or absolute path where you want the resulting files stored.\n\n";
		print "Ex: perl $PROGRAM_NAME host=10.42.160.12 user=jsmith dir=/home/jsmith/augments\n\n";
		exit();
	}
	if ($goodpar eq "false")
	{
		print "Invalid option $x  Try 'perl $PROGRAM_NAME help' for syntax\n\n";
	}
}

if ($dir eq "")
{
	print "No destination directory specified, assuming current directory.\n";
#	print "See 'perl $PROGRAM_NAME help' for proper syntax for specifying destination directory\n\n";
}

if ($hostname eq "")
{
	print "Please specify hostname or IP address of a Ciena 5305 you need PM containers for: ";
	$hostname = <STDIN>;
	chomp $hostname;
}

if ($login eq "")
{
	print "Please enter your username for login to $hostname: ";
	$login = <STDIN>;
	chomp $login;
}

print "Please enter the password for $login\@$hostname: ";
ReadMode('noecho');
$password = ReadLine(0);
chomp $password;
ReadMode 'normal';

$prompt = '/\#|\>/';

$t = Net::Telnet->new(  Timeout => 10,
                        Prompt=> $prompt,
                        Errmode => "return" );
#$fh = $t->input_log('c:/perlscript/logs/telnettest5.log');
#$fh1 = $t->dump_log('c:/perlscript/logs/telnettestdump5.log');
print "\nAttempting to login to $hostname\n\n";
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
		$t->print("");
		($output, $match) = $t->waitfor($prompt);
		$output = substr $output, 2;
		$promptname = $output;
		if ($promptname =~ /\*$/)
		{
			$promptname = substr $promptname,0, -1;
		}
		$lineprompt = $output . $match;
		
		$outfile = "$dir$promptname-PMAugment.txt";

		open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
		
		$outfileR = "$dir$promptname-PMRollback.txt";

		open(ROUT,">",$outfileR) || die "cannot open outfile $outfileR for write: $!";

		print "hostname according to prompt is: $promptname\n";
		print "Prompt is: $lineprompt\n";
		print "gathering pbt service information\n";
		$t->print("pbt service show");
		($output, $match) = $t->waitfor($prompt);
		$output = substr $output, 1;
		@lines = split /\n/, $output;
		$numlines = scalar(@lines);
#		print "\nParsing $numlines lines of PBT Tunnel output\n";
		$x=0;
		for ($i = 6; $i < $numlines - 3; $i++) 
		{
			@lineparts = split /\|/, $lines[$i];
			$lineparts[1]=~ s/\s+$//;
			$lineparts[1] =~ s/^\s+//;
			$pbtService[$x]=$lineparts[1];
#			print "$lineparts[1]\n";
			$x++;
		}
		print "gathering sub port information\n";
		$t->print("sub show");
		($output, $match) = $t->waitfor($prompt);
		$output = substr $output, 1;
		@lines = split /\n/, $output;
		$numlines = scalar(@lines);
#		print "\nParsing $numlines lines of sub port output\n";
		$x=0;
		for ($i = 5; $i < $numlines - 2; $i++) 
		{
			@lineparts = split /\|/, $lines[$i];
			$lineparts[1]=~ s/\s+$//;
			$lineparts[1] =~ s/^\s+//;
			$lineparts[2]=~ s/\s+$//;
			$lineparts[2] =~ s/^\s+//;
			if ($lineparts[1] eq 'Name')
			{
#				print "$lineparts[2]\n";
				$subport[$x] = $lineparts[2];
				$x++;
			}
		}
		print "generating PBT service PM configuration\n";
		foreach $x (@pbtService)
		{
			print OUT "pm create service $x pm-instance $x\_BCPM profile-type Container bin-count 2\n";
			print OUT "pm enable pm-instance $x\_BCPM\n";
			print ROUT "pm disable pm-instance $x\_BCPM\n";
			print ROUT "pm delete pm-instance $x\_BCPM\n";
		}
		print "generating sub port PM configuration\n";
		foreach $x (@subport)
		{
			print OUT "pm create sub-port $x pm-instance $x\_BCPM profile-type Container bin-count 2\n";
			print OUT "pm enable pm-instance $x\_BCPM\n";
			print ROUT "pm disable pm-instance $x\_BCPM\n";
			print ROUT "pm delete pm-instance $x\_BCPM\n";
		}
		print "\nAugment file $outfile\nRollback file $outfileR\nDone !!\n";
	}
	$t->close();
}
