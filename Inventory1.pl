use strict;
use net::SNMP;
my (@device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$k,$v,$key,@hkeys,$entPhysicalEntry,$id,$outfile);
my (@Inv, %invitem, $inst, $type, $loc, $len, %PhysClass, %FRU,$dev, $errmsg, $IntOutfile, $xcvrFile);
my ($Int, @tmp, $PartNo, $Vendor, $SN, $Rev, $DevName, $x, $y);

$device[0] = '10.40.184.233';
$device[1] = '10.40.184.234';
$device[2] = '10.40.184.3';
$device[3] = '10.40.184.4';
$device[4] = '10.41.136.235';
$device[5] = '10.41.136.236';

$comstr = 'ctipublic';

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

foreach $dev (sort @device)
{
	print "Establishing connection to $dev\n";
	($session,$error) = Net::SNMP->session(hostname => $dev, community => $comstr);
	if (!defined($session)) 
	{
		printf("ERROR: %s.\n", $error);
		next;
#		exit 1;
	}
		
	$result = $session->get_request($sysname);
	if (!defined($result)) 
	{
		printf("ERROR: %s.\n", $session->error);
		$session->close;
		next;
#		exit 1;
	}
	
	$DevName = $result->{$sysname};
	printf "device name is %s\n",$DevName;

	$outfile    = "c:/invresults/$DevName-inv.txt";
	$IntOutfile = "c:/invresults/$DevName-int.txt";
	$xcvrFile   = "c:/invresults/$DevName-xcvr.txt";
	
	print "Fetching ifDesc\n";
	$result = $session->get_table($ifDesc);
	print "fetch complete\n";
	if (!defined($result)) 
	{
		$error = $session->error;
		$errmsg = "SNMP ERROR: $error.";
	}
	else
	{
		open(INT,">",$IntOutfile) || die "cannot open IntOutfile $IntOutfile for write: $!";
		%reshash = %$result;
		foreach $key(sort(keys %$result)) 
		{ 
#			print "$key => $reshash{$key}\n"; 
			print INT "$key\t$reshash{$key}\n";
		}
	}
	
	print "fetching entPhysEntry\n";
	$result = $session->get_table($entPhysicalEntry);
	print "fetch complete, parsing results ... \n";
	if (!defined($result)) 
	{
		$error = $session->error;
		$errmsg = "SNMP ERROR: $error.";
	}
	else
	{
		%reshash = %$result;
		foreach $key(sort(keys %reshash)) 
		{ 
#			print "Key: $key\n";
			if ($reshash{$key} ne '')
			{
				$len = length($entPhysicalEntry);
				$id = 'entPhysicalEntry' . substr($key,$len);
				$loc = rindex ($key, '.');
				$inst = substr($key,$loc+1);
				$type = substr($key,$len+1,$loc-$len-1);
#				print "$id\t$reshash{$key}\n";
#				print OUT "$type\t$inst\t$reshash{$key}\n";
				$invitem{$inst}{$type} = $reshash{$key}
			}
		}
	}
	print "parsing complete, saving results\n";
	open(XCVR,">",$xcvrFile)  || die "cannot open xcvrFile $xcvrFile for write: $!";
	open(OUT,">",$outfile)    || die "cannot open outfile $outfile for write: $!";

	print OUT  "Description\tName\tHardware Rev\tFirmware Rev\tSoftware Rev\tSN\tMake\tModel\n";
	print XCVR "Interface\tVendor\tPart Number\tSerial Number\tRevision Number\n";
	$x = scalar %invitem;
	$y = scalar keys %invitem;
	print "invitem count: x=$x y=$y\n";
	
	foreach $key(sort(keys %invitem))
	{
		if ($invitem{$key}{'16'} == 1)
		{
			if ($invitem{$key}{'5'} == 3)
			{
				
				print "Chassis: $invitem{$key}{'12'} $invitem{$key}{'13'} SN:$invitem{$key}{'11'}\n";
			}
			if ($invitem{$key}{'5'} == 9)
			{
				print "Module Name: $invitem{$key}{'7'}\n";
				if ($invitem{$key}{'7'} =~ /Transceiver/)
				{
					$Int = $invitem{$key}{'7'};
					$Int =~ s/Transceiver //;
					
					if ($invitem{$key}{'13'} eq "")
					{
						@tmp = split(/ /,$invitem{$key}{'2'});
						$PartNo = $tmp[1];
					}
					else
					{
						$PartNo = $invitem{$key}{'13'};
					}
					
					if ($invitem{$key}{'12'} eq "")
					{
						@tmp = split(/ /,$invitem{$key}{'2'});
						$Vendor = $tmp[1];
					}
					else
					{
						$Vendor = $invitem{$key}{'12'};
					}						
					
					if ($invitem{$key}{'11'} eq "")
					{
						@tmp = split(/ /,$invitem{$key}{'2'});
						$SN = $tmp[1];
					}
					else
					{
						$SN = $invitem{$key}{'11'};
					}
					
					$Rev = $invitem{$key}{'8'};
					
					print XCVR "$Int\t$Vendor\t$PartNo\t$SN\t$Rev\n";
					print "XCVR: $Int\t$Vendor\t$PartNo\t$SN\t$Rev\n\n";
				}
				else
				{
					if ($invitem{$key}{'2'} !~ /(VTT|Clock)/)
					{
					print OUT "$invitem{$key}{'2'}\t$invitem{$key}{'7'}\t$invitem{$key}{'8'}\t$invitem{$key}{'9'}\t$invitem{$key}{'10'}\t";
					print OUT "$invitem{$key}{'11'}\t$invitem{$key}{'12'}\t$invitem{$key}{'13'}\n";
					print "Module: $invitem{$key}{'2'}\t$invitem{$key}{'7'}\t$invitem{$key}{'8'}\t$invitem{$key}{'9'}\t$invitem{$key}{'10'}\t";
					print "$invitem{$key}{'11'}\t$invitem{$key}{'12'}\t$invitem{$key}{'13'}\n";
				}
				}
	  	}
	  }
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
	close(INT);
	close(XCVR);
}
exit 0;