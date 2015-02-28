$DNSDumpFile = "/var/tmp/DNSDump.txt";
$DNSURL = "http://10.41.161.140/dns/hosts.php";

$result = `wget -O $DNSDumpFile $DNSURL 2>&1`;
#print "DNS Dump Complete. Here is output of the command:\n$result\n";
$Response = "10.252.196.5";
print "\nSearching the DNS Dump file for: $Response\n";
$cmd = "grep -i $Response $DNSDumpFile";
print "using command: $cmd\n";
$result = `$cmd`;
print "results are:*$result*\n";
chomp $result;
@parts = split /\t/, $result;
print "\nIP Address=*$parts[0]* and Hostname=*$parts[1]*\n";
