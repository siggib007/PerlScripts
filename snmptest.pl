use strict;
use Net::SNMP;
my ($device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$k,$v,$key,@hkeys,$entPhysicalEntry,$id,$outfile);
my ($FlashFileEntry, $ConfigRegEntry);

$device = '10.41.224.3';
$comstr = 'ctipublic';

$outfile = "$device.log";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr, timeout => 10);
if (!defined($session)) {
      printf("ERROR: %s.\n", $error);
      exit 1;
   }
$sysname = '1.3.6.1.2.1.1.5.0';
$ifDesc = '1.3.6.1.2.1.2.2.1.2';
$entPhysicalEntry = '1.3.6.1.2.1.47.1.1.1.1';
$FlashFileEntry = '1.3.6.1.4.1.9.9.10.1.1.4.2.1.1';
$ConfigRegEntry = '1.3.6.1.4.1.9.9.195.1.2.1';
$result = $session->get_request($sysname);
   if (!defined($result)) {
      printf("ERROR: %s.\n", $session->error);
      $session->close;
      exit 1;
   }
#print "devicename is $%result\n";
printf "device name is %s\n",$result->{$sysname};
print OUT $result->{$sysname}."\n";

$result = $session->get_table($ConfigRegEntry);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "$ConfigRegEntry\n";
foreach $key(@hkeys) { print "$key => $reshash{$key}\n"; print OUT "$key\t$reshash{$key}\n";}
#while (($k,$v) = each %reshash) { print "$k => $v\n";}

$result = $session->get_table($FlashFileEntry);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "$FlashFileEntry\n";
foreach $key(@hkeys) 
	{ 
		if ($reshash{$key} ne '')
		{
			$id = 'FlashFileEntry' . substr($key,length($FlashFileEntry));
			print "$id\t$reshash{$key}\n";
			print OUT "$id\t$reshash{$key}\n";
		}
	}

$session->close;
close(OUT);
exit 0;