$|=1;
#!/opt/perl5/bin/perl

#################################################################
# catInfo.pl                                                    #
# By: Otto J. Helweg II                                         #
#    Version: 11/27/2002										#
#    11/21/2003,wayney removed database poll                    #
#    Gathers Cat Port Info from a Database or SNMP              #
#    usage: perl catInfo.pl                                     #
#################################################################

use BER;
use SNMP_util;
use Win32::ODBC;
use ossgnet;

# Setup the program variables
$webDir   = "d:/inetpub/wwwroot";
$progDir   = "d:/inetpub/wwwroot/cgi-bin";
$logFile = "$progDir/logs/catInfo.log";
$tempFile = "$progDir/temp/catInfo.tmp";
$pageTitle = "Cat Information";
$action = "catinfo.pl";
$eventCount = 0;
# SNMP_util examples:
#   snmpget(community@host:port:timeout:retries:backoff, OID, [OID...])
#   snmpgetnext(community@host:port:timeout:retries:backoff, OID, [OID...])
#   snmpwalk(community@host:port:timeout:retries:backoff, OID)

snmpmapOID("ifDescr","1.3.6.1.2.1.2.2.1.2");
snmpmapOID("ifSpeed","1.3.6.1.2.1.2.2.1.5");
snmpmapOID("ifInOctets","1.3.6.1.2.1.2.2.1.10");
snmpmapOID("ifOperStatus","1.3.6.1.2.1.2.2.1.8");
snmpmapOID("ifName","1.3.6.1.2.1.31.1.1.1.1");
snmpmapOID("ifHCInOctets","1.3.6.1.2.1.31.1.1.1.6");
snmpmapOID("ifInErrors",".1.3.6.1.2.1.2.2.1.14");
snmpmapOID("ifInErrors",".1.3.6.1.2.1.2.2.1.20");
snmpmapOID("sysClearPortTime","1.3.6.1.4.1.9.5.1.1.13.0");
snmpmapOID("portName","1.3.6.1.4.1.9.5.1.4.1.1.4");
snmpmapOID("portType","1.3.6.1.4.1.9.5.1.4.1.1.5");
snmpmapOID("portOperStatus","1.3.6.1.4.1.9.5.1.4.1.1.6");
snmpmapOID("portAdminSpeed","1.3.6.1.4.1.9.5.1.4.1.1.9");
snmpmapOID("portDuplex","1.3.6.1.4.1.9.5.1.4.1.1.10");
snmpmapOID("portIfIndex","1.3.6.1.4.1.9.5.1.4.1.1.11");
snmpmapOID("vlanPortVlan","1.3.6.1.4.1.9.5.1.9.3.1.3");
snmpmapOID("vtpVlanName","1.3.6.1.4.1.9.9.46.1.3.1.1.4.1");

$ifOperStatusVal{"1"} = "up";
$ifOperStatusVal{"2"} = "down";
$ifOperStatusVal{"3"} = "testing";
$ifOperStatusVal{"4"} = "unknown";
$ifOperStatusVal{"5"} = "dormant";
$ifOperStatusVal{"6"} = "notPresent";
$ifOperStatusVal{"7"} = "lowerLayerDown";

$portDuplexVal{"1"} = "half";
$portDuplexVal{"2"} = "full";
$portDuplexVal{"3"} = "disagree";
$portDuplexVal{"4"} = "auto";

$portOperStatusVal{"1"} = "other";
$portOperStatusVal{"2"} = "ok";
$portOperStatusVal{"3"} = "minorFault";
$portOperStatusVal{"4"} = "majorFault";

