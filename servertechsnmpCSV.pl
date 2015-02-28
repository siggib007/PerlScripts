use strict;
use net::SNMP;
use English;
use Sys::Hostname;
my ($device,$comstr,$session,$error,$sysname,$result,$outfile, $numin, $logfile, $errmsg, $key, $len, $id, $progname);
my ($OutletID, $OutletName, $OutletStatus, $Outletloadstatus, $OutletLoadValue, %OutletStatusCodes, %loadstatusCodes);
my (%strOutletIDs, %strOutletNames, %strOutletStatus, %strOutletloadstatus, %OutletLoadValueNums, %reshash, $strOut);
my ($devname, $InFile, $line, $IPAddr, $BTUs, $Value);

$numin = scalar(@ARGV);
if ($numin != 2)
	{
		print "\nInvalid usage: Two arguments are required and you supplied $numin\n\n";
		print "Correct usage: perl $PROGRAM_NAME InFile OutFile\n\n";
		print "InFile: A comma seperate file listing the target server techs\n";
		print "OutFile: filename with complete path of where you want the results saved.\n\n";
		print "Ex: perl $PROGRAM_NAME c:/tools/servertechs.csv c:/tools/snmpout.csv \n";
		exit(1);
	}
	
print "starting $PROGRAM_NAME\n";
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname.log";
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");

$InFile = $ARGV[0];
$outfile = $ARGV[1];

$InFile=~s/\\/\//g;

$outfile=~s/\\/\//g;

open(IN,"<",$InFile) || die "cannot open InFile $InFile for read: $!";

open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

$sysname          = '1.3.6.1.2.1.1.5.0';
$OutletID         = '.1.3.6.1.4.1.1718.3.2.3.1.2';
$OutletName       = '.1.3.6.1.4.1.1718.3.2.3.1.3';
$OutletStatus     = '.1.3.6.1.4.1.1718.3.2.3.1.5';
$Outletloadstatus = '.1.3.6.1.4.1.1718.3.2.3.1.6';
$OutletLoadValue  = '.1.3.6.1.4.1.1718.3.2.3.1.7';

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

$strOut = "Device,IP,SysName,OutletID,OutletName,OutletStatus,OutletLoadStatus,OutletLoadValue,Est. BTU/hr\n";
logentry ($strOut);
print OUT $strOut;

foreach $line (<IN>)
{
	chomp($line);
	($device,$IPAddr,$comstr)  = split (/,/, $line);
	
	logentry("processing $device at address $IPAddr...\n");
	
	($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr);
	if (!defined($session)) {
	      cleanup("Connect ERROR: $error\n",1);
	   }
	
	logentry("Fetching Sysname\n");
	
	$result = $session->get_request($sysname);
	if (!defined($result)) 
	{
		$errmsg = $session->error;
	  logentry("Sysname ERROR: $errmsg\n");
	  $devname = $errmsg;
	}
	else
	{
		$devname = $result->{$sysname};
		
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
				$len = length($OutletName);
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
				$len = length($Outletloadstatus);
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
				$Value = $reshash{$key};
				if ($Value == -1)
				{
					$Value = "Fail";
				}
				else
				{
					$Value = $Value / 100;
				}
				$len = length($OutletLoadValue);
				$id = substr($key,$len+1);
				$OutletLoadValueNums{$id} = $Value;
				#logentry ("$id\t$OutletLoadValueNums{$id}\n");
			}
		}
	} 
	logentry ("Devname: $devname\nErr: $errmsg\n");
	if ($devname eq $errmsg)
	{
		$strOut = "$device,$IPAddr,$devname\n";
		logentry ($strOut);
		print OUT $strOut;		
	}
	else
	{
		foreach $key(sort(keys %strOutletIDs))
		{
			$BTUs = "";
			if ($OutletLoadValueNums{$key} ne "Fail")
			{
				$BTUs = $OutletLoadValueNums{$key}*164;
			}
			$strOut = "$device,$IPAddr,$devname,$strOutletIDs{$key},$strOutletNames{$key},$strOutletStatus{$key},$strOutletloadstatus{$key},$OutletLoadValueNums{$key},$BTUs\n";
			logentry ($strOut);
			print OUT $strOut;
		}
	}
	$session->close;
}

cleanup("Done!\n",0);

sub logentry
	{
		my($outmsg) = @_;
		print $outmsg;
		print LOG $outmsg;
	}
	
sub cleanup
{
	my($closemsg,$exitcode) = @_;
	logentry($closemsg);
	$session->close;
	close (OUT) or warn "error while closing the outfile file $outfile: $!" ;
	close (LOG) or warn "error while closing log file $logfile: $!" ;
	close (IN) or warn "error while closing the input file $InFile: $!" ;
	exit($exitcode);
}
