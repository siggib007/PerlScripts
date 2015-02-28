use strict;
use net::SNMP;
use English;
use Sys::Hostname;
my ($device,$comstr,$session,$error,$sysname,$result,$outfile, $numin, $logfile, $errmsg, $key, $len, $id, $progname);
my ($OutletID, $OutletName, $OutletStatus, $Outletloadstatus, $OutletLoadValue, %OutletStatusCodes, %loadstatusCodes);
my (%strOutletIDs, %strOutletNames, %strOutletStatus, %strOutletloadstatus, %OutletLoadValueNums, %reshash, $strOut);
my ($devname);

$numin = scalar(@ARGV);
if ($numin != 3)
	{
		print "\nInvalid usage: Three arguments are required and you supplied $numin\n\n";
		print "Correct usage: perl $PROGRAM_NAME DeviceName pwd logfile\n\n";
		print "DeviceName: the dns name or IP address of device to query\n";
		print "pwd: The snmp community string for this device.\n";
		print "logfile: filename with complete path of where you want the results saved.\n\n";
		print "Ex: perl $PROGRAM_NAME 192.168.1.15 public c:/tools/snmpout.txt \n";
		exit();
	}
	
print "starting $PROGRAM_NAME\n";
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname.log";
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");

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
$OutletID = '.1.3.6.1.4.1.1718.3.2.3.1.2';
$OutletName = '.1.3.6.1.4.1.1718.3.2.3.1.3';
$OutletStatus = '.1.3.6.1.4.1.1718.3.2.3.1.5';
$Outletloadstatus = '.1.3.6.1.4.1.1718.3.2.3.1.6';
$OutletLoadValue = '.1.3.6.1.4.1.1718.3.2.3.1.7';

$OutletStatusCodes{0} = 'off';
$OutletStatusCodes{1} = 'on';
$OutletStatusCodes{2} = 'offWait';
$OutletStatusCodes{3} = 'onWait';
$OutletStatusCodes{4} = 'offError';
$OutletStatusCodes{5} = 'onError';
$OutletStatusCodes{6} = 'noComm';
$OutletStatusCodes{7} = 'reading';
$OutletStatusCodes{8} = 'offFuse';
$OutletStatusCodes{9} = 'onFuse'; 

$loadstatusCodes{0} = 'normal';
$loadstatusCodes{1} = 'notOn';
$loadstatusCodes{2} = 'reading';
$loadstatusCodes{3} = 'loadLow';
$loadstatusCodes{4} = 'loadHigh';
$loadstatusCodes{5} = 'overLoad';
$loadstatusCodes{6} = 'readError';
$loadstatusCodes{7} = 'noComm';

$result = $session->get_request($sysname);
   if (!defined($result)) {
      printf("ERROR: %s.\n", $session->error);
      $session->close;
      exit 1;
   }

printf "Current load for ServerTech named %s\n",$result->{$sysname};
printf OUT "Current load for ServerTech named %s\n",$result->{$sysname};

logentry("Fetching OutletID\n");
$result = $session->get_table($OutletID);
if (!defined($result)) 
{
	$errmsg = $session->error;
	logentry ("OutletID ERROR: $errmsg.\n");
}
else
{
	%reshash = %$result;			
	foreach $key(sort(keys %reshash)) 
	{ 
		$len = length($OutletID);
		$id = substr($key,$len+1);
		$strOutletIDs{$id} = $reshash{$key};
		#logentry ("$id\t$strOutletIDs{$id}\n");
	}
}

logentry("Fetching OutletName\n");
$result = $session->get_table($OutletName);
if (!defined($result)) 
{
	$errmsg = $session->error;
	logentry ("OutletName ERROR: $errmsg.\n");
}
else
{
	%reshash = %$result;			
	foreach $key(sort(keys %reshash)) 
	{ 
		$len = length($OutletID);
		$id = substr($key,$len+1);
		$strOutletNames{$id} = $reshash{$key};
		#logentry ("$id\t$strOutletNames{$id}\n");
	}
}

logentry("Fetching OutletStatus\n");
$result = $session->get_table($OutletStatus);
if (!defined($result)) 
{
	$errmsg = $session->error;
	logentry ("OutletStatus ERROR: $errmsg.\n");
}
else
{
	%reshash = %$result;			
	foreach $key(sort(keys %reshash)) 
	{ 
		$len = length($OutletStatus);
		$id = substr($key,$len+1);
		$strOutletStatus{$id} = $OutletStatusCodes{$reshash{$key}};
		#logentry ("$id\t$strOutletStatus{$id}\n");
	}
}

logentry("Fetching Outletloadstatus\n");
$result = $session->get_table($Outletloadstatus);
if (!defined($result)) 
{
	$errmsg = $session->error;
	logentry ("Outletloadstatus ERROR: $errmsg.\n");
}
else
{
	%reshash = %$result;			
	foreach $key(sort(keys %reshash)) 
	{ 
		$len = length($OutletStatus);
		$id = substr($key,$len+1);
		$strOutletloadstatus{$id} = $loadstatusCodes{$reshash{$key}};
		#logentry ("$id\t$strOutletloadstatus{$id}\n");
	}
}

logentry("Fetching OutletLoadValue\n");
$result = $session->get_table($OutletLoadValue);
if (!defined($result)) 
{
	$errmsg = $session->error;
	logentry ("OutletLoadValue ERROR: $errmsg.\n");
}
else
{
	%reshash = %$result;			
	foreach $key(sort(keys %reshash)) 
	{ 
		$len = length($OutletID);
		$id = substr($key,$len+1);
		$OutletLoadValueNums{$id} = $reshash{$key}/100;
		#logentry ("$id\t$OutletLoadValueNums{$id}\n");
	}
}

$strOut = "ID,Name,Status,LoadStatus,LoadValue\n";
logentry ($strOut);
print OUT $strOut;

foreach $key(sort(keys %strOutletIDs))
{
	$strOut = "$strOutletIDs{$key},$strOutletNames{$key},$strOutletStatus{$key},$strOutletloadstatus{$key},$OutletLoadValueNums{$key}\n";
	logentry ($strOut);
	print OUT $strOut;
}

$session->close;
close(OUT);
close(LOG);
exit 0;

sub logentry
	{
		my($outmsg) = @_;
		print $outmsg;
		print LOG $outmsg;
	}