$portTypeVal{"1"} = "other";
$portTypeVal{"2"} = "cddi";
$portTypeVal{"3"} = "fddi";
$portTypeVal{"4"} = "tppmd";
$portTypeVal{"5"} = "mlt3";
$portTypeVal{"6"} = "sddi";
$portTypeVal{"7"} = "smf";
$portTypeVal{"8"} = "e10BaseT";
$portTypeVal{"9"} = "e10BaseF";
$portTypeVal{"10"} = "scf";
$portTypeVal{"11"} = "e100BaseTX";
$portTypeVal{"12"} = "e100BaseT4";
$portTypeVal{"13"} = "e100BaseF";
$portTypeVal{"14"} = "atmOc3mmf";
$portTypeVal{"15"} = "atmOc3smf";
$portTypeVal{"16"} = "atmOc3utp";
$portTypeVal{"17"} = "e100BaseFsm";
$portTypeVal{"18"} = "e10a100BaseTX";
$portTypeVal{"19"} = "mii";
$portTypeVal{"20"} = "vlanRouter";
$portTypeVal{"21"} = "remoteRouter";
$portTypeVal{"22"} = "tokenring";
$portTypeVal{"23"} = "atmOc12mmf";
$portTypeVal{"24"} = "atmOc12smf";
$portTypeVal{"25"} = "atmDs3";
$portTypeVal{"26"} = "tokenringMmf";
$portTypeVal{"27"} = "e1000BaseLX";
$portTypeVal{"28"} = "e1000BaseSX";
$portTypeVal{"29"} = "e1000BaseCX";
$portTypeVal{"30"} = "networkAnalysis";
$portTypeVal{"31"} = "e1000Empty";
$portTypeVal{"32"} = "e1000BaseLH";
$portTypeVal{"33"} = "e1000BaseT";
$portTypeVal{"34"} = "e1000UnsupportedGbic";
$portTypeVal{"35"} = "e1000BaseZX";
$portTypeVal{"36"} = "depi2";
$portTypeVal{"37"} = "t1";
$portTypeVal{"38"} = "e1";
$portTypeVal{"39"} = "fxs";
$portTypeVal{"40"} = "fxo";
$portTypeVal{"41"} = "transcoding";
$portTypeVal{"42"} = "conferencing";

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mon++;
$year = $year + 1900;
$date = sprintf ("%02d%02d%04d",$mon,$mday,$year);
$dateTimeStamp = sprintf ("%02d/%02d/%04d %02d:%02d:%02d",$mon,$mday,$year,$hour,$min,$sec);

queryParse();
displayFormHead();

my $odbcDriver = Config_ODBC_DSN('msnov');

if (!($O = new Win32::ODBC($odbcDriver))){
	print 'Error: ODBC Open Failed: ',Win32::ODBC::Error(),"\n";
	#die logit("  Open NETDB: ".Win32::ODBC::Error(),$logFile);
	die sendSyslog("  Open NETDB: ".Win32::ODBC::Error()) && logit("  Open NETDB: ".Win32::ODBC::Error(),$logFile);
}

# Get All Cats

#$sqlQuery = "select a.*,b.snmpRO from staging..devices as a left outer join access..snmpAccess as b on a.dataCenter = b.dataCenter where a.deviceType = 'CiscoCatalyst' and a.status = 'active'";
#$sqlQuery = "select a.*,b.snmpRO from network..msndevices as a left outer join access..snmpDomains as b on a.dataCenter = b.dataCenter where a.deviceModel like '%Catalyst%' and a.status = 'active' and a.sysobjid not in ('1.3.6.1.4.1.9.1.310','1.3.6.1.4.1.9.1.400','1.3.6.1.4.1.9.1.258','1.3.6.1.4.1.9.1.301')";

#$sqlQuery = "select a.deviceName, a.deviceIPaddress, a.deviceModel, b.snmpRO 
#from network..msnDevices as a left outer join access..snmpDomains as b on a.snmpDomain = b.snmpDomain 
#where a.deviceModel like '%Catalyst%' and a.status = 'active' 
#and a.sysobjid not in ('1.3.6.1.4.1.9.1.310','1.3.6.1.4.1.9.1.400','1.3.6.1.4.1.9.1.258','1.3.6.1.4.1.9.1.301')";


