#!/usr/bin/perl
use strict;
###############################################################################################
# Cisco Routing table to mySQL DB                                                             #
# Author: Siggi Bjarnason                                                                     #
# Date Authored: 11/27/2012                                                                   #
# This script will read text file containing the output from show ip route on a cisco box     #
# and parse it into learned from protocol, subnet, next hop, then save to mySQL database.     #
###############################################################################################

# Start User configurable value variable section

my ($strSQL, $DBName, $DBHost, $DBUser, $DBpwd, $TblName, $InFileName);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$sec = substr("0$sec",-2);

$InFileName = "C:/Users/sbjarna/Documents/Projects/Dev/drcwsc21_RouteTable_11-16-2012-13-34.txt";
$DBHost = "localhost";
$DBName = "NetTools";
$TblName = "tblRoutes";
$DBUser = "PerlScript";
$DBpwd = "~AQwBFyIxO?D";


###############################################################################################
#End user configurable section.                                                               #
#Begin Script section. Do not modify below unless you know what you are doing.                #
###############################################################################################

use warnings;
use English;
use Sys::Hostname;
use DBI();

my ($progname, $ShortName, $scriptFullName, @tmp, $pathparts, $dbh, $host, $line, %RouteType);
my ($RType, $SubNet, $NextHop, $RTypeCode, $DevName, $cmdTime);

$host = hostname;
$scriptFullName = $PROGRAM_NAME;
$scriptFullName =~ s/\\/\//g;

@tmp = split(/\//,$scriptFullName);
$pathparts = scalar @tmp;
$ShortName = $tmp[$pathparts-1];
($progname) = split(/\./,$ShortName);

$RouteType{"C"} = "connected";
$RouteType{"S"} = "static";
$RouteType{"R"} = "RIP";
$RouteType{"B"} = "BGP";
$RouteType{"D"} = "EIGRP";
$RouteType{"EX"} = "EIGRP external";
$RouteType{"O"} = "OSPF";
$RouteType{"O IA"} = "OSPF inter area";
$RouteType{"O N1"} = "OSPF NSSA external type 1";
$RouteType{"O N2"} = "OSPF NSSA external type 2";
$RouteType{"O E1"} = "OSPF external type 1";
$RouteType{"O E2"} = "OSPF external type 2";
$RouteType{"E"} = "EGP";
$RouteType{"i"} = "ISIS";
$RouteType{"L1"} = "IS-IS level-1";
$RouteType{"L2"} = "IS-IS level-2";
$RouteType{"ia"} = "IS-IS inter area";
$RouteType{"su"} = "IS-IS summary null";
$RouteType{"U"} = "per-user static route";
$RouteType{"o"} = "ODR";
$RouteType{"L"} = "local";
$RouteType{"G "} = "DAGR";
$RouteType{"A"} = "access/subscriber";
$RouteType{"(!)"} = "FRR Backup path";

$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                      "$DBUser", "$DBpwd",
                      {'RaiseError' => 1});
$strSQL = "truncate table $TblName;";
$dbh->do($strSQL);

open(IN,"<",$InFileName) || die "cannot open File $InFileName for read: $!";

$line = <IN>;
chomp $line;
if ($line =~ /:(.*)#/)
{
	$DevName = $1;
}
#print "Device name is: $DevName\n";

$line = <IN>;
chomp $line;
$cmdTime = $line;
#print "Command was executed: $cmdTime\n";

$strSQL = "INSERT INTO tblLog(vcDeviceName, vcCmdTime)";
$strSQL .= "VALUES ('$DevName', '$cmdTime');";
$dbh->do($strSQL);

foreach $line (<IN>)
{
	chomp($line);
	if ($line =~ /(^.{4})\s*([1-9]\d{0,2}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}).* ([1-9]\d{0,2}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)
	{
		$RTypeCode = $1;
		$SubNet = $2;
		$NextHop = $3;
		$RTypeCode =~ s/\s+$//;
		$RType = $RouteType{"$RTypeCode"};
		#print "$RType - $SubNet - $NextHop\n";
		$strSQL = "INSERT INTO $TblName (vcProtoType, vcSubnet, vcNextHop)";
		$strSQL .= "VALUES ('$RType', '$SubNet', '$NextHop');";
		$dbh->do($strSQL);
	}
}
close IN;