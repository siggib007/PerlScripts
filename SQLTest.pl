use Win32::ODBC;
if (!($O = new Win32::ODBC("driver=sql Server;server=satnetengfs01;UID=readonly;PWD=readonly;"))){
	print 'Error: ODBC Open Failed: ',Win32::ODBC::Error(),"\n";
	die "  Open configAccessDB: ".Win32::ODBC::Error();
}
#$sqlQuery = "select configitemname from socadmin.dbo.tblNetDevice where datacentername like 'Shanghai%'";
#$sqlQuery = "select datacentername from socadmin.dbo.tblNetDevice where configitemname = 'sha-6nb-1a'";
$sqlquery = "select DeviceName from reports.dbo.brixdevices";
if (! $O->Sql($sqlQuery)) {
	while($O->FetchRow()) {
		%sqlData = $O->DataHash();
		print "$sqlData{DeviceName}\n";
	}
} else {
	die "  Query error: ".Win32::ODBC::Error();
}

$O->Close();