$sqlQuery = "select a.*, b.snmpRO 
from network..msnDevices as a left outer join access..snmpDomains as b on a.snmpDomain = b.snmpDomain 
where a.deviceModel like '%Catalyst%' and a.status = 'active' 
and a.sysobjid not in ('1.3.6.1.4.1.9.1.310','1.3.6.1.4.1.9.1.400','1.3.6.1.4.1.9.1.258','1.3.6.1.4.1.9.1.301')";


if (! $O->Sql($sqlQuery)) {
	while($O->FetchRow()) {
		%sqlData = $O->DataHash();
		$deviceIPAddress{$sqlData{deviceName}} = $sqlData{deviceIPAddress};
		$deviceSNMP{$sqlData{deviceName}} = $sqlData{snmpRO};
		$deviceType{$sqlData{deviceName}} = $sqlData{deviceModel};
		$vsnmpDomain{$sqlData{deviceName}} = $sqlData{snmpDomain};
	}
} else {
	die logit("  Query agentIndex: ".Win32::ODBC::Error(),$logFile);
}

displayFormControl();

if ($ENV{"QUERY_STRING"} ne "") {
	# For Debugging
	#if (1 == 1) {
	#$lookup{radioInput} = "poll";
	#$lookup{catObject} = "iuscmsnbcc5001";
	if ($lookup{radioInput} eq "poll") {
		print "<I>Be patient, this may take a while.</I><BR>\n";
		$deviceName = $lookup{catObject};
		# For Debugging
		#if ($count > 0) {last()} else {$count++};
		#if ($deviceName !~ /iuscmscomc/) {next()};
		#if ($deviceName ne "iuscablanc5501") {next()};

		#print "Scanning $deviceName ($deviceIPAddress{$deviceName}):<BR>\n";

		# Clear variables
		$sysClearPortTime = "";
		undef %vtpVlanName;
		undef %portName;
		undef %portType;
		undef %portOperStatus;
		undef %portAdminSpeed;
		undef %portDuplex;
		undef %portIfIndex;
		undef %vlanPortVlan;
		undef %ifDescr;
		undef %ifSpeed;
		undef %ifInOctets;
		undef %ifOperStatus;

		if ($deviceType{$deviceName} =~ /catalyst/i) {
			print " >SNMPDomain:$vsnmpDomain{$deviceName}<BR>\n";
			print " >Getting sysClearPortTime<BR>\n";
			open(STDERR,">$tempFile");
			@result = snmpget("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",sysClearPortTime);
			close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			#if (grep(/SNMP\sError\:/,@tempFile)) {
			#	logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
			#	next();
			#}
			$sysClearPortTime = $result[0];
			#print "counterClear: $sysClearPortTime<BR>\n";
		}

		print " >Getting portName Table<BR>\n";
		open(STDERR,">$tempFile");
		@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",portName);
		close(STDERR);
		open(TEMPFILE,"$tempFilePortNameTable");
		@tempFile = <TEMPFILE>;
		close(TEMPFILE);
		if (grep(/SNMP\sError\:/,@tempFile)) {
			logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
			next();
		}
		foreach $result (@result) {
			($oid,$value) = split(/:/,$result,2);
			$portName{$oid} = $value;
			#print "oid:$oid\tvalue:$value<BR>\n";
		}

		print " >Getting ifOperStatus Table<BR>\n";
		open(STDERR,">$tempFile");
		@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",ifOperStatus);
		close(STDERR);
		open(TEMPFILE,"$tempFile");
		@tempFile = <TEMPFILE>;
		close(TEMPFILE);
		if (grep(/SNMP\sError\:/,@tempFile)) {
			logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
			next();
		}
		foreach $result (@result) {
			($oid,$value) = split(/:/,$result,2);
			if ($ifOperStatusVal{$value} ne "") {
				$ifOperStatus{$oid} = $ifOperStatusVal{$value};
			} else {
				$ifOperStatus{$oid} = $value;
			}
			#print "oid:$oid\tvalue:$value<BR>\n";
		}

		print " >Getting portIfIndex Table<BR>\n";
		open(STDERR,">$tempFile");
		@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",portIfIndex);
		close(STDERR);
		open(TEMPFILE,"$tempFile");
		@tempFile = <TEMPFILE>;
		close(TEMPFILE);
		if (grep(/SNMP\sError\:/,@tempFile)) {
			logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
			next();
		}
		foreach $result (@result) {
			($oid,$value) = split(/:/,$result,2);
			$portIfIndex{$oid} = $value;
			push(@portIfIndex,$oid);
			#print "oid:$oid\tvalue:$value<BR>\n";
		}

		if ($lookup{min} ne "on") {
			#print " >Getting portType Table<BR>\n";
			open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",portType);
			close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				if ($portTypeVal{$value} ne "") {
					$portType{$oid} = $portTypeVal{$value};
				} else {
					$portType{$oid} = $value;
				}
				#print "oid:$oid\tvalue:$value\n";
			}

			print " >Getting portDuplex Table<BR>\n";
			open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",portDuplex);
			close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				if ($portDuplexVal{$value} ne "") {
					$portDuplex{$oid} = $portDuplexVal{$value};
				} else {
					$portDuplex{$oid} = $value;
				}
				#print "oid:$oid\tvalue:$value<BR>\n";
			}

			print " >Getting vtpVlanName Table<BR>\n";
			open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",vtpVlanName);
			close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				$vtpVlanName{$oid} = $value;
				#print "oid:$oid\tvalue:$value<BR>\n";
			}

			print " >Getting vlanPortVlan Table<BR>\n";
			open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",vlanPortVlan);
			close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				$vlanPortVlan{$oid} = $value;
				#print "oid:$oid\tvalue:$value<BR>\n";
			}

			print " >Getting ifSpeed Table<BR>\n";
			open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",ifSpeed);
			close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				$ifSpeed{$oid} = $value / 1000000;
				#print "oid:$oid\tvalue:$value<BR>\n";
			}

			print " >Getting ifInOctets Table<BR>\n";
			#open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",ifInOctets);
			#close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				$ifInOctets{$oid} = $value;
				#print "oid:$oid\tvalue:$value<BR>\n";
			}

			print " >Getting ifHCInOctets Table<BR>\n";
			#open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:3:1",ifHCInOctets);
			#close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				$ifHCInOctets{$oid} = $value;
				$ifHCInOctets{$oid} =~ s/^\+//;
				#print "oid:$oid\tvalue:$value<BR>\n";
			}

			print " >Getting ifInErrors Table<BR>\n";
			#open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",ifInErrors);
			#close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				$ifInErrors{$oid} = $value;
				#print "oid:$oid\tvalue:$value<BR>\n";
			}

			print " >Getting ifOutErrors Table<BR>\n";
			#open(STDERR,">$tempFile");
			@result = snmpwalk("$deviceSNMP{$deviceName}\@$deviceIPAddress{$deviceName}:161:1:1",ifOutErrors);
			#close(STDERR);
			open(TEMPFILE,"$tempFile");
			@tempFile = <TEMPFILE>;
			close(TEMPFILE);
			if (grep(/SNMP\sError\:/,@tempFile)) {
				logit("  SNMP Error against $deviceName ($deviceIPAddress{$deviceName})",$logFile);
				next();
			}
			foreach $result (@result) {
				($oid,$value) = split(/:/,$result,2);
				$ifOutErrors{$oid} = $value;
				#print "oid:$oid\tvalue:$value<BR>\n";
			}
		}

		print "<TABLE CELLSPACING=2 CELLPADDING=0 style=\"font-family:Arial;font-size:8pt;\">\n";
		print "<TR BGCOLOR=DARKSLATEGRAY style=\"color:white;\"><TH COLSPAN=20>Result from Catalyst $deviceName<BR>(click on 'Port' link for a rate query)</TH></TR>\n";
		print "<TR BGCOLOR=DARKSLATEGRAY style=\"color:white;\"><TH COLSPAN=20>Last Counter Clear: $sysClearPortTime</TH></TR>\n";
		print "<TR BGCOLOR=GOLD>\n";
		if ($lookup{min} ne "on") {
			print "<TH>Port</TH>\n";
			print "<TH>VLAN Name(#)</TH>\n";
			print "<TH>Type</TH>\n";
			print "<TH>Speed</TH>\n";
			print "<TH>Duplex</TH>\n";
			print "<TH>Description</TH>\n";
			print "<TH>Out Errors</TH>\n";
			print "<TH>In Errors</TH>\n";
			print "<TH>In Octets (64)</TH>\n";
			print "<TH>In Octets (32)</TH>\n";
			print "<TH>Status</TH>\n";
		} else {
			print "<TH>Port</TH>\n";
			print "<TH>Description</TH>\n";
			print "<TH>Status</TH>\n";
		}
		print "</TR>\n";

		#foreach $portOID (sort(keys %portIfIndex)) {
		foreach $portOID (@portIfIndex) {
			$eventCount++;
			if ($bgColor eq "GAINSBORO") { $bgColor = "WHITESMOKE" } else { $bgColor = "GAINSBORO" };
			if ($ifOperStatus{$portIfIndex{$portOID}} eq "down") {
				$alarmColor = "ORANGERED";
			} else {
				$alarmColor = "LIME";
			}

			if ($portDuplex{$portOID} eq "half") {
				$duplexColor = "YELLOW";
			} else {
				$duplexColor = "LIME";
			}

			if ($ifInOctets{$portIfIndex{$portOID}} > 0) {
				if ($ifHCInOctets{$portIfIndex{$portOID}} > $ifInOctets{$portIfIndex{$portOID}}) {
					$ifErrorPercent = (100 * ($ifInErrors{$portIfIndex{$portOID}} / $ifHCInOctets{$portIfIndex{$portOID}}));
					$errorColor = colorLevel($ifErrorPercent,.01);
				} else {
					$ifErrorPercent = (100 * ($ifInErrors{$portIfIndex{$portOID}} / $ifInOctets{$portIfIndex{$portOID}}));
					$errorColor = colorLevel($ifErrorPercent,.01);
				}
			} else {
				if ($ifInErrors{$portIfIndex{$portOID}} > 0) {
					$errorColor = "FF0000";
				} else {
					$errorColor = "00FF00";
				}
			}

			$port = $portOID;
			$port =~ s/\./\//;
			$portName{$portOID} =~ s/\'//g;
			$ifInOctets{$portIfIndex{$portOID}} = commas($ifInOctets{$portIfIndex{$portOID}});
			$ifHCInOctets{$portIfIndex{$portOID}} = commas($ifHCInOctets{$portIfIndex{$portOID}});
			$ifInErrors{$portIfIndex{$portOID}} = commas($ifInErrors{$portIfIndex{$portOID}});
			$ifOutErrors{$portIfIndex{$portOID}} = commas($ifOutErrors{$portIfIndex{$portOID}});

			if ($lookup{min} ne "on") {
				print "<TR ALIGN=CENTER BGCOLOR=$bgColor>\n";
				print "<TD><a href=\"http://msnov/cgi-bin/catportinfoNew.pl?catObject=$deviceName&catPortName=$port&catPortIndex=$portIfIndex{$portOID}\" TARGET=\"_blank\"><B>$port</B></A></TD>\n";
				print "<TD><B>$vtpVlanName{$vlanPortVlan{$portOID}}</B>($vlanPortVlan{$portOID})</TD>\n";
				print "<TD>$portType{$portOID}</TD>\n";
				print "<TD>$ifSpeed{$portIfIndex{$portOID}}</TD>\n";
				print "<TD BGCOLOR=$duplexColor>$portDuplex{$portOID}</TD>\n";
				print "<TD ALIGN=LEFT><B>$portName{$portOID}</B></TD>\n";
				print "<TD ALIGN=RIGHT>$ifOutErrors{$portIfIndex{$portOID}}</TD>\n";
				print "<TD ALIGN=RIGHT BGCOLOR=$errorColor>$ifInErrors{$portIfIndex{$portOID}}</TD>\n";
				print "<TD ALIGN=RIGHT>$ifHCInOctets{$portIfIndex{$portOID}}</TD>\n";
				print "<TD ALIGN=RIGHT>$ifInOctets{$portIfIndex{$portOID}}</TD>\n";
				print "<TD BGCOLOR=$alarmColor>$ifOperStatus{$portIfIndex{$portOID}}</TD>\n";
				print "</TR>\n";
			} else {
				print "<TR ALIGN=CENTER BGCOLOR=$bgColor>\n";
				print "<TD><a href=\"http://msnov/cgi-bin/catportinfoNew.pl?catObject=$deviceName&catPortName=$port&catPortIndex=$portIfIndex{$portOID}\" TARGET=\"_blank\"><B>$port</B></A></TD>\n";
				print "<TD ALIGN=LEFT><B>$portName{$portOID}</B></TD>\n";
				print "<TD BGCOLOR=$alarmColor>$ifOperStatus{$portIfIndex{$portOID}}</TD>\n";
				print "</TR>\n";
			}
		}
		print "</TABLE><BR>\n";
		print "Note: Both 64 bit and 32 bit counters are displayed since some Cats don't support 64 bit counters. 32 bit counters will wrap every ~5 minutes on a 100Mb/s link.<BR>\n";
	} else {
		$deviceName = $lookup{catObject};
		#$sqlQuery = "select * from network..ports where devicename = '$deviceName'";
		#$sqlQuery = "select * from staging..ports where devicename = '$deviceName'";
        $sqlQuery = "select * from network..msnInterfaces where devicename = '$deviceName'";
		if (! $O->Sql($sqlQuery)) {
			while($O->FetchRow()) {
				%sqlData = $O->DataHash();
				if ($lookup{min} ne "on") {
					@queryKeys = (keys %sqlData);
				} else {
					@queryKeys = ("port","portName","portStatus");
				}
				foreach $key (keys %sqlData) {
					$$key{$sqlData{portInst}} = $sqlData{$key};
				}
			}
		} else {
			die logit("  Query agentIndex: ".Win32::ODBC::Error(),$logFile);
		}

		print "<TABLE CELLSPACING=2 CELLPADDING=0 style=\"font-family:Arial;font-size:8pt;\">\n";
		print "<TR BGCOLOR=DARKSLATEGRAY><TH COLSPAN=20 style=\"color:white;\">Result from Catalyst $deviceName</TH></TR>\n";
		print "<TR BGCOLOR=GOLD>\n";
		foreach $key (@queryKeys) {
			print "<TH>$key</TH>\n";
		}
		print "</TR>\n";

		foreach $key (sort {$a <=> $b}(keys %portInst)) {
			if ($bgColor eq "GAINSBORO") { $bgColor = "WHITESMOKE" } else { $bgColor = "GAINSBORO" };
			print "<TR BGCOLOR=$bgColor ALIGN=CENTER>\n";
			foreach $queryKey (@queryKeys) {
				if ($queryKey eq "portStatus") {
					if ($$queryKey{$key} eq "up") {
						$cellBgColor = "LIME";
					} else {
						$cellBgColor = "ORANGERED";
					}
				} else {
					$cellBgColor = $bgColor;
				}
				print "<TD BGCOLOR=$cellBgColor>$$queryKey{$key}</TD>\n";
			}
			print "</TR>\n";
		}
		print "</TABLE>\n";
	}
}

