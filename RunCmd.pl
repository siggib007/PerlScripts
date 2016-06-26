#!/perl/bin/perl
use Net::Telnet 3.00;

$datafile = "h:/perlscript/brixdevices-1.csv";
$cmdfile = "h:/perlscript/cleandiscovery.cmd";
$outfile = "h:/perlscript/Change_Out.txt";
$login = "admin";
$password ="admin";
$enpwd = "enable";


$t = Net::Telnet->new(  Timeout => 30,
                        Errmode => 'die' );
open (CMD,$cmdfile) || die "cannot open command file $cmdfile for reading: $!";
open(IN,$datafile) || die "cannot open devicelist $datafile for reading: $!";
open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
while(<IN>)
{
	chomp;
	@line = split(/,/);
	$hostname = $line[0]; #"sat-b1kb-1"; 
	$hostip = $line[1]; #"10.205.67.19";
	$prompt = '/'.$hostname.'>/';
	$enPrompt = '/'.$hostname.'#/';
	logentry ("Processing $hostname\n");
	$logfile = "h:/perlscript/logs/change_$hostname.log";
	$t->prompt($prompt);
	$t->open($hostip);
	$fh  = $t->input_log($logfile);
	$t->login($login,$password);
	$t->print("enable");
	($output, $match) = $t->waitfor('/password:/');
	#print OUT "$match\n$output\n";
	$t->print($enpwd);
	($output, $match) = $t->waitfor(Match =>$prompt, Match =>$enPrompt);
	#print OUT "$match\n$output\n";
	if ($match eq $hostname.">") 
	{ 
		logentry ("Failed first attempt at enable, retrying\n");
		$t->print("enable");
		($output, $match) = $t->waitfor('/password:/');
		#print OUT "$match\n$output\n";
		$t->print("");
		($output, $match) = $t->waitfor(Match =>$prompt, Match =>$enPrompt);
		#print OUT "$match\n$output\n";
	}
	if ($match eq $hostname."#")
	{	
		$t->print(" ");
		seek(CMD, 0,0);
		while(<CMD>)
		{
			chomp;
			@cmd = split(/\t/);
			if ($cmd[1] eq "\$enPrompt") 
			{
				$waitfor = $enPrompt;
			}
			elsif ($cmd[1] eq "\$prompt")
			{
				$waitfor = $prompt;
			}
			else
			{
				$waitfor = $cmd[1];
			}
			$t->print($cmd[0]);
			($output, $match) = $t->waitfor($waitfor);
			#print OUT "$match\n$output\n";
		}
		logentry ("Completed $hostname\n");
	}
	else
	{
		logentry ("Failed to enter into enable mode after two tries for $hostname");
	}
	$t->close();
}
close(IN);
close(CMD);

sub logentry
{
	print "$_[0]";
	print OUT "$_[0]";
}	