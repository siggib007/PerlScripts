use Win32::ODBC;
#if (!($O = new Win32::ODBC("driver=sql Server;server=TK2STGSQLH04;UID=scriptRW;PWD=Martin1?;"))){
if (!($O = new Win32::ODBC("driver=sql Server;server=SAGNSSCR01;UID=readonly;PWD=readonly;"))){
	print 'Error: ODBC Open Failed: ',Win32::ODBC::Error(),"\n";
	die "  Open configAccessDB: ".Win32::ODBC::Error();
}
#$sqlQuery = "select configitemname from socadmin.dbo.tblNetDevice where datacentername like 'Shanghai%'";
$sqlQuery = "select datacentername from socadmin.dbo.tblNetDevice where configitemname = 'sha-6nb-1a'";

if (! $O->Sql($sqlQuery)) 
{
	$O->FetchRow();
	%sqlData = $O->DataHash();
	print "$sqlData{datacentername}\n";
}
$O->Close();
