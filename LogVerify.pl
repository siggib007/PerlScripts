$PortTestArray{22} = "SSH";
$PortTestArray{23} = "Telnet";
$PortTestArray{80} = "HTTP";
$PortTestArray{443} = "HTTPS";

$getOIDs[0] = "sysName";
$getOIDs[1] = "sysDescr";
$getOIDs[2] = "sysObjectID";

$dir = $ARGV[0];
$dir =~ s/\\/\//g;
if ($dir eq "")
{
	print "What directory do you wish to process:";
	$dir = <STDIN>;
	chomp $dir;
	$dir =~ s/\\/\//g;
}
print "processing $dir ...\n";

opendir(DH, $dir) or die "Couldn't open $dir for reading: $!";

@files = ();
while( defined ($file = readdir(DH)) ) 
{
	if ($file =~ /\.log$/)
	{
		$logfile = $dir . "/" . $file;
		print "Processing $logfile ...\n";
		open(LOG,"<$logfile") || die "cannot open log file $logfile for write: $!";
		print "looping through $logfile\n";
		foreach $line (<LOG>)
		{
			chomp($line);
			if ($line =~ /processing address/)
			{
				@words = split (/ /, $line);
				$ipaddress = $words[4];
				undef $ping;
				undef $DNS;
				undef %test;
				undef %results;
				undef %SNMP;
#				print "$ipaddress \n";
			}
			else
			{
				if ($line =~ /Ping test/)
				{
					$ping = "OK";
				}
				if ($line =~ /Reverse DNS/)
				{
					$DNS = "OK";
				}
				
				foreach $key (sort keys %PortTestArray)  
				{
					$value = $PortTestArray{$key};
					$strtest = "testing $value";
					$strResults = "$value test";
					if (index($line,$strtest)> -1)
					{
						$test{$value} = "OK";
					}
					if (index($line,$strResults)> -1)
					{
						$results{$value} = "OK";
					}
				}
				foreach $value (@getOIDs)  
				{
					$snmp = "Issuing a SNMP get for $key";
					if (index($line,$snmp)> -1)
					{
						$snmp{$value} = "OK";
					}					
				}				
			}
		}
		
		close(LOG);
	}
}
