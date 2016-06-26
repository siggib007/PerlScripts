#!/perl/bin/perl
use Net::Telnet 3.00;
$datafile = "h:/Brix Docs/brixdevices.csv";
$outdir  = "h:/Brix Docs/configs";
$outfile = "$outdir/Showrun.log"; #logfile
$login = "admin";
$password ="admin";
$enpwd = "enable";
$t = Net::Telnet->new(  Timeout => 30,
                        Errmode => 'die' );

open(IN,$datafile) || die "cannot open $datafile for reading: $!";
open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

while(<IN>)
{
	@line = split(/,/,$_);
	$hostname = $line[0]; #"sat-b1kb-1"; 
	$hostip = $line[1]; #"10.205.67.19";
	$prompt = '/'.$hostname.'>/';
	$enPrompt = '/'.$hostname.'#/';
	$logfile = "$outdir/$hostname.conf";
	#print $logfile."\n";
	logentry ("Processing $hostname\n");
	$fh  = $t->input_log($logfile);
	$t->prompt($prompt);
	$t->open(Host => $hostip, Errmode => "die");
	$errormsg = $t->errmsg();
	$ret = scalar $t;
	#print "Open returned:$ret:\nError: $errormsg\n";
	if (!defined($t))
	{
		logentry("Failed to connect to $hostname: $t->errmsg\n");
	}
	else
	{
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
			$t->print("show run");
			($output, $match) = $t->waitfor(Match =>$enPrompt, Match =>"/More/");
			while ($match eq "More")
			{
				$t->print("");
				($output, $match) = $t->waitfor(Match =>$enPrompt, Match =>"/More/");
			}
			$t->print("show bench");
			($output, $match) = $t->waitfor(Match =>$enPrompt, Match =>"/More/");
			while ($match eq "More")
			{
				$t->print("");
				($output, $match) = $t->waitfor(Match =>$enPrompt, Match =>"/More/");
			}
			$t->print("sh int");
			$t->waitfor($enPrompt);
		
			print "Completed $hostname\n";
		}
		else
		{
			logentry ("Failed to enter into enable mode after two tries for $hostname");
		}		
		$t->close();
		#undef $t;
	}
}

close(IN);
close(CMD);

sub logentry
{
	print "$_[0]";
	print OUT "$_[0]";
}	