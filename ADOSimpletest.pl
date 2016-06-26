use strict;
use Win32::OLE 'in';
my ($SrcCN, $SrcRS, $cmdText, $srcDBServer, $i);

$srcDBServer = "SEAVVAS001W02";
$i=1;

#$cmdText = "select datacenter, shortcode, DCGroup from cmdb.dbo.dclist";
#$cmdText = "select DeviceName from Inventory.dbo.vwProdDeviceList";
$cmdText = "select * from inventory.dbo.tblmodel";

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
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch query\n".Win32::OLE->LastError(),1);}
while ( !$SrcRS->EOF )
{
	print "$i:  $SrcRS->{fields}{vcModelName}->{value}\n";	
	$SrcRS->MoveNext;	
	$i+=1
}
$SrcRS->Close;
undef $SrcRS;
$SrcCN->Close;
undef $SrcCN;

exit(0);

sub cleanup
{
	my($closemsg,$exitcode) = @_;
	print $closemsg;
	exit($exitcode);
}