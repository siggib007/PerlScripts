use strict;
use net::SNMP;
use English;
use Sys::Hostname;
use DBI();

my ($device,$comstr,$session,$error,$sysname,$result, $logfile, $errmsg, $key, $len, $id, $progname, $Loc);
my ($OutletID, $OutletName, $OutletStatus, $Outletloadstatus, $OutletLoadValue, %OutletStatusCodes, %loadstatusCodes);
my (%strOutletIDs, %strOutletNames, %strOutletStatus, %strOutletloadstatus, %OutletLoadValueNums, %reshash);
my ($devname, $line, $IPAddr, $BTUs, $Value, $DBName, $DBHost, $DBUser, $DBpwd, $strSQL, $sth, $dbh, $dtStart);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$dtStart = "$year-$mon-$mday $hour:$min";
print "starting $PROGRAM_NAME\n";
($progname) = split(/\./,$PROGRAM_NAME);
$logfile = "$progname.log";
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing $PROGRAM_NAME ....\n");

$DBHost = "localhost";
$DBName = "capacity";
$DBUser = "script";
$DBpwd  = "test123";
$strSQL = "select vcdevname,vcipaddr,vccomstr,vcLocation from tblservertecs;";

$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost", "$DBUser", "$DBpwd", {'RaiseError' => 1});

$sysname              = '1.3.6.1.2.1.1.5.0';
$OutletID             = '.1.3.6.1.4.1.1718.3.2.3.1.2';
$OutletName           = '.1.3.6.1.4.1.1718.3.2.3.1.3';
$OutletStatus         = '.1.3.6.1.4.1.1718.3.2.3.1.5';
$Outletloadstatus     = '.1.3.6.1.4.1.1718.3.2.3.1.6';
$OutletLoadValue      = '.1.3.6.1.4.1.1718.3.2.3.1.7';

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

$loadstatusCodes{0}   = 'normal';
$loadstatusCodes{1}   = 'notOn';
$loadstatusCodes{2}   = 'reading';
$loadstatusCodes{3}   = 'loadLow';
$loadstatusCodes{4}   = 'loadHigh';
$loadstatusCodes{5}   = 'overLoad';
$loadstatusCodes{6}   = 'readError';
$loadstatusCodes{7}   = 'noComm';

$sth = $dbh->prepare($strSQL);
$sth->execute();
while ($line = $sth->fetchrow_hashref())
{
	$device = $line->{'vcdevname'};
	$IPAddr = $line->{'vcipaddr'};
	$comstr = $line->{'vccomstr'};
	$Loc    = $line->{'vcLocation'};
	
	logentry("processing $device at address $IPAddr located in $Loc...\n");
	
	($session,$error) = Net::SNMP->session(hostname => $IPAddr, community => $comstr);
	if (!defined($session)) {
	      cleanup("Connect ERROR: $error\n",1);
	   }
	
	logentry("Fetching Sysname\n");
	
	$result = $session->get_request($sysname);
	if (!defined($result)) 
	{
		$errmsg = $session->error;
	  logerror("Sysname", $errmsg);
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
		  logerror("OutletID", $errmsg);
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
		  logerror("OutletName", $errmsg);
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
		  logerror("OutletStatus", $errmsg);
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
		  logerror("Outletloadstatus", $errmsg);
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
		  logerror("OutletLoadValue", $errmsg);
		}
		else
		{
			%reshash = %$result;			
			foreach $key(sort(keys %reshash)) 
			{ 
				$Value = $reshash{$key};
				if ($Value == -1)
				{
					$Value = "NULL";
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
	#logentry ("Devname: $devname\nErr: $errmsg\n");
	if ($devname eq $errmsg)
	{
		$devname =~s/\'/''/g;
		$strSQL  = "insert into tbldevpower (dtMeasuredTime,vcDevName,vcIPAddr,vcSysName,vcLocation) ";
		$strSQL .= "values ('$dtStart','$device','$IPAddr','$devname','$Loc');";
		#logentry ($strSQL);
		$dbh->do($strSQL);
	}
	else
	{
		foreach $key(sort(keys %strOutletIDs))
		{		
			$strSQL = "insert into tbldevpower (dtMeasuredTime,vcDevName,vcIPAddr,vcSysName,vcLocation,vcOutletID,vcOutletName,vcOutletStatus,vcOutletLoadStatus,fOutletLoadValue) ";
			$strSQL .= "values ('$dtStart','$device','$IPAddr','$devname','$Loc','$strOutletIDs{$key}','$strOutletNames{$key}','$strOutletStatus{$key}','$strOutletloadstatus{$key}',$OutletLoadValueNums{$key});";
			#logentry ($strSQL);
			$dbh->do($strSQL);
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
	close (LOG) or warn "error while closing log file $logfile: $!" ;
	$dbh->disconnect();
	exit($exitcode);
}

sub logerror
	{
		my($ErrType,$ErrMsg) = @_;
		my($SQLcmd);
		logentry("$ErrType ERROR: $ErrMsg\n");
		$ErrMsg =~s/\'/''/g;
		$SQLcmd = "insert into tblerrorlog (dtErrorTime, vcErrType, vcErrDescr) values (now(),'$ErrType','$ErrMsg');";
		#logentry ("$SQLcmd\n");
		$dbh->do($SQLcmd);
	}