# Close up the Page
$O->Close();
$elapsed = (time() - $^T);
print "<P style=\"font-family:Arial;font-size:10pt\"><I>Elapsed Computational Time: $elapsed seconds</I></P>\n";
displayFormTail ();
logResult();

# Sub Routines ------------------------------------------------------

# insert commas into numeric string
sub commas {
    local($_) = @_;
    1 while s/(.*\d)(\d\d\d)/$1,$2/;
    $_;
}

sub displayFormHead {
	print "Content-type: text/html\n\n";
	print "<HTML>\n";
	print "<HEAD>\n";
	print "<TITLE>$pageTitle</TITLE>\n";
	print "<BODY topmargin=0 leftmargin=0 rightmargin=0>\n";

	open (HEADER,"$webDir/header/includes/toolbar.inc");
	while (<HEADER>) {
		print "$_";
	}
	close (HEADER);
}

sub displayFormControl {
	print "<TABLE style=\"font-family:Arial;\"><TR VALIGN=\"Top\">\n";
	print "<TD><TABLE BGCOLOR=\"WhiteSmoke\" CELLPADDING=\"0\" CELLSPACING=\"0\" WIDTH=\"175\" style=\"font-family:Arial;font-size:7pt;color:gray\">\n";
	print "<TR><TH BGCOLOR=\"DarkSlateGray\" style=\"font-size:12pt;color:white\"><B>&nbsp;&nbsp;Catalyst Info&nbsp;&nbsp;</B></TH></TR>\n";
	print "<TR><TH>Control</TH></TR>\n";
	print "<TR><TD BGCOLOR=\"LightGrey\"></TD></TR>\n";
	print "<TR><TD>Catalyst:</TD></TR>\n";
	print "<FORM METHOD=\"GET\" ACTION=\"catinfo.pl\">\n";
	print "<TR><TD ALIGN=\"Center\"><SELECT NAME=\"catObject\">\n";
	foreach $key (sort(keys %deviceIPAddress)) {
		if ($lookup{catObject} eq $key) {
			print "<OPTION SELECTED>$key";
		} else {
			print "<OPTION>$key";
		}
	}
	print "</SELECT>\n";
	print "</TD></TR>\n";
	print "<TR><TD>\n";
	if ($lookup{radioInput} eq "") {$lookup{radioInput} = "poll"};
	if ($lookup{radioInput} eq "poll") {
		print "<INPUT NAME=\"radioInput\" type=\"radio\" value=\"poll\" CHECKED> Active Poll<BR>\n";
	} else {
		print "<INPUT NAME=\"radioInput\" type=\"radio\" value=\"poll\"> Active Poll<BR>\n";
	}
	#if ($lookup{radioInput} eq "database") {
	#	print "<INPUT NAME=\"radioInput\" type=\"radio\" value=\"database\" CHECKED> Database<BR>\n";
	#} else {
	#	print "<INPUT NAME=\"radioInput\" type=\"radio\" value=\"database\"> Database<BR>\n";
	#}
	print "</TD></TR>\n";
	print "<TR><TD>\n";
	if ($lookup{min} eq "on" || $lookup{catObject} eq "") {
		print "<INPUT NAME=\"min\" type=\"checkbox\" CHECKED> Reduced Query\n";
	} else {
		print "<INPUT NAME=\"min\" type=\"checkbox\"> Reduced Query\n";
	}
	print "<TR><TD ALIGN=\"Center\"><INPUT TYPE=\"SUBMIT\" VALUE=\"Select\"></TD></TR>\n";
	print "</FORM>\n";
	print "<TR><TD BGCOLOR=\"LightGrey\"></TD></TR>\n";
	print "<TR><TH>Notes:</TH></TR>\n";
	print "<TR><TD BGCOLOR=\"LightGrey\"></TD></TR>\n";
	#print "<TR><TD>Not all Cats will respond to SNMP, we're working on this. Resort the the 'Database' query rather then the 'Active' query.</TD></TR>\n";
	print "<TR><TD>Uncheck \"Reduced Query\" to get error information for each port</TD></TR>";
	print "</TABLE></TD>\n";
	print "<TD>\n";
}

