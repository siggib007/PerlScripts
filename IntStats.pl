use strict;
use Net::SNMP;
use English;

my ($comstr, $session, $error, $sysname, $result, $ID, $logfile, $verbose, $LogLevel, $StopTime);
my (%tableOIDs, $value, $errmsg, $Tablekey, $devname, $OutKey, $DeviceIP, $LogPath, $OutPath);
my ($ElapseSec, $StartTime, $OIDResult, %outhash, $SleepSec, $RunTimeSec, @IntIDs, $pfh);
my ($scriptFullName, @tmp, $pathparts, $ShortName, $progname, $strOut, $outfile, $isec);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$mon ++;
$min = substr("0$min",-2);
$sec = substr("0$sec",-2);

$verbose    = 2;
$LogLevel   = 5;

$comstr = 'ctipublic';
$DeviceIP = "10.31.28.190";

$SleepSec = 60;
$RunTimeSec = 60 * 15;

$IntIDs[0] = 21;
$IntIDs[1] = 22;
$IntIDs[2] = 23;
$IntIDs[3] = 24;
$IntIDs[4] = 17645;

$LogPath = "/var/log/scripts";
$OutPath = "/var";

$tableOIDs{"ifDesc"}          = "1.3.6.1.2.1.2.2.1.2";
$tableOIDs{"ifHCInOctets"}    = "1.3.6.1.2.1.31.1.1.1.6";
$tableOIDs{"ifHCoutOctets"}   = "1.3.6.1.2.1.31.1.1.1.10";
$tableOIDs{"ifInDiscards"}    = "1.3.6.1.2.1.2.2.1.13";
$tableOIDs{"ifInErrors"}      = "1.3.6.1.2.1.2.2.1.14";
$tableOIDs{"ifOutDiscards"}   = "1.3.6.1.2.1.2.2.1.19";
$tableOIDs{"ifOutErrors"}     = "1.3.6.1.2.1.2.2.1.20";

$sysname = '1.3.6.1.2.1.1.5.0';

$StartTime = time();

$scriptFullName = $PROGRAM_NAME;
$scriptFullName =~ s/\\/\//g;	
@tmp = split(/\//,$scriptFullName);
$pathparts = scalar @tmp;
$ShortName = $tmp[$pathparts-1];
($progname) = split(/\./,$ShortName);

$logfile = "$LogPath/$progname-$mon-$mday-$year.log";

print "Logging to $logfile\n";

open(LOG,">>",$logfile) || die "cannot open logfile $logfile for append: $!";

$pfh = select LOG;
$| = 1;
select $pfh;

logentry ("Starting $ShortName. Will collect stats for $RunTimeSec seconds.\n",0,0);

logentry ("Opening SNMP connection to $DeviceIP\n",1,0);
($session,$error) = Net::SNMP->session(-hostname => $DeviceIP, -community => $comstr, -timeout => 10, -version => 2);
if (!defined($session)) 
{
	printf("ERROR: %s.\n", $error);
  next;
}

$result = $session->get_request($sysname);
if (!defined($result)) 
{
	$error = $session->error;
	$errmsg = "SNMP ERROR: $error.";
	logentry ("$errmsg\n",1,0);
  $session->close;
  next;
}
$devname = $result->{$sysname};
logentry ("device name is $devname\n",2,1);

$outfile = "$OutPath/$devname-$mon-$mday-$year-$hour-$min.csv";
logentry ("writing output to $outfile \n",2,1);
open(OUT,">",$outfile) || die "cannot open outfile $outfile for write: $!";

$pfh = select OUT;
$| = 1;
select $pfh;

#print OUT "Interface stats for $devname\n";
print OUT "TimeStamp,ElapseSec,IntName,InOctets,OutOctets,InDiscards,InErrors,OutDiscards,OutErrors\n";
while ((time() - $StartTime) < $RunTimeSec)
{
	undef %outhash;
	  
	$ElapseSec = time() - $StartTime;

	foreach $Tablekey (sort keys %tableOIDs)  
	{
		foreach $ID (@IntIDs)
		{
			$value = $tableOIDs{$Tablekey} . "." . $ID;
			logentry("Issuing a SNMP get for $Tablekey ID $ID ... \n",2,1);
			logentry ("OID: $value\n",3,2);
			$result = $session->get_request($value);
			if (!defined($result)) 
			{
				$error = $session->error;
				$errmsg = "SNMP ERROR: $error.";
				logentry ("$errmsg\n",2,1);
			}
			else
			{
				$OIDResult = $result->{$value};
				$OIDResult =~ s/^\s+//;
				$OIDResult =~ s/\s+$//;
				$OIDResult =~ s/\n/ /g;
				$OIDResult =~ s/\t/ /g;
				$OIDResult =~ s/\r/ /g;
				$OIDResult =~ s/\'/\'/g;
				$outhash{$ID}{$Tablekey} = $OIDResult;
			}
		}
	}
	logentry("Writing results to $outfile ... \n",2,1);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);
	$mon = $mon + 1;
	$sec = substr("0$sec",-2);
	
	foreach $OutKey (sort keys %outhash)
	{
		$strOut  = "$mon/$mday/$year $hour:$min:$sec,$ElapseSec,";
		$strOut .= "$outhash{$OutKey}{ifDesc},$outhash{$OutKey}{ifHCInOctets},$outhash{$OutKey}{ifHCoutOctets},";
		$strOut .= "$outhash{$OutKey}{ifInDiscards},$outhash{$OutKey}{ifInErrors},$outhash{$OutKey}{ifOutDiscards},";
		$strOut .= "$outhash{$OutKey}{ifOutErrors}\n";
		logentry ("output: $strOut",3,2);
		print OUT "$strOut";
	}
	logentry ("Waiting for $SleepSec seconds and then repeat ... \n",2,1);
	sleep $SleepSec;
}

$session->close;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$sec = substr("0$sec",-2);

$StopTime = time;
$isec = $StopTime - $StartTime;

logentry ("Done processing $ShortName at $mon/$mday/$year $hour:$min\n",0,0);
logentry ("Processing took $isec seconds.\n",0,0);

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
