use strict;
use Win32::OLE;
use SNMP_util;

my ($ip,$rw1,$rw2,$device,$days,$hms,$hrs,$mins,$bootcode,$pingap,$pingrtr,$status,$ap,$apname,$Cmd,$downtime);
my ($totdowntime,$bootcnt,$totbootcnt,$lasttotbootcnt);
my %devices=();

$status = 1;

getAPlist();


openSQL();

foreach $ap (sort keys %devices) {
	$apname = $ap;
	$ip = $devices{$apname};
	
	$SNMP_Session::suppress_warnings=2;

	$ro = "xxxxxxx";  #Add SNMP RO string

	getapinfo($ro);
	
	if (!$status) {
		print "\n\nPinging $apname: ";
		my $png = `ping -n 1 $ip`;
		if ($png =~ /Reply/ & $png !~ /unreachable/) {
			$pingap = 1;
			print "$png\n";
#			print "pingable = $pingap\n\n";
			print "\nTry again...\n";
			getapinfo();
		} else {
			$pingap = 0;
			print "$png\n";
#			print "pingable = $pingap\n";
			
			my $rtrip = $ip;
			$rtrip =~ s/.\d*$/.1/;
			my $png = `ping -n 1 $rtrip`;
			if ($png =~ /Reply/ & $png !~ /unreachable/) {
				$pingrtr = 1;
				print "$png\n";
#				print "pingable = $pingrtr\n\n";
				print "Router is pingable\n";
			} else {
				$pingrtr = 0;
				print "Router is not pingable\n";
			}

		}
		$status = 1;
	}
	if ($bootcode eq "SNMP Timeout") {
#		print "Timeout\n";
		($downtime,$totdowntime) = getlastdowntime();
		if ($downtime < 30) {
			$downtime = 30;
			$totdowntime = 30;
		}else {
			$downtime = 60;
			$totdowntime += $downtime;
		}
	} elsif ($days == 0 && $hrs == 0) {
		my $tmp1 = getlaststatus();
		if ($tmp1 eq 'SNMP TIMEOUT') {
			$downtime = 60 - $mins;
			$totdowntime += $downtime;
		} else {
			if ($apname =~ /a12/) {
#				print "AP 1200 Booted\n";
				$downtime = 2;
				$totdowntime += $downtime;
			} else {
#				print "THIS IS NOT AN AP1200\n";
#				print "1> DownTime = $downtime, TotalDownTime = $totdowntime, TotalBootCnt = $totbootcnt, LastTotalBootCnt = $lasttotbootcnt, Bootcnt = $bootcnt\n";
				$lasttotbootcnt = getlastbootcnt();
				($downtime,$totdowntime) = getlastdowntime();
				if ($lasttotbootcnt == "" && $totbootcnt >= 0) {
					$lasttotbootcnt = $totbootcnt;
				} elsif ($totbootcnt < $lasttotbootcnt) {
					$lasttotbootcnt = $totbootcnt;
				}
				$bootcnt = $totbootcnt - $lasttotbootcnt;
#				print "ERROR: last hour bootcount = 0 for $apname\n" if $tmp2 = 0;
				$downtime = $bootcnt * 2;
				$totdowntime += $downtime;
#				print "2> DownTime = $downtime, TotalDownTime = $totdowntime, TotalBootCnt = $totbootcnt, LastTotalBootCnt = $lasttotbootcnt, Bootcnt = $bootcnt\n";
			}
		}
	} else {
		$downtime = 0;
		$totdowntime = 0;
		$bootcnt = 0;
	}

#	print "$apname,$days,$hrs,$mins,$bootcode,$pingap,$pingrtr,$downtime,$totdowntime,$bootcnt,$totbootcnt\n";
	addapuptime ($apname,$days,$hrs,$mins,$bootcode,$pingap,$pingrtr,$downtime,$totdowntime,$bootcnt,$totbootcnt);
}

closeSQL();

aptimesync();

#apavail();


sub getAPlist {

    my $Conn = Win32::OLE->new("ADODB.Connection")
	or die "Can't create connection: ".Win32::OLE->LastError();
    $Conn->Open('Provider=SQLOLEDB.1;Data Source=xxxxxx;User Id=xxxxxx;PASSWORD=xxxxxxx;Initial Catalog=xxxxxxx;');

    if (Win32::OLE->LastError()) {
	die "Open: ".Win32::OLE->LastError();
    }

    my $sqlquery=<<EOU;
select  devicename, deviceipaddress
from    dbo.vwDevicesActive with (nolock)
where (devicemodel like '% AP%' or devicemodel like '%AIR%') 
and deviceipaddress like '172.28.%'
EOU

    my $RS = $Conn->Execute($sqlquery);		# pointer to Record Set
    if (Win32::OLE->LastError()) {
	die print "SQL Execute failed: ($sqlquery)".Win32::OLE->LastError(),"\n";
    }

	if ($RS) {
		while ( ! $RS->EOF ) {
            $devices{$RS->{'devicename'}->Value} = $RS->{'deviceipaddress'}->Value;
			$RS->MoveNext;
		}
		$RS->close;
	} else {
		print "$sqlquery: No Data\n".Win32::OLE->LastError(),"\n";
	}
	
    $Conn->Close;
    return;
}

