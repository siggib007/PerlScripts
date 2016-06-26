<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<title>Clearwire Summary Power Usage report</title>
</head>
<body>
<?php
$DetailPageName  = "powerdet.php";
$Target = "_Blank";
$PageName = $_SERVER["SCRIPT_NAME"];
$dtSel = $_GET["dt"];
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

print "<center><h1>Clearwire Summaery Power Usage report for $dtSel</h1>";
$strQuery = "select distinct dtMeasuredTime from tbldevpower order by dtMeasuredTime desc;";
$Result = mysql_query ($strQuery,$dbh) or die ('Failed to fetch data because: ' . mysql_error());
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
print "<input type=\"submit\" value=\"Update\" name=\"btnSubmit\">";
print "</form>";

$strQuery = "select vclocation, format(sum(fOutletLoadValue),1) Curload, format(sum(BTUs),1) BTUs from vwPowerBTU where dtMeasuredTime = '$dtSel' group by vclocation;";
$Result = mysql_query ($strQuery,$dbh) or die ('Failed to fetch data because: ' . mysql_error());
print "<table border=1 cellpadding=10>\n";
print "<tr><th>Location</th><th>Current Load</th><th>BTUs</th></tr>\n";
while ($Row = mysql_fetch_array($Result))
{
	$strLocation  = $Row['vclocation'];
	$fCurLoad     = $Row['Curload'];
	$fBTUs        = $Row['BTUs'];
	print "<tr><td><a href=\"$DetailPageName?dt=$dtSel&loc=$strLocation\" target=\"$Target\">$strLocation</a></td><td>$fCurLoad Amps</td><td>$fBTUs</td></tr>\n";
}
print "</table>\n</center>\n";
?>
</body>
</html>
