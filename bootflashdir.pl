use strict;
use net::SNMP;
my ($device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,@hkeys,$entPhysicalEntry,$id,$outfile);
my ($FlashFileEntry, $ConfigRegEntry, %FlashFiles, $tail, $type, $outstr, $inst, %FileStatus, %FileType, $curReg);
my ($Bootimg, $NextReg, $FlashInst, $FlashName, $ciscoFlashDeviceEntry, $len, %FlashDev, $value);

$device = 'db2-49x-cps-1-04';
$comstr = 'landbird948';

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
$FlashFileEntry = '1.3.6.1.4.1.9.9.10.1.1.4.2.1.1';
$ConfigRegEntry = '1.3.6.1.4.1.9.9.195.1.2.1';
$ciscoFlashDeviceEntry = '1.3.6.1.4.1.9.9.10.1.1.2.1';

$result = $session->get_request($sysname);
   if (!defined($result)) {
      printf("ERROR: %s.\n", $session->error);
      $session->close;
      exit 1;
   }
$outstr = "Device Name: " . $result->{$sysname} . "\n";
print $outstr;
print OUT $outstr;

$result = $session->get_table($ciscoFlashDeviceEntry);
%reshash = %$result;
foreach $key(sort(keys %reshash)) 
{ 
	if ($reshash{$key} ne '')
	{
		$len = length($ciscoFlashDeviceEntry);
		$tail = substr($key,$len+1);
		($type,$inst) = split(/\./,$tail);
		$FlashDev{$inst}{$type} = $reshash{$key};
		$value=$reshash{$key};
	}
}

$result = $session->get_table($ConfigRegEntry);
%reshash = %$result;
$curReg = "$ConfigRegEntry.1.1000";
$NextReg = "$ConfigRegEntry.2.1000";
$Bootimg = "$ConfigRegEntry.3.1000";

$outstr = "Current registry: " . $reshash{$curReg} . "\nNext registry: " . $reshash{$NextReg} . "\nBootImage: " . 
			$reshash{$Bootimg} . "\n\nContents of flash:\n";

print "$outstr";
print OUT $outstr;

$result = $session->get_table($FlashFileEntry);
%reshash = %$result;
foreach $key(sort(keys %reshash)) 
	{ 
		if ($reshash{$key} ne '')
		{
			$tail = substr($key,length($FlashFileEntry)+1);
			($type, $FlashInst) = split(/\./,$tail);
			$inst = substr($tail,length($type));
			#print "tail: $tail\ntype:$type\ninst:$inst\nfinst:$FlashInst\n";
			if ($type eq '5')
			{
				$FlashFiles{$inst}{$type} = $FlashDev{$FlashInst}{'7'} . ":" . $reshash{$key};
			}
			else
			{
				$FlashFiles{$inst}{$type} = $reshash{$key};	
			}
			$value=$reshash{$key};
			#print "value:$value\n";
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