sub getapinfo {
	my($snmp) = @_;
	undef ($days);
	undef ($hrs);
	undef ($mins);
	undef ($bootcode);
	undef ($pingap) if ($status == 1);
	undef ($pingrtr) if ($status == 1);
	undef ($bootcnt);
	undef ($totbootcnt);
	my @apinfo;
	
	if ($apname =~ /a12/) {
		@apinfo=snmpget("$snmp\@$ip",'sysUpTime', 'apBootCode');
	} else {
		@apinfo=snmpget("$snmp\@$ip",'sysUpTime', 'apBootCode','bootconfigBootCount');
	}

	my $size = @apinfo;
	if (($#apinfo == 0) && ($size == 1) && !($apinfo[0])) {
		$bootcode = "SNMP Timeout";
		$status = 0;
		print "$apname -> SNMP Timeout\n";
		return;
	}

	($days,$hms) = (split(/,/,$apinfo[0]));
	$hms = (split(/ /,$hms))[1];
	if ($days =~ /day/) {
		$days = (split(/ /,$days))[0];
	} else {
		$hms = $days;
		$days = 0;
	}
	($hrs,$mins) = (split(/:/,$hms));
	
	$bootcode = $apinfo[1];
#	print "BOOT CODE = $bootcode\n";
		
	if ($apname =~ /a12/) {
		undef($totbootcnt);
	} else {
		$totbootcnt = $apinfo[2];
#		print "BOOT COUNT = $totbootcnt\n";
	}
	
	print "$apname -> OK\n";
	return;
}

sub openSQL {
 	$Cmd = Win32::OLE->new("ADODB.Command") or die "Error: Can't create Command connection: ".Win32::OLE->LastError(); 
 	$Cmd->{ActiveConnection} = 'Provider=SQLOLEDB.1;Data Source=xxxxx;User Id=xxxxxx;PASSWORD=xxxxxxx;Initial Catalog=xxxxx;';
	return;
}

sub closeSQL {
	 $Cmd->Close;
	 return;
}
	
sub addapuptime {
	my($dn,$ud,$uh,$um,$bc,$pap,$prtr,$dt,$tdt,$bcnt,$tbcnt) = @_;
#	print "DN = $dn\n";
 	return print "Error: addapuptime must be called with valid names."
 		unless $dn;
 	$Cmd->{CommandType} = 4;
 	$Cmd->{CommandText} = 'addap_ps';
 	$Cmd->Parameters->Refresh();
 	$Cmd->Parameters('@devicename')->{Value} = $dn;
 	$Cmd->Parameters('@uptimedays')->{Value} = $ud;
 	$Cmd->Parameters('@uptimehrs')->{Value} = $uh;
 	$Cmd->Parameters('@uptimemins')->{Value} = $um;
 	$Cmd->Parameters('@bootcode')->{Value} = uc($bc);
 	$Cmd->Parameters('@pingap')->{Value} = $pap;
 	$Cmd->Parameters('@pingrtr')->{Value} = $prtr;
 	$Cmd->Parameters('@downtime')->{Value} = $dt;
 	$Cmd->Parameters('@totdowntime')->{Value} = $tdt;
 	$Cmd->Parameters('@bootcnt')->{Value} = $bcnt;
 	$Cmd->Parameters('@totbootcnt')->{Value} = $tbcnt;
 	my $RS = $Cmd->Execute();
 	if (Win32::OLE->LastError()) {
 		die print "SQL Execute failed".Win32::OLE->LastError(),"\n";
 	}
 	return;
}

sub aptimesync {
 	my $Cmd = Win32::OLE->new("ADODB.Command") 
        or die "Error: Can't create Command connection: ".Win32::OLE->LastError(); 
 	$Cmd->{ActiveConnection} = 'Provider=SQLOLEDB.1;Data Source=xxxxx;User Id=xxxxx;PASSWORD=xxxx;Initial Catalog=xxxx;';
 	$Cmd->{CommandType} = 4;
 	$Cmd->{CommandText} = 'aptimesync';
 	$Cmd->{CommandTimeout} = 300;
 	my $RS = $Cmd->Execute();
 	if (Win32::OLE->LastError()) {
 		die print "SQL Execute failed".Win32::OLE->LastError(),"\n";
 	}
 	$Cmd->Close;
 	return;
}

sub getlastdowntime {
	my $apdt;
	my $totapdt;
	
    my $Cmd = Win32::OLE->new("ADODB.Connection")
	or die "Can't create connection: ".Win32::OLE->LastError();
    $Cmd->Open('Provider=SQLOLEDB.1;Data Source=xxxxxx;User Id=xxxxx;PASSWORD=xxxx;Initial Catalog=xxxx;');

    if (Win32::OLE->LastError()) {
	die "Open: ".Win32::OLE->LastError();
    }

	my $sqlquery=<<EOU;
select  downtime,totdowntime
from    apuptime with (nolock)
where display = 1 and devicename = '$apname'
EOU

	my $RS = $Cmd->Execute($sqlquery);		# pointer to Record Set
	if (Win32::OLE->LastError()) {
		die print "SQL Execute failed: ($sqlquery)".Win32::OLE->LastError(),"\n";
	}

	if ($RS) {
           	$apdt = $RS->{'downtime'}->Value;
           	$totapdt = $RS->{'totdowntime'}->Value;
		$RS->close;
	} else {
#		print "$sqlquery: No Data\n".Win32::OLE->LastError(),"\n";
		$apdt = 0;
		$totapdt = 0;
	}
	
	$Cmd->Close;
	return $apdt,$totapdt;
}

sub apavail {
 	my $Cmd = Win32::OLE->new("ADODB.Command") 
        or die "Error: Can't create Command connection: ".Win32::OLE->LastError(); 
 	$Cmd->{ActiveConnection} = 'Provider=SQLOLEDB.1;Data Source=xxxxx;User Id=xxxxx;PASSWORD=xxxxxx;Initial Catalog=xxxxx;';
 	$Cmd->{CommandType} = 4;
 	$Cmd->{CommandText} = 'ap_avail3';
 	$Cmd->{CommandTimeout} = 300;
 	my $RS = $Cmd->Execute();
 	if (Win32::OLE->LastError()) {
 		die print "SQL Execute failed".Win32::OLE->LastError(),"\n";
 	}
 	$Cmd->Close;
 	return;
}

sub getlastbootcnt {
	my $apbtcnt;
	
    my $Cmd = Win32::OLE->new("ADODB.Connection")
	or die "Can't create connection: ".Win32::OLE->LastError();
    $Cmd->Open('Provider=SQLOLEDB.1;Data Source=xxxxx;User Id=xxxxx;PASSWORD=xxxxxx;Initial Catalog=xxxxxx;');

    if (Win32::OLE->LastError()) {
	die "Open: ".Win32::OLE->LastError();
    }

	my $sqlquery=<<EOU;
select  totbootcnt
from    apuptime with (nolock)
where display = 1 and devicename = '$apname'
EOU

	my $RS = $Cmd->Execute($sqlquery);		# pointer to Record Set
	if (Win32::OLE->LastError()) {
		die print "SQL Execute failed: ($sqlquery)".Win32::OLE->LastError(),"\n";
	}

	if ($RS) {
           	$apbtcnt = $RS->{'totbootcnt'}->Value;
		$RS->close;
	} else {
#		print "$sqlquery: No Data\n".Win32::OLE->LastError(),"\n";
		$apbtcnt = 0;
	}
	
	$Cmd->Close;
	return $apbtcnt;
}

sub getlaststatus {
	my $apbc;
	
    my $Cmd = Win32::OLE->new("ADODB.Connection")
	or die "Can't create connection: ".Win32::OLE->LastError();
    $Cmd->Open('Provider=SQLOLEDB.1;Data Source=xxxxxx;User Id=xxxxx;PASSWORD=xxxxxx;Initial Catalog=xxxxx;');

    if (Win32::OLE->LastError()) {
	die "Open: ".Win32::OLE->LastError();
    }

	my $sqlquery=<<EOU;
select  bootcode
from    apuptime with (nolock)
where display = 1 and devicename = '$apname'
EOU

	my $RS = $Cmd->Execute($sqlquery);		# pointer to Record Set
	if (Win32::OLE->LastError()) {
		die print "SQL Execute failed: ($sqlquery)".Win32::OLE->LastError(),"\n";
	}

	if ($RS) {
           	$apbc = $RS->{'bootcode'}->Value;
		$RS->close;
	} else {
#		print "$sqlquery: No Data\n".Win32::OLE->LastError(),"\n";
		$apbc = 0;
	}
	
	$Cmd->Close;
	return $apbc;
}