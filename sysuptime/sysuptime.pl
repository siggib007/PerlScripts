use strict;
use SNMP_util;
use Win32::OLE;
$|=1;

$SNMP_Session::suppress_warnings=2;

my ($ip,$ro,$size,$days,$hrs,$mins,$hms,$apname);
my %devices=();

print "Getting List of APs...\n\n";
getAPlist();

my $count=scalar keys %devices;

foreach my $apname (sort keys %devices) {
	$ip = $devices{$apname};
	#
 	# Add SNMP RO string here, or you could read it from a database so you don't have to store it here.
 	#
	$ro = "xxxxxxx";
	getAPsysuptime($apname);	
}

print "\nTotal APs: $count\n";


sub getAPlist {

    my $Conn = Win32::OLE->new("ADODB.Connection")
	or die "Can't create connection: ".Win32::OLE->LastError();
    
    #
    # Add database server name, login creds, and table name
    #
    $Conn->Open('Provider=SQLOLEDB.1;Data Source=xxxxx;User Id=xxxxx;PASSWORD=xxxxx;Initial Catalog=xxxxx;');

    if (Win32::OLE->LastError()) {
	die "Open: ".Win32::OLE->LastError();
    }

    my $sqlquery=<<EOU;
select  devicename, deviceipaddress
from    dbo.vwDevicesActive
where devicemodel like '%AP%' 
and deviceipaddress like '172.2[0168].%'
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


sub getAPsysuptime {
	my ($apname) = @_;
	undef ($days);
	undef ($hrs);
	undef ($mins);
	my @apinfo;
	
	@apinfo=snmpget("$ro\@$ip",'sysUpTime');

	my $size = @apinfo;
	if (($#apinfo == 0) && ($size == 1) && !($apinfo[0])) {
		print "$apname SysUpTime: ** SNMP Timeout **\n";
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
		
	print "$apname SysUpTime: $apinfo[0]\n";
	return;
}
