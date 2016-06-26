use strict;
use Net::SNMP;
my ($device,$comstr,$session,$error,$sysname,$ifDesc,$result,%reshash,$key,@hkeys,$id,$outfile);
my ($ifSpeed, $ifPhysAddress, $ifAdminStatus, $ifOperStatus, %AdminStatusCode, %OperStatusCode);

$device = '10.41.160.18';
$comstr = 'ctipublic';

$outfile = "logs/$device.log";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

($session,$error) = Net::SNMP->session(hostname => $device, community => $comstr, timeout => 10);
if (!defined($session)) 
{
	printf("ERROR: %s.\n", $error);
  exit 1;
}
$sysname = '1.3.6.1.2.1.1.5.0';
$ifDesc = '1.3.6.1.2.1.2.2.1.2';
$ifSpeed = '1.3.6.1.2.1.2.2.1.5';
$ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
$ifAdminStatus = '1.3.6.1.2.1.2.2.1.7';
$ifOperStatus = '1.3.6.1.2.1.2.2.1.8';

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
#print "devicename is $%result\n";
printf "device name is %s\n",$result->{$sysname};
print OUT $result->{$sysname}."\n";

$result = $session->get_table($ifDesc);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "ifDesc\n";
foreach $key(@hkeys) 
{
	$id = substr($key,length($ifDesc)+1);
	print "$id\t$reshash{$key}\n"; 
	print OUT "$key\t$reshash{$key}\n";
}

$result = $session->get_table($ifPhysAddress);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "\nifPhysAddress\n";
foreach $key(@hkeys) 
{ 
	$id = substr($key,length($ifPhysAddress)+1);
	print "$id\t$reshash{$key}\n";
	print OUT "$id\t$reshash{$key}\n";
}

$result = $session->get_table($ifSpeed);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "\nifSpeed\n";
foreach $key(@hkeys) 
{ 
	$id = substr($key,length($ifSpeed)+1);
	print "$id\t$reshash{$key}\n";
	print OUT "$id\t$reshash{$key}\n";
}


$result = $session->get_table($ifAdminStatus);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "\nifAdminStatus\n";
foreach $key(@hkeys) 
{ 
	$id = substr($key,length($ifAdminStatus)+1);
	print "$id\t$reshash{$key}\n";
	print OUT "$id\t$reshash{$key}\n";
}

$result = $session->get_table($ifOperStatus);
%reshash = %$result;
@hkeys = sort(keys %reshash);
print "\nifOperStatus\n";
foreach $key(@hkeys) 
{ 
	$id = substr($key,length($ifOperStatus)+1);
	print "$id\t$reshash{$key}\n";
	print OUT "$id\t$reshash{$key}\n";
}

$session->close;
close(OUT);
exit 0;