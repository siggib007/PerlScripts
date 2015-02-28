#!/perl/bin/perl
use Net::Telnet 3.00;
$datafile = "h:/perlscript/brixdevices.csv";
$login = "admin";
$password ="admin";
$enpwd = "enable";
$t = Net::Telnet->new(  Timeout => 30,
                        Errmode => 'die' );

open(IN,$datafile) || die "cannot open $datafile for reading: $!";
while(<IN>)
{
	@line = split(/,/,$_);
	$hostname = $line[0]; #"sat-b1kb-1"; 
	$hostip = $line[1]; #"10.205.67.19";
	$prompt = '/'.$hostname.'>/';
	$enPrompt = '/'.$hostname.'#/';
	print "Processing $hostname\n";
	$fh  = $t->input_log('h:/perlscript/logs/disc_$hostname.log');
	$t->prompt($prompt);
	$t->open($hostip);
	$t->login($login,$password);
	$t->print("enable");
	$t->waitfor('/password:/');
	$t->print($enpwd);
	($output, $match) = $t->waitfor(Match =>$prompt, Match =>$enPrompt);
	if ($match eq $hostname.">") 
	{ 
		print "Failed first attempt at enable, retrying\n";
		$t->print("enable");
		$t->waitfor('/password:/');
		$t->print("");
		($output, $match) = $t->waitfor(Match =>$prompt, Match =>$enPrompt);
	}
	if ($match eq $hostname."#")
	{	
		$t->print(" ");
		$t->print("conf t");
		$t->waitfor('/\(config\)#/');
		$t->print("server discovery local 10.230.9.151");
		$t->waitfor('/\(config\)#/');
		$t->print("server discovery network 10.230.9.151");
		$t->waitfor('/\(config\)#/');
		$t->print("server discovery universal 10.230.9.151");
		$t->waitfor('/\(config\)#/');
		$t->print("exit");
		$t->waitfor($enPrompt);
		$t->print("write");
		$t->waitfor('/saved./');
		$t->print("exit");
		print "Completed $hostname\n";
	}
	else
	{
		print "Failed to enter into enable mode after two tries for $hostname";
	}
	$t->close();
}
