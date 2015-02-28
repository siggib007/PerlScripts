#!/perl/bin/perl
#use strict;
use Net::Telnet 3.00;
$datafile = "c:/testinv/devices.csv";
$outdir  = "c:/testinv/sessionlogs";
$outfile = "c:/testinv/Showrun.log"; #logfile
$login = "admin";
$password ="help911";
$tftpserver = "10.100.253.30";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;

logentry( "Started processing");

$t = Net::Telnet->new(  Timeout => 10,
                        Errmode => 'die' );

open(IN,$datafile) || die "cannot open $datafile for reading: $!";
open(OUT,'>>'.$outfile) || die "cannot open outfile $outfile for write: $!";

while(<IN>)
{
	@line = split(/,/,$_);
	$hostname = lc($line[0]); #"sat-b1kb-1"; 
	$uchostname = uc($hostname);
	#print "hostname: $hostname\tuchost: $uchostname\n";
	$hostip = $line[1]; #"10.205.67.19";
	$logfile = "$outdir/$hostname.log";
	#print "Logfile:$logfile\n";
	logentry ("Processing $hostname");
	$fh  = $t->input_log($logfile);
	logentry ("opening connection to $hostname");
	$t->open(Host => $hostip);
	$errormsg = $t->errmsg();
	$ret = scalar $t;
	#print "Open returned:$ret:\nError: $errormsg\n";
	if (!defined($t))
	{
		logentry("Failed to connect to $hostname: $t->errmsg");
	}
	else
	{
		logentry ("Connection established, login in...");
		($output, $match) = $t->waitfor('/ame:/');
		$t->print($login);
		($output, $match) = $t->waitfor(Match =>'/word:/', Match =>'/#/');
		#print "Match: $match\n";
		if ($match eq "word:")
		{
			$t->print($password);
			($output, $match) = $t->waitfor('/#/');		
		}
		logentry ("Logged in, doing a show run");
		$t->print("show run");
		($output, $match) = $t->waitfor(Match =>"/More/", Match =>'/#/');
		while ($match eq "More")
		{
			$t->print(" ");
			($output, $match) = $t->waitfor(Match =>"/More/", Match =>'/#/');
		}
		#print "Match: $match\nOutput: $output\n";
		logentry ("show run done, attempting to upload via tftp");
		$t->print("");
		($output, $match) = $t->waitfor(Match =>"/console#/", Match =>"/Vty/", Match =>"/$hostname/", Match =>"/$uchostname/");
		#print "Match: $match\nOutput: $output\n";
		$errormsg = $t->errmsg();
		$ret = scalar $t;
		#print "Open returned:$ret:\nError: $errormsg\n";
		if (!defined($t))
		{
			logentry("Error during prompt detection on $hostname: $t->errmsg");
		}
		else
		{
			#print "Match: $match\n";
			if ($match eq "Vty")
			{
				print "VTY: copy run tftp\n";
				$t->print("copy run tftp");
				($output, $match) = $t->waitfor('/ip address:/');	
				#print "$tftpserver\n";
				$t->print($tftpserver);
				($output, $match) = $t->waitfor('/file name:/');	
				#print "$hostname-$mon-$mday-$year-$hour-$min.conf\n";
				$t->print("$hostname-$mon-$mday-$year-$hour-$min.conf");
				($output, $match) = $t->waitfor('/Vty/');	
			}
			if ($match eq "console#" or $match eq "$hostname" or $match eq "$uchostname")
			{
				print "console copy run tftp://$tftpserver/$hostname-$mon-$mday-$year-$hour-$min.conf\n";
				$t->print("copy run tftp://$tftpserver/$hostname-$mon-$mday-$year-$hour-$min.conf");
				($output, $match) = $t->waitfor(Match =>"/console#/", Match =>"/$hostname/", Match =>"/$uchostname/");	
			}
		}
		$t->print("exit");
		logentry ("Completed $hostname");

		$t->close();
		#undef $t;
	}
}
logentry ("Stopped processing");
close(IN);
close(CMD);

sub logentry
{
	my($strmsg) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);	
	$mon = $mon + 1;
	
	print "$mon/$mday/$year $hour:$min  $strmsg\n";
	print OUT "$mon/$mday/$year $hour:$min  $strmsg\n";
}	