use Net::Telnet 3.00;
use Term::ReadKey;
use English;

$numin = scalar(@ARGV);
if ($numin == 0)
{
	print "Please hostname or IP address of a Ciena 5305 you need PM containers for: ";
	$hostname = <STDIN>;
	chomp $hostname;
}
else
{
	$hostname = @ARGV[0];
}

$prompt = '/\#|\>/';
if ($numin == 1)
{
	print "Please enter your username for login to $hostname: ";
	$login = <STDIN>;
	chomp $login;
}
else
{
	$login = @ARGV[1];
}	
print "Please enter the password for $login\@$hostname: ";
ReadMode('noecho');
$password = ReadLine(0);
chomp $password;
ReadMode 'normal';

$t = Net::Telnet->new(  Timeout => 10,
                        Prompt=> $prompt,
                        Errmode => "return" );
$fh = $t->input_log('c:/perlscript/logs/telnettest5.log');
$fh1 = $t->dump_log('c:/perlscript/logs/telnettestdump5.log');
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
		$lineprompt = $output . $match;
		
		$outfile = "$promptname-Augment.txt";

		open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
		
		$outfileR = "$promptname-Rollback.txt";

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
		}
		print "generating sub port PM configuration\n";
		foreach $x (@subport)
		{
			print OUT "pm create sub-port $x pm-instance $x\_BCPM profile-type Container bin-count 2\n";
			print OUT "pm enable pm-instance $x\_BCPM\n";
		}
		print "\nAugment file $outfile complete\n";
	}
	$t->close();
}
