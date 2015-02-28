$Outstr = "";
$InFile = '/home/siggib/nmapSEA.txt';
open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";
foreach $line (<IN>)
{
	print $line;
	chomp $line;
	if ($line=~/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)
	{
		if ($IPAddr ne "")
		{
			print "found new IP address $1\n";
			$Outstr .= "$IPAddr,";
			foreach $x (sort keys %PortTest)
			{
				$Outstr .= "$x:$PortTest{$x},";
			}
			$Outstr = substr $Outstr,0,-1;;
			$Outstr .= "\n";
			$IPAddr = $1;
		}
		else
		{
			print "Found the first IP of $1\n";
			$IPAddr = $1;
		}
	}
	if ($line=~/(\d{1,3})\/tcp\s*(\S*)/)
	{
		print "Found Port $1 $2\n";
		$PortTest{$1} = $2;
	}
}
print "\n\n\n\n$Outstr\n";