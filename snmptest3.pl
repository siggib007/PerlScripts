use strict;
use net::SNMP;
my ($device,$comstr,$session,$error,$sysname,$result,$outfile, $numin);

#$device = 'cpk-49x-1-79';
#$comstr = '427cipower7';

#$outfile = "h:/perlscript/$device.log";

$numin = scalar(@ARGV);
if ($numin != 3)
	{
		print "Three arguments are required in this order:\n";
		print "usage: snmptest3.pl devname pwd logfile\n\n";
		print "devname: the dns name or IP address of device to query\n";
		print "pwd: The snmp community string for this device.\n";
		print "logfile: filename with complete path of where you want the results saved. Ex: c:/tools/snmpout.txt \n";
		exit();
	}

$device = $ARGV[0];
$comstr = $ARGV[1];
$outfile = $ARGV[2];

while ($outfile=~/\\/)
{
	$outfile=~s/\\/\//;
}

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr);
if (!defined($session)) {
      printf("ERROR: %s.\n", $error);
      exit 1;
   }
$sysname = '1.3.6.1.2.1.1.5.0';
$result = $session->get_request($sysname);
   if (!defined($result)) {
      printf("ERROR: %s.\n", $session->error);
      $session->close;
      exit 1;
   }
#print "devicename is $%result\n";
printf "device name is %s\n",$result->{$sysname};
print OUT $result->{$sysname}."\n";

$session->close;
close(OUT);
exit 0;