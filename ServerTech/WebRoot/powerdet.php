<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<title>Clearwire Detailed Power Usage report</title>
</head>
<body>
<?php
$PageName = $_SERVER["SCRIPT_NAME"];
$dtSel  = $_GET["dt"];
$strLoc = $_GET["loc"];
$strDev = $_GET["dev"];
$UID = "script";
$PWD = "test123";
$DefaultDB = "capacity";
$DBServerName = "localhost";
$dbh=mysql_connect ($DBServerName, $UID, $PWD) 
		or die ('I cannot connect to the database because: ' . mysql_error());
mysql_select_db ($DefaultDB);
$strQuery = "select max(dtMeasuredTime) dtmax from vwPowerBTU;";
$Result = mysql_query ($strQuery,$dbh) or die ('Failed to fetch data because: ' . mysql_error());
$Row = mysql_fetch_array($Result)  or die ('Failed to fetch data because: ' . mysql_error());
$dtMax = $Row['dtmax'];
if ($dtSel == "")
{
	$dtSel = $dtMax;
}
$strQuery = "select distinct dtMeasuredTime from tbldevpower order by dtMeasuredTime desc;";
$Result = mysql_query ($strQuery,$dbh) or die ('Failed to fetch data because: ' . mysql_error());
print "<center><h1>Clearwire Detailed Power Usage report for $strLoc $dtSel</h1>";
print "<form method=\"GET\" action=\"$PageName\">";
print "Choose different time: <select size=\"1\" name=\"dt\">\n";
while ($Row = mysql_fetch_array($Result))
{
	if ($Row['dtMeasuredTime'] == $dtSel)
	{
		print "<option selected>$dtSel</option>\n";
	}
	else
	{
		print "<option>$Row[dtMeasuredTime]</option>\n";
	}
}
print "</select>\n";
$strQuery = "select distinct vcLocation from tbldevpower order by vcLocation;";
$Result = mysql_query ($strQuery,$dbh) or die ('Failed to fetch data because: ' . mysql_error());
print "  Site: <select size=\"1\" name=\"loc\">\n";
if ($strLoc == "")
{
	print "<option selected></option>\n";
}
else
{
	print "<option></option>\n";
}

while ($Row = mysql_fetch_array($Result))
{
	if ($Row['vcLocation'] == $strLoc)
	{
		print "<option selected>$strLoc</option>\n";
	}
	else
	{
		print "<option>$Row[vcLocation]</option>\n";
	}
}
print "</select>\n";
if ($strLoc == "")
{
	$strLoc = '%';
}
$strQuery = "select distinct vcDevName from tbldevpower order by vcDevName;";
$Result = mysql_query ($strQuery,$dbh) or die ('Failed to fetch data because: ' . mysql_error());
print "   Device Name: <select size=\"1\" name=\"dev\">\n";
if ($strDev == "")
{
	print "<option selected></option>\n";
}
else
{
	print"<option></option>\n";
}
while ($Row = mysql_fetch_array($Result))
{
	if ($Row['vcDevName'] == $strDev)
	{
		print "<option selected>$strDev</option>\n";
	}
	else
	{
		print "<option>$Row[vcDevName]</option>\n";
	}
}
print "</select>\n";
print "<input type=\"submit\" value=\"Update\" name=\"btnSubmit\">";
print "</form>";
if ($strDev == "")
{
	$strDev = '%';
}

$strQuery = "select vcDevName, vcIPAddr, vcSysName, vcOutletID, vcOutletName, vcOutletLoadStatus, fOutletLoadValue, btus from vwPowerBTU where dtMeasuredTime = '$dtSel' and vcLocation like '$strLoc' and vcDevName like '$strDev';";
$Result = mysql_query ($strQuery,$dbh) or die ('Failed to fetch data because: ' . mysql_error());
print "<table border=1 cellpadding=10>\n";
print "<tr><th>Device Name</th><th>IP Addrress</th><th>SysName</th><th>Outlet ID</th><th>Outlet Name</th><th>Status</th><th>Load</th><th>BTUs</th></tr></b>\n";
while ($Row = mysql_fetch_array($Result))
{
		$strDevice    = $Row['vcDevName'];
		$strIPAddr    = $Row['vcIPAddr'];
		$strSysName   = $Row['vcSysName'];
		$strOutletID  = $Row['vcOutletID'];
		$strOutlet    = $Row['vcOutletName'];
		$fLoad        = $Row['fOutletLoadValue'];
		$fBTUs        = $Row['BTUs'];
		$strLoadStat  = $Row['vcOutletLoadStatus'];
		print "<tr><td>$strDevice</td><td>$strIPAddr</td><td>$strSysName</td><td>$strOutletID</td><td>$strOutlet</td><td>$strLoadStat</td><td>$fLoad</td><td>$fBTUs</td></tr>\n";
}
print "</table></center>\n";
?>
</body>
</html>
