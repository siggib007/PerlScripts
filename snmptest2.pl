use strict;
use net::SNMP;
my ($device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,@hkeys,$entPhysicalEntry,$id,$outfile);
my ($FlashFileEntry, $ConfigRegEntry, %FlashFiles, $tail, $type, $outstr, $inst, %FileStatus, %FileType);

$device = 'cpk-49x-1-79';
$comstr = '427cipower7';

$FileStatus{1} = "Deleted";
$FileStatus{2} = "InvalidCheckSum";
$FileStatus{3} = "Valid";

$FileType{1} = "Unknown";
$FileType{2} = "Config";
$FileType{3} = "Image";
$FileType{4} = "Directory";
$FileType{5} = "Crashinfo";

$outfile = "h:/perlscript/$device.log";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr);
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

$result = $session->get_table($FlashFileEntry);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "$FlashFileEntry\n";
foreach $key(@hkeys) 
	{ 
		if ($reshash{$key} ne '')
		{
			$tail = substr($key,length($FlashFileEntry)+1);
			($type) = split(/\./,$tail);
			$inst = substr($tail,length($type));
			$FlashFiles{$inst}{$type} = $reshash{$key};	
			$outstr = "FlashFileEntry\t$type\t$inst\t$reshash{$key}\n";	
			print $outstr;
			print OUT $outstr;
		}
	}
foreach $key(sort(keys %FlashFiles))
{
	$outstr	= $FlashFiles{$key}{'5'} . "\t" . $FlashFiles{$key}{'2'} . "\t" . $FileType{$FlashFiles{$key}{'6'}} . "\t" . $FlashFiles{$key}{'3'} . "\t" . $FileStatus{$FlashFiles{$key}{'4'}} . "\n";
	print $outstr;
	print OUT $outstr;
}
$session->close;
close(OUT);
exit 0;