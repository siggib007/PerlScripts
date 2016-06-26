use strict;
use Net::SNMP;
my ($device,$comstr,$session,$error,$sysname,$result,%reshash,@hkeys,$id,$outfile);
my (%tableOIDs, $value, $errmsg, %outhash, $Tablekey, $reskey, $devname, $OutKey);
my (%AdminStatusCode, %OperStatusCode);

undef %outhash;
$device = '10.41.160.10';
$comstr = 'ctipublic';

$outfile = "logs/$device.log";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr, timeout => 10);
if (!defined($session)) 
{
	printf("ERROR: %s.\n", $error);
  exit 1;
}

$tableOIDs{"ifDesc"}        = "1.3.6.1.2.1.2.2.1.2";
$tableOIDs{"ifSpeed"}       = "1.3.6.1.2.1.2.2.1.5";
$tableOIDs{"ifPhysAddress"} = "1.3.6.1.2.1.2.2.1.6";
$tableOIDs{"ifAdminStatus"} = "1.3.6.1.2.1.2.2.1.7";
$tableOIDs{"ifOperStatus"}  = "1.3.6.1.2.1.2.2.1.8";

$sysname = '1.3.6.1.2.1.1.5.0';

$AdminStatusCode{1} = 'up';
$AdminStatusCode{2} = 'down';
$AdminStatusCode{3} = 'testing';

$OperStatusCode{1} = 'up';
$OperStatusCode{2} = 'down';
$OperStatusCode{3} = 'testing';
$OperStatusCode{4} = 'unknown';
$OperStatusCode{5} = 'dormant';
$OperStatusCode{6} = 'notPresent';
$OperStatusCode{7} = 'lowerLayerDown';

$result = $session->get_request($sysname);
if (!defined($result)) 
{
   printf("ERROR: %s.\n", $session->error);
   $session->close;
   exit 1;
}
$devname = $result->{$sysname};
printf "device name is %s\n",$devname;
print OUT $devname."\n";

foreach $Tablekey (sort keys %tableOIDs)  
{
	$value = $tableOIDs{$Tablekey};
	print "Tablekey: $Tablekey\nValue: $value\n";
#	logentry("Issuing a SNMP walk for $Tablekey ... \n",2,1);
	$result = $session->get_table($value);
	if (!defined($result)) 
	{
		$error = $session->error;
		$errmsg = "SNMP ERROR: $error.";
#		logentry ("$errmsg\n",2,1);
		print "$errmsg\n";
#		$getOIDResults{$key} = $errmsg;
#		$SNMPTest = "Fail";
		last;
	}
	else
	{
		%reshash = %$result;
#		@hkeys = sort(keys %reshash);
		print "\n$Tablekey\n";
		foreach $reskey(sort(keys %reshash)) 
		{
			$id = substr($reskey,length($value)+1);
			print "$id\t$reshash{$reskey}\n"; 
			print OUT "$reskey\t$reshash{$reskey}\n";
			$outhash{$id}{$Tablekey} = $reshash{$reskey};
		}
	}
}

#print OUT $devname."\n";
print "\n$devname\n";
foreach $OutKey (sort keys %outhash)
{
#	print "Outkey: $OutKey\n";
	print "$OutKey\t$outhash{$OutKey}{ifDesc}\t$outhash{$OutKey}{ifSpeed}\t$outhash{$OutKey}{ifPhysAddress}\t";
	print "$AdminStatusCode{$outhash{$OutKey}{ifAdminStatus}}\t$OperStatusCode{$outhash{$OutKey}{ifOperStatus}}\n";
	print OUT "$OutKey\t$outhash{$OutKey}{ifDesc}\t$outhash{$OutKey}{ifSpeed}\t$outhash{$OutKey}{ifPhysAddress}\t";
	print OUT "$AdminStatusCode{$outhash{$OutKey}{ifAdminStatus}}\t$OperStatusCode{$outhash{$OutKey}{ifOperStatus}}\n";
}

$session->close;
close(OUT);
exit 0;