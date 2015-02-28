use strict;
use Socket;

use Win32::OLE 'in';
my ($SrcCN, $SrcRS, $cmdText, $srcDBServer, $i, $DevName);
my ($packed_ip, $ip_address, $iaddr, $HostName);

$i = 1;
$srcDBServer = "SEAVVAS001W02";
$cmdText = "select vcDeviceName from inventory.dbo.tbldevices";

$SrcCN = new Win32::OLE "ADODB.Connection";
$SrcRS = new Win32::OLE "ADODB.Recordset";

$SrcCN->{Provider} = "sqloledb";
$SrcCN->{Properties}{"Data Source"}->{value} = $srcDBServer;
$SrcCN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open Connection\n";
$SrcCN->open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to Open Connection\n".Win32::OLE->LastError(),1);}
print "attempting to execute query\n";
$SrcRS->Open ($cmdText, $SrcCN);
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch data\n".Win32::OLE->LastError(),1);}
while ( !$SrcRS->EOF )
	{
		$DevName = $SrcRS->{fields}{vcDeviceName}->{value};
		print "$i: $DevName\n";	
    $packed_ip = gethostbyname($DevName);
    if (defined $packed_ip) 
    	{
        $ip_address = inet_ntoa($packed_ip);
    		print "IP Addr: $ip_address\n";
    		$iaddr = inet_aton($ip_address);
    		$HostName  = gethostbyaddr($iaddr, AF_INET);
		    print "host addr: $HostName\n";    	}
    else
    	{
    		print "Unable to resolve\n";
    	}	
		$SrcRS->MoveNext;
		$i += 1;
	}
$SrcRS->Close;
undef $SrcRS;
$SrcCN->Close;
undef $SrcCN;

cleanup("Done",0);

sub cleanup
{
	my($closemsg,$exitcode) = @_;
	print $closemsg;
	exit($exitcode);
}