sub displayFormTail {
	print "</TD></TR></TABLE>\n";
	print "</BODY>\n";
	print "</HTML>\n";
}

#
# Log a time stamped message to the file $logfile
#
sub logit {
	my($text,$logFile,$nonlflag)=@_;
	my($timeStamp);
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	$mon++;
	$year += 1900;
	$timeStamp = sprintf ("%02d/%02d/%04d %02d:%02d:%02d ",$mon,$mday,$year,$hour,$min,$sec,$$);
	$logopen = open(LOG,">> $logFile");
	warn "Can't open log file: $!\n" if ! $logopen;
	my $oldfh=select LOG; $|=1; select $oldfh;
	print $timeStamp . $text;
	print ($nonlflag ? "" : "\n");
	return 1  if ! $logopen;
	print LOG $timeStamp . $text;
	print LOG ($nonlflag ? "" : "\n");
	close(LOG);
}

sub queryParse {
	# Begin parsing the QUERY_STRING from the form input...
	#   Expects something like;
	#     foo=www%21&bar=hello&baz=blah

	# Split the string into each of the key-value pairs
	(@fields) = split('&', $ENV{'QUERY_STRING'});

	# For each of these key-value pairs, decode the value
	for $field (@fields) {
		# Split the key-value pair on the equal sign.
		($name, $value) = split('=', $field);

		# Change all plus signs to spaces. This is an
		# remnant of ISINDEX
		$value =~ y/\+/ /;

		# Change all carrage-return/line feeds to spaces. This is an
		# remnant of ISINDEX?
		# $value =~ y/\%0D\%0A/ /;

		# Decode the value & removes % escapes.
		$value =~ s/%([\da-f]{1,2})/pack(C,hex($1))/eig;

		# Create the appropriate entry in the
		# associative array lookup
		if(defined $lookup{$name}) {
			# If there are multiple values, seperate
			# them by newlines
			$lookup{$name} .= "\n".$value;
		} else {
			$lookup{$name} = $value;
		}
	}
}

