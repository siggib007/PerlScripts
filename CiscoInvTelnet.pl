use strict;
use Net::Telnet 3.00;
use Term::ReadKey;
use English;

my (@lines, $x, $hostname, $login, $dir, $goodpar, $password, $prompt, $t, $errormsg, $output, $match, $cmd);
my ($outfile, $outfileR, $numlines, @lineparts, $i, @pbtService, @subport, @ret, $promptname, $lineprompt);
my ($str, @CiscoInv);

$hostname = "";
$login = "";
$dir = "";

print "\nThis script will login to a specified Cisco Device and gather inventory information.\n";
print "Use 'perl $PROGRAM_NAME help' for syntax of optional arguments\n\n\n";
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
		print "host=hostname: DNS name or IP address of the device you want to inventory.\n";
		print "user=username: login user name.\n";
		print "dir=dirname: relative or absolute path where you want the resulting files stored.\n\n";
		print "Ex: perl $PROGRAM_NAME host=10.42.160.12 user=jsmith dir=/home/jsmith/inventory\n\n";
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
	print "Please specify hostname or IP address of the Cisco Device you want inventory for: ";
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
		$output = substr $output, 1;
		$promptname = $output;
		if ($promptname =~ /\*$/)
		{
			$promptname = substr $promptname,0, -1;
		}
		$lineprompt = $output . $match;
		
		$outfile = "$dir$promptname-Inventory.txt";

		open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
		
		print "hostname according to prompt is: $promptname\n";
		print "Prompt is: $lineprompt\n";
		print "gathering inventory information\n";
		$cmd = "sh inv raw";
		$t->print($cmd);
		($output, $match) = $t->waitfor($prompt);
		$output =~ s/$promptname//g;
		$output =~ s/$cmd//g;
		$output =~ s/\nPID/,PID/g;
		$output =~ s/\n\n/\n/g;
		$output =~ s/, /,/g;
		$output =~ s/\s+,/,/g;
		$output =~ s/,\s+/,/g;
		$output =~ s/: /:/g;
		$output =~ s/NAME://g;
		$output =~ s/DESCR://g;
		$output =~ s/PID://g;
		$output =~ s/SN://g;
		$output =~ s/VID://g;
		$output =~ s/\".*,//g;
		
		$output = substr $output, 1, -2;
		print $output;
		print OUT "Name,Description,PartNum,Version,Serial Number\n";
		print OUT $output;
		exit;
		@lines = split /\n/, $output;
		@lineparts = split /,/, $lines[0];
print $lineparts[5];
exit;
		$numlines = scalar(@lines);
		$x=0;
		for ($i = 0; $i < $numlines; $i++) 
		{
			@lineparts = split /,/, $lines[$i];
			print "$lineparts[0]\t$lineparts[1]\t$lineparts[2]\t$lineparts[3]\t$lineparts[4]\n";
			print OUT "$lineparts[0]\t$lineparts[1]\t$lineparts[2]\t$lineparts[3]\t$lineparts[4]\n";
			foreach $str (@lineparts)
			{
				$str =~ s/\s+$//;
				$str =~ s/^\s+//;
			}		
			$CiscoInv[$x]=[@lineparts];
			$x++;
		}

		print "\nInventory File\n";
		print OUT "Name\tDescription\tPartNum\tVersion\tSerial Number\n";

		print "Here is the first line:\n";
		print "$CiscoInv[0][0]\t$CiscoInv[0][1]\t$CiscoInv[0][2]\t$CiscoInv[0][3]\t$CiscoInv[0][4]\n";

#		print "$CiscoInv[0][0]";#\t$CiscoInv0[$i][1]\t$CiscoInv[0][2]\t$CiscoInv[0][3]\t$CiscoInv[0][4]\n";
		
		$numlines = scalar(@CiscoInv);
		print "Printing out $numlines lines ... \n";
		for ($i = 0; $i < $numlines; $i++) 
		{
			print "$CiscoInv[$i][0]\t$CiscoInv[$i][1]\t$CiscoInv[$i][2]\t$CiscoInv[$i][3]\t$CiscoInv[$i][4]\n";
			print OUT "$CiscoInv[$i][0]\t$CiscoInv[$i][1]\t$CiscoInv[$i][2]\t$CiscoInv[$i][3]\t$CiscoInv[$i][4]\n";
		}
		print "\nInventory complete and save to $outfile\n Done !!\n";
	}
	$t->close();
}
