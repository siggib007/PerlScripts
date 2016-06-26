use strict;
use net::SNMP;
my (@device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$k,$v,$key,@hkeys,$entPhysicalEntry,$id,$outfile);
my (@Inv, %invitem, $inst, $type, $loc, $len, %PhysClass, %FRU,$dev);
$device[0] = 'tuk-12f-btd-1a';
$device[1] = 'tuk-76c-1a';
$device[2] = 'iuskcmgmtc6n01';
$device[3] = 'iuskipssbc6501';
$device[4] = 'tuk-65ag-1a';

$comstr = '427cipower7';

$sysname = '1.3.6.1.2.1.1.5.0';
$ifDesc = '1.3.6.1.2.1.2.2.1.2';
$entPhysicalEntry = '1.3.6.1.2.1.47.1.1.1.1';

$PhysClass{1} = 'other';
$PhysClass{2} = 'unknown';
$PhysClass{3} = 'chassis';
$PhysClass{4} = 'backplane';
$PhysClass{5} = 'container';
$PhysClass{6} = 'powerSupply';
$PhysClass{7} = 'fan';
$PhysClass{8} = 'sensor';
$PhysClass{9} = 'module';
$PhysClass{10} = 'port';
$PhysClass{11} = 'stack';
$PhysClass{12} = 'cpu';

$FRU{1} = 'true';
$FRU{2} = 'false';

foreach $dev (@device)
{
	$outfile = "h:/perlscript/$dev.txt";
	open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";
	
	($session,$error) = Net::SNMP->session(hostname => $dev, community => $comstr);
	if (!defined($session)) 
	{
		printf("ERROR: %s.\n", $error);
		exit 1;
	}
		
	$result = $session->get_request($sysname);
		if (!defined($result)) 
		{
			printf("ERROR: %s.\n", $session->error);
			$session->close;
			exit 1;
		}
	#print "devicename is $%result\n";
	printf "device name is %s\n",$result->{$sysname};
	#print OUT $result->{$sysname}."\n";
	
	$result = $session->get_table($ifDesc);
	%reshash = %$result;
	@hkeys = sort(keys %reshash);
	#print "$ifDesc\n";
	#foreach $key(@hkeys) { print "$key => $reshash{$key}\n"; print OUT "$key\t$reshash{$key}\n";}
	#while (($k,$v) = each %reshash) { print "$k => $v\n";}
	
	$result = $session->get_table($entPhysicalEntry);
	%reshash = %$result;
	@hkeys = sort(keys %reshash);
	print "$entPhysicalEntry\n";
	foreach $key(@hkeys) 
	{ 
		if ($reshash{$key} ne '')
		{
			$len = length($entPhysicalEntry);
			$id = 'entPhysicalEntry' . substr($key,$len);
			$loc = rindex ($key, '.');
			$inst = substr($key,$loc+1);
			$type = substr($key,$len+1,$loc-$len-1);
			print "$id\t$reshash{$key}\n";
			#print OUT "$type\t$inst\t$reshash{$key}\n";
			$invitem{$inst}{$type} = $reshash{$key}
		}
	}
	print OUT "Instance\tDescription\tContained in Name\tContained in Descr\tType\tsub pos\tName\tHardware Rev\tFirmware Rev\tSoftware Rev\tSN\tMake\tModel\tFRU\tMFGDate\tUris\n";
	foreach $key(sort(keys %invitem))
	{
		print OUT "$key\t$invitem{$key}{'2'}\t$invitem{$invitem{$key}{'4'}}{'7'}\t$invitem{$invitem{$key}{'4'}}{'2'}\t$PhysClass{$invitem{$key}{'5'}}\t$invitem{$key}{'6'}\t";
		print OUT "$invitem{$key}{'7'}\t$invitem{$key}{'8'}\t$invitem{$key}{'9'}\t$invitem{$key}{'10'}\t$invitem{$key}{'11'}\t";
		print OUT "$invitem{$key}{'12'}\t$invitem{$key}{'13'}\t$FRU{$invitem{$key}{'16'}}\t$invitem{$key}{'17'}\t$invitem{$key}{'18'}";
	    print OUT "\n";
	}
		
	#foreach $key(sort(keys %invitem))
	#	{
	#		print OUT "$key\t";
	#	    for $type ( sort keys %{ $invitem{$key} } ) 
	#		    {
	#				print OUT "$type=$invitem{$key}{$type}\t";
	#		    }
	#	    print OUT "\n";
	#	}
	
	$session->close;
	close(OUT);
}
exit 0;