sub colorLevel {
	(my $value,my $alarmLevel) = @_;
	my $greenValue;
	my $redValue;
	my $resultColor;
	if ($alarmLevel <= 0) {
		$greenValue = "00";
		$redValue = "00";
	} elsif ($value <= ($alarmLevel/2)) {
		$greenValue = "ff";
		$redValue = sprintf ("%02x",(255 * ($value/($alarmLevel/2))));
	} elsif ($value <= $alarmLevel) {
		$redValue = "ff";
		$greenValue = sprintf ("%02x",(255 * ((($alarmLevel-$value)/($alarmLevel/2)))));
	} else {
		$redValue = "ff";
		$greenValue = "00";
	}
	$resultColor = sprintf ("%s%s00",$redValue,$greenValue);
	#if ($value == 0) {$resultColor = "GRAY"};
	return($resultColor);
}



sub logResult {
	my $loggingProgramName = "http://msnov/cgi-bin/$action.pl";
	my $loggingUserName = $ENV{AUTH_USER};
	$loggingUserName =~ tr/A-Z/a-z/;
	my $loggingParameters = $lookup{loadBalancer};

	my $loggingMachineName = Win32::NodeName();

	my $loggingRunTime = (time() - $^T);
	my $logInfo = $telnetEditLog;
	if ($eventCount > 0) {
		$loggingResult = "Success";
	} else {
		$eventCount = 0;
		$loggingResult = "Silent";
	}
	my $loggingResultInfo = "Returned $eventCount rows.";

	# Open the network database for read/write
	my $odbcDriver = Config_ODBC_DSN('msnov');
		
	if (!($Log = new Win32::ODBC($odbcDriver))){
		print 'Error: ODBC Open Failed: ',Win32::ODBC::Error(),"\n";
		die logit("  Open database: ".Win32::ODBC::Error(),$logFile);
	}

	$sqlQuery = "insert into reports..scriptResultLog (logTime,scriptURL,machineName,userName,result,runTime,parameters,resultInfo,logInfo)
		values (getdate(),'$loggingProgramName','$loggingMachineName','$loggingUserName',
		'$loggingResult','$loggingRunTime','$loggingParameters','$loggingResultInfo','$logInfo')";
	#print "$sqlQuery<BR>\n";
	if ($Log->Sql($sqlQuery)) {
		logit("  Insert record: $sqlQuery".Win32::ODBC::Error(),$logFile);
	}

	$Log->Close();
}
