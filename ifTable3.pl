use strict;
use Net::SNMP;
my ($device,$comstr,$session,$error,$sysname,$result,%reshash,@hkeys,$id,$logfile);
my (%tableOIDs, $value, $errmsg, %outhash, $Tablekey, $reskey, $devname, $OutKey);
my (%AdminStatusCode, %OperStatusCode, $verbose, $LogLevel, $Outfile);

undef %outhash;
$device = '10.41.160.10';
$comstr = 'ctipublic';
$verbose = 5;
$LogLevel = 5;

$Outfile = "in out/$device.txt";
$logfile = "logs/$device.log";

open(LOG,">",$logfile) || die "cannot open logfile $logfile for write: $!";
open(OUT,">",$Outfile) || die "cannot open outfile $Outfile for write: $!";

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
	$error = $session->error;
	$errmsg = "SNMP ERROR: $error.";
	logentry ("$errmsg\n",2,1);
  $session->close;
  exit 1;
}
$devname = $result->{$sysname};
logentry ("device name is $devname\n",2,1);

foreach $Tablekey (sort keys %tableOIDs)  
{
	$value = $tableOIDs{$Tablekey};
	logentry("Issuing a SNMP walk for $Tablekey ... \n",2,1);
	$result = $session->get_table($value);
	if (!defined($result)) 
	{
		$error = $session->error;
		$errmsg = "SNMP ERROR: $error.";
		logentry ("$errmsg\n",2,1);
		last;
	}
	else
	{
		%reshash = %$result;
		foreach $reskey(sort(keys %reshash)) 
		{
			$id = substr($reskey,length($value)+1);
			$outhash{$id}{$Tablekey} = $reshash{$reskey};
		}
	}
}

logentry("Writing results to $Outfile ... \n",2,1);

foreach $OutKey (sort keys %outhash)
{
	print OUT "$OutKey\t$outhash{$OutKey}{ifDesc}\t$outhash{$OutKey}{ifSpeed}\t$outhash{$OutKey}{ifPhysAddress}\t";
	print OUT "$AdminStatusCode{$outhash{$OutKey}{ifAdminStatus}}\t$OperStatusCode{$outhash{$OutKey}{ifOperStatus}}\n";
}

logentry("Done !!! \n",2,1);

$session->close;
close(LOG);
close(OUT);
exit 0;

sub logentry
{
	my($outmsg, $ConLevel, $FileLevel) = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);
	$mon = $mon + 1;
	$sec = substr("0$sec",-2);
	
	if ($ConLevel <= $verbose)
	{
		print "$mon/$mday/$year $hour:$min:$sec $outmsg";
	}
	if ($FileLevel <= $LogLevel)
	{
		print LOG "$mon/$mday/$year $hour:$min:$sec $outmsg";
	}
}
