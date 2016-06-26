use strict;
use Win32::OLE 'in';
my ($SrcCN, $SrcRS, $dstCN, $dstRS, $cmdText, $srcDBServer,$dstDBServer, $DefaultDB, $dsn, $Cmd);

$srcDBServer = "by2netsql01";
$dstDBServer = "satnetengfs01";

$cmdText = "select datacenter, shortcode, DCGroup from cmdb.dbo.dclist";

$SrcCN = new Win32::OLE "ADODB.Connection";
$SrcRS = new Win32::OLE "ADODB.Recordset";
$dstCN = new Win32::OLE "ADODB.Connection";
$dstRS = new Win32::OLE "ADODB.Recordset";
$Cmd   = new Win32::OLE "ADODB.Command";

$SrcCN->{Provider} = "sqloledb";
$SrcCN->{Properties}{"Data Source"}->{value} = $srcDBServer;
$SrcCN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open Connection\n";
$SrcCN->open;
print "attempting to execute query\n";
$SrcRS->Open ($cmdText, $SrcCN);
$dstCN->{Provider} = "sqloledb";
$dstCN->{Properties}{"Data Source"}->{value} = $dstDBServer;
$dstCN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open connection to destination";
$dstCN->open;
print "Opening dest table";
$dstRS->{LockType} = 3; #adLockOptimistic
$dstRS->{ActiveConnection} = $dstCN;
$dstRS->{Source} = "gns.dbo.dclist";
$dstRS->Open;
$Cmd->{ActiveConnection} = $dstCN;
$Cmd->{CommandText} = "delete from gns.dbo.dclist";
$Cmd->{Execute};

while ( !$SrcRS->EOF )
{
	print "$SrcRS->{fields}{datacenter}->{value}\t$SrcRS->{fields}{shortcode}->{value}\t$SrcRS->{fields}{DCGroup}->{value}\n";	
	$SrcRS->MoveNext;
	$dstRS->AddNew;
		$dstRS->{fields}{datacenter}->{value} = $SrcRS->{fields}{datacenter}->{value};
		$dstRS->{fields}{shortcode}->{value} = $SrcRS->{fields}{shortcode}->{value};
		$dstRS->{fields}{DCGroup}->{value} = $SrcRS->{fields}{DCGroup}->{value};
	$dstRS->Update;
	
}
$SrcRS->Close;
undef $SrcRS;
$SrcCN->Close;
undef $dstCN;
$dstRS->Close;
undef $dstRS;
#$dstCN->Close;
undef $dstCN;
undef $Cmd;

exit(0);}->{value} = $SrcRS->{fields}{shortcode}->{value};
		$dstRS->{fields}{DCGroup}->{value} = $SrcRS->{fields}{DCGroup}->{value};
	$dstRS->Update; # || die "failed to update recordset: $!";
	$SrcRS->MoveNext; # || die "couldn't movenext: $!";
}
$SrcRS->Close;
undef $SrcRS;
$SrcCN->Close;
undef $dstCN;
$dstRS->Close;
undef $dstRS;
#$dstCN->Close;
undef $dstCN;
undef $Cmd;

exit(0);