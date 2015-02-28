use strict;
use net::SNMP;
use Win32::OLE 'in';
use Net::SMTP;
use English;
use Sys::Hostname;


my ($devicename, $comstr, $session, $error, $sysname, $ifTable, $result, %reshash, $key, $key2, $errmsg);
my ($StartTime, $isec, $imin, $len, $id, $type, $inst, %IntStat, %vmPortStatus, %vmVlanType, $iVlanID, $strErrCmd);
my ($CN, $RS, $SrcCmdText, $DBServer, $Cmd, $ComCmd, $Device, $StopTime, $ihour, $DevID, $iMTU, $strDescr);
my ($rem, $tail, $finst, %cdpcach, $cdpCacheEntry, %Int, $rdevice, %VlanMember, $strCmd, $strMACAddr, $scriptName);
my ($to, $from, $subject, @body, $relay, %IntType, %IntDescr, %IntIP, %IntMask, %VlanNames, %ArpTable, $progDir);
my ($sysname, $SysObjID, $SysLocation, $IPonInt, $IPmask, $locIfDescr, $arpPhysAddress, $ChassisSN, $IPAddr);
my ($ChassisModel, $VlanMembers, $VlanName, $strSysObjID, $strLocation, $strSerialNum, $strModel, $logfile);
my ($dot1dTpFdbAddress, $dot1dTpFdbPort, $dot1dBasePortIfIndex, %PortIfIndex, $scriptName, %FdbAddress, %FdbPort);


my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
($logfile) = split(/\./,$PROGRAM_NAME);
$logfile .= ".log";
print "Logging to $logfile\n";
open(OUT,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing....\n");

$DBServer = hostname();
$relay = "eagle.alaskaair.com";
$to = "siggi.bjarnason\@alaskaair.com";
$from = "siggi.bjarnason\@alaskaair.com";
$subject = "SNMP Inventory job outcome";
#$ComCmd = "select vcComRO from inventory.dbo.tblClass where iclassid = 3";
#$SrcCmdText = "select iDeviceID from inventory.dbo.tblDevices where vcdevicename = '$Device'";
$SrcCmdText = "select iDeviceID, vcDeviceName, vcComRO from inventory.dbo.vwActiveCisco order by dtLastPoll";

$sysname = '1.3.6.1.2.1.1.5.0';
$ifTable = '1.3.6.1.2.1.2.2.1';
$cdpCacheEntry = '1.3.6.1.4.1.9.9.23.1.2.1.1';
$SysObjID = '1.3.6.1.2.1.1.2.0';
$SysLocation = '1.3.6.1.2.1.1.6.0';
$arpPhysAddress = '1.3.6.1.2.1.4.22.1.2';
$IPonInt = '1.3.6.1.2.1.4.20.1.2';
$IPmask = '1.3.6.1.2.1.4.20.1.3';
$locIfDescr = '1.3.6.1.4.1.9.2.2.1.1.28';
$ChassisSN = '1.3.6.1.4.1.9.5.1.2.19.0';
$ChassisModel ='1.3.6.1.4.1.9.5.1.2.16.0';
$VlanMembers = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';
$VlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';
$dot1dTpFdbAddress = '1.3.6.1.2.1.17.4.3.1.1';
$dot1dTpFdbPort = '1.3.6.1.2.1.17.4.3.1.2';
$dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';

$IntStat{1} ='up';   
$IntStat{2} ='down';
$IntStat{3} ='testing';   
$IntStat{4} ='unknown';
$IntStat{5} ='dormant';
$IntStat{6} ='notPresent';
$IntStat{7} ='lowerLayerDown';

$IntType{1} = 'other';
$IntType{2} = 'regular1822';
$IntType{3} = 'hdh1822';
$IntType{4} = 'ddnX25';
$IntType{5} = 'rfc877x25';
$IntType{6} = 'ethernetCsmacd';
$IntType{7} = 'iso88023Csmacd';
$IntType{8} = 'iso88024TokenBus';
$IntType{9} = 'iso88025TokenRing';
$IntType{10} = 'iso88026Man';
$IntType{11} = 'starLan';
$IntType{12} = 'proteon10Mbit';
$IntType{13} = 'proteon80Mbit';
$IntType{14} = 'hyperchannel';
$IntType{15} = 'fddi';
$IntType{16} = 'lapb';
$IntType{17} = 'sdlc';
$IntType{18} = 'ds1';
$IntType{19} = 'e1';
$IntType{20} = 'basicISDN';
$IntType{21} = 'primaryISDN';
$IntType{22} = 'propPointToPointSerial';
$IntType{23} = 'ppp';
$IntType{24} = 'softwareLoopback';
$IntType{25} = 'eon';
$IntType{26} = 'ethernet3Mbit';
$IntType{27} = 'nsip';
$IntType{28} = 'slip';
$IntType{29} = 'ultra';
$IntType{30} = 'ds3';
$IntType{31} = 'sip';
$IntType{32} = 'frameRelay';
$IntType{33} = 'rs232';
$IntType{34} = 'para';
$IntType{35} = 'arcnet';
$IntType{36} = 'arcnetPlus';
$IntType{37} = 'atm';
$IntType{38} = 'miox25';
$IntType{39} = 'sonet';
$IntType{40} = 'x25ple';
$IntType{41} = 'iso88022llc';
$IntType{42} = 'localTalk';
$IntType{43} = 'smdsDxi';
$IntType{44} = 'frameRelayService';
$IntType{45} = 'v35';
$IntType{46} = 'hssi';
$IntType{47} = 'hippi';
$IntType{48} = 'modem';
$IntType{49} = 'aal5';
$IntType{50} = 'sonetPath';
$IntType{51} = 'sonetVT';
$IntType{52} = 'smdsIcip';
$IntType{53} = 'propVirtual';
$IntType{54} = 'propMultiplexor';
$IntType{55} = 'ieee80212';
$IntType{56} = 'fibreChannel';
$IntType{57} = 'hippiInterface';
$IntType{58} = 'frameRelayInterconnect';
$IntType{59} = 'aflane8023';
$IntType{60} = 'aflane8025';
$IntType{61} = 'cctEmul';
$IntType{62} = 'fastEther';
$IntType{63} = 'isdn';
$IntType{64} = 'v11';
$IntType{65} = 'v36';
$IntType{66} = 'g703at64k';
$IntType{67} = 'g703at2mb';
$IntType{68} = 'qllc';
$IntType{69} = 'fastEtherFX';
$IntType{70} = 'channel';
$IntType{71} = 'ieee80211';
$IntType{72} = 'ibm370parChan';
$IntType{73} = 'escon';
$IntType{74} = 'dlsw';
$IntType{75} = 'isdns';
$IntType{76} = 'isdnu';
$IntType{77} = 'lapd';
$IntType{78} = 'ipSwitch';
$IntType{79} = 'rsrb';
$IntType{80} = 'atmLogical';
$IntType{81} = 'ds0';
$IntType{82} = 'ds0Bundle';
$IntType{83} = 'bsc';
$IntType{84} = 'async';
$IntType{85} = 'cnr';
$IntType{86} = 'iso88025Dtr';
$IntType{87} = 'eplrs';
$IntType{88} = 'arap';
$IntType{89} = 'propCnls';
$IntType{90} = 'hostPad';
$IntType{91} = 'termPad';
$IntType{92} = 'frameRelayMPI';
$IntType{93} = 'x213';
$IntType{94} = 'adsl';
$IntType{95} = 'radsl';
$IntType{96} = 'sdsl';
$IntType{97} = 'vdsl';
$IntType{98} = 'iso88025CRFPInt';
$IntType{99} = 'myrinet';
$IntType{100} = 'voiceEM';
$IntType{101} = 'voiceFXO';
$IntType{102} = 'voiceFXS';
$IntType{103} = 'voiceEncap';
$IntType{104} = 'voiceOverIp';
$IntType{105} = 'atmDxi';
$IntType{106} = 'atmFuni';
$IntType{107} = 'atmIma';
$IntType{108} = 'pppMultilinkBundle';
$IntType{109} = 'ipOverCdlc';
$IntType{110} = 'ipOverClaw';
$IntType{111} = 'stackToStack';
$IntType{112} = 'virtualIpAddress';
$IntType{113} = 'mpc';
$IntType{114} = 'ipOverAtm';
$IntType{115} = 'iso88025Fiber';
$IntType{116} = 'tdlc';
$IntType{117} = 'gigabitEthernet';
$IntType{118} = 'hdlc';
$IntType{119} = 'lapf';
$IntType{120} = 'v37';
$IntType{121} = 'x25mlp';
$IntType{122} = 'x25huntGroup';
$IntType{123} = 'trasnpHdlc';
$IntType{124} = 'interleave';
$IntType{125} = 'fast';
$IntType{126} = 'ip';
$IntType{127} = 'docsCableMaclayer';
$IntType{128} = 'docsCableDownstream';
$IntType{129} = 'docsCableUpstream';
$IntType{130} = 'a12MppSwitch';
$IntType{131} = 'tunnel';
$IntType{132} = 'coffee';
$IntType{133} = 'ces';
$IntType{134} = 'atmSubInterface';
$IntType{135} = 'l2vlan';
$IntType{136} = 'l3ipvlan';
$IntType{137} = 'l3ipxvlan';
$IntType{138} = 'digitalPowerline';
$IntType{139} = 'mediaMailOverIp';
$IntType{140} = 'dtm';
$IntType{141} = 'dcn';
$IntType{142} = 'ipForward';
$IntType{143} = 'msdsl';
$IntType{144} = 'ieee1394';
$IntType{145} = 'if-gsn';
$IntType{146} = 'dvbRccMacLayer';
$IntType{147} = 'dvbRccDownstream';
$IntType{148} = 'dvbRccUpstream';
$IntType{149} = 'atmVirtual';
$IntType{150} = 'mplsTunnel';
$IntType{151} = 'srp';
$IntType{152} = 'voiceOverAtm';
$IntType{153} = 'voiceOverFrameRelay';
$IntType{154} = 'idsl';
$IntType{155} = 'compositeLink';
$IntType{156} = 'ss7SigLink';
$IntType{157} = 'propWirelessP2P';
$IntType{158} = 'frForward';
$IntType{159} = 'rfc1483';
$IntType{160} = 'usb';
$IntType{161} = 'ieee8023adLag';
$IntType{162} = 'bgppolicyaccounting';
$IntType{163} = 'frf16MfrBundle';
$IntType{164} = 'h323Gatekeeper';
$IntType{165} = 'h323Proxy';
$IntType{166} = 'mpls';
$IntType{167} = 'mfSigLink';
$IntType{168} = 'hdsl2';
$IntType{169} = 'shdsl';
$IntType{170} = 'ds1FDL';
$IntType{171} = 'pos';
$IntType{172} = 'dvbAsiIn';
$IntType{173} = 'dvbAsiOut';
$IntType{174} = 'plc';
$IntType{175} = 'nfas';
$IntType{176} = 'tr008';
$IntType{177} = 'gr303RDT';
$IntType{178} = 'gr303IDT';
$IntType{179} = 'isup';
$IntType{180} = 'propDocsWirelessMaclayer';
$IntType{181} = 'propDocsWirelessDownstream';
$IntType{182} = 'propDocsWirelessUpstream';
$IntType{183} = 'hiperlan2';
$IntType{184} = 'propBWAp2Mp';
$IntType{185} = 'sonetOverheadChannel';
$IntType{186} = 'digitalWrapperOverheadChannel';
$IntType{187} = 'aal2';
$IntType{188} = 'radioMAC';
$IntType{189} = 'atmRadio';
$IntType{190} = 'imt';
$IntType{191} = 'mvl';
$IntType{192} = 'reachDSL';
$IntType{193} = 'frDlciEndPt';
$IntType{194} = 'atmVciEndPt';
$IntType{195} = 'opticalChannel';
$IntType{196} = 'opticalTransport';
$IntType{197} = 'propAtm';
$IntType{198} = 'voiceOverCable';
$IntType{199} = 'infiniband';
$IntType{200} = 'teLink';
$IntType{201} = 'q2931';
$IntType{202} = 'virtualTg';
$IntType{203} = 'sipTg';
$IntType{204} = 'sipSig';
$IntType{205} = 'docsCableUpstreamChannel';
$IntType{206} = 'econet';
$IntType{207} = 'pon155';
$IntType{208} = 'pon622';
$IntType{209} = 'bridge';
$IntType{210} = 'linegroup';
$IntType{211} = 'voiceEMFGD';
$IntType{212} = 'voiceFGDEANA';
$IntType{213} = 'voiceDID';
$IntType{214} = 'mpegTransport';
$IntType{215} = 'sixToFour';
$IntType{216} = 'gtp';
$IntType{217} = 'pdnEtherLoop1';
$IntType{218} = 'pdnEtherLoop2';
$IntType{219} = 'opticalChannelGroup';
$IntType{220} = 'homepna';
$IntType{221} = 'gfp';
$IntType{222} = 'ciscoISLvlan';
$IntType{223} = 'actelisMetaLOOP';
$IntType{224} = 'fcipLink';
$IntType{225} = 'rpr';
$IntType{226} = 'qam';
$IntType{227} = 'lmp';
$IntType{228} = 'cblVectaStar';
$IntType{229} = 'docsCableMCmtsDownstream';
$IntType{230} = 'adsl2';
$IntType{231} = 'macSecControlledIF';
$IntType{232} = 'macSecUncontrolledIF';
$IntType{233} = 'aviciOpticalEther';
$IntType{234} = 'atmbond';
$IntType{235} = 'voiceFGDOS';
$IntType{236} = 'mocaVersion1';
$IntType{237} = 'ieee80216WMAN';
$IntType{238} = 'adsl2plus';
$IntType{239} = 'dvbRcsMacLayer';
$IntType{240} = 'dvbTdm';
$IntType{241} = 'dvbRcsTdma';


$StartTime = time;

logentry ("Started processing at $mon/$mday/$year $hour:$min\n") ;

$CN = new Win32::OLE "ADODB.Connection";
if (!defined($CN) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create conenction object\n".Win32::OLE->LastError(),1);}

$RS = new Win32::OLE "ADODB.Recordset";
if (!defined($RS) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create source recordset object\n".Win32::OLE->LastError(),1);}

$Cmd = new Win32::OLE "ADODB.Command";
if (!defined($Cmd) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a command object\n".Win32::OLE->LastError(),1);}

$CN->{Provider} = "sqloledb";
$CN->{Properties}{"Data Source"}->{value} = $DBServer;
$CN->{Properties}{"Integrated Security"}->{value} = "SSPI";

logentry ("Attempting to open Connection to $DBServer\n");
$CN->open; 
if (Win32::OLE->LastError() != 0 ) { cleanup("cannot open source database connection\n".Win32::OLE->LastError(),1);}

$Cmd->{ActiveConnection} = $CN;

#logentry ("fetching com string\n");
#$RS->Open ($ComCmd, $CN);
#if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch comstr\n".Win32::OLE->LastError(),1);}

#$comstr = $RS->{fields}{vcComRO}->{value};
#$RS->Close;
#logentry ("Device: $Device\n");
$RS->{LockType} = 1; #adLockReadOnly; 3; #adLockOptimistic
$RS->{CursorLocation} = 3; #adUseClient
$RS->Open ($SrcCmdText, $CN);
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch Device Data list\n".Win32::OLE->LastError(),1);}
while ( !$RS->EOF )
{
	$DevID = $RS->{fields}{iDeviceID}->{value};
	$comstr = $RS->{fields}{vcComRO}->{value};
	$Device = $RS->{fields}{vcDeviceName}->{value};
	if ($DevID eq '') {cleanup("Failed to fetch DevID, came up blank\n",1);}
	if ($comstr eq '') {cleanup("Failed to fetch comstr, came up blank\n",1);}
	#if ($Device eq '') {cleanup("Failed to fetch Device name, came up blank\n",1);}
	logentry ("starting to process ID $DevID, name $Device\n");
	$strCmd  = "update inventory.dbo.tbldevices set dtLastPollAttempt = getdate() where ideviceid = $DevID";
	$Cmd->{CommandText} = $strCmd;
	$Cmd->{Execute};
	if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
	logentry("Successfully updated Database with poll attempt.\n");
	
	($session,$error) = Net::SNMP->session(hostname => $Device, community => $comstr);
	if (!defined($session)) 
	{
		logentry ("Connect Error: $error.\n");
	}
	else	
	{
		#$strCmd = "update inventory.dbo.tbldevices set ";
		$strCmd = "";
		$result = $session->get_request($sysname);
		$errmsg = "";
		if (!defined($result)) 
		{
			$errmsg = $session->error;
			logentry ("Sysname ERROR: $errmsg.\n");
			$devicename = "";
			logerrdb($DevID, "Sysname",-1, $errmsg);
		}
		else
		{
			$devicename = substr($result->{$sysname},0,50);
			logentry ("Sysname: $devicename\n");
			$strCmd .= "vcSysName = '$devicename', ";
		
			$result = $session->get_request($SysObjID);
			$errmsg = "";
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("SysObjID ERROR: $errmsg.\n");
				$strSysObjID = "";
				logerrdb($DevID, "SysObjID", -1,$errmsg);
			}
			else
			{
				$strSysObjID = substr($result->{$SysObjID},0,50);
				logentry ("SysObjID: $strSysObjID\n");
				$strCmd .= "vcSysObjID = '$strSysObjID', ";
			}
	    	
			$result = $session->get_request($SysLocation );
			$errmsg = "";
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("SysLocation  ERROR: $errmsg.\n");
				$strLocation  = "";
				logerrdb($DevID, "SysLocation",-1, $errmsg);
			}
			else
			{
				$strLocation = substr($result->{$SysLocation},0,200);
				$strLocation =~ s/\'//g;
				$strLocation =~ s/\0//g;	
				logentry ("Location: $strLocation\n");
				$strCmd .= "vcSysLocation = '$strLocation', ";
			}
			
			$result = $session->get_request($ChassisSN );
			$errmsg = "";
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("ChassisSN  ERROR: $errmsg.\n");
				$strSerialNum  = "";
				logerrdb($DevID, "ChassisSN", -1,$errmsg);
			}
			else
			{
				$strSerialNum = substr($result->{$ChassisSN},0,50);
				logentry ("SN: $strSerialNum\n");
				$strCmd .= "vcSerialNum = '$strSerialNum', ";
			}
			
			$result = $session->get_request($ChassisModel );
			$errmsg = "";
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("ChassisModel  ERROR: $errmsg.\n");
				$strModel  = "";
				logerrdb($DevID, "ChassisModel",-1, $errmsg);
			}
			else
			{
				$strModel = substr($result->{$ChassisModel},0,50);
				logentry ("Model: $strModel\n");
				$strCmd .= "vcChassisModel = '$strModel', ";
			}
	    	
	   		if ($strCmd ne '')
	   		{
				$strCmd = "update inventory.dbo.tbldevices set $strCmd dtLastUpdated = getdate(), vcLastUpdatedBy = '$scriptName', dtlastpoll = getdate() where ideviceid = $DevID ";
				#logentry("Updating database\n$strCmd\n");
				$Cmd->{CommandText} = $strCmd;
				$Cmd->{Execute};
				if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
				logentry("Successfully updated Devicetable.\n");
			}
			
			logentry("Fetching ifTable\n");
			$result = $session->get_table($ifTable);
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("If Table ERROR: $errmsg.\n");
				logerrdb($DevID, "IfTable", -1,$errmsg);
			}
			else
			{
				%reshash = %$result;			
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($ifTable);
					($type,$id) = split(/\./,substr($key,$len+1));
					$Int{$id}{$type} = $reshash{$key};
					#logentry ("$id\t$reshash{$key}\n");
				}
			}
	    	
			logentry("Fetching Descriptions\n");
			$result = $session->get_table($locIfDescr);
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("IntDesc ERROR: $errmsg.\n");
				logerrdb($DevID, "IntDesc",-1, $errmsg);
			}
			else
			{
				%reshash = %$result;			
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($locIfDescr);
					$id = substr($key,$len+1);
					$IntDescr{$id} = $reshash{$key};
					#logentry ("$id\t$reshash{$key}\n");
				}
			}
	    	
			logentry("Fetching IP's\n");
	    	
			$result = $session->get_table($IPonInt);
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("IntIP ERROR: $errmsg.\n");
				logerrdb($DevID, "IntIP",-1, $errmsg);
			}
			else
			{
				%reshash = %$result;			
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($IPonInt);
					$id = substr($key,$len+1);
					$IntIP{$id} = $reshash{$key};
					#logentry ("$id\t$reshash{$key}\n");
				}
			}
	    	
			logentry("Fetching Masks\n");
	    	
			$result = $session->get_table($IPmask);
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("Int mask ERROR: $errmsg.\n");
				logerrdb($DevID, "Int mask",-1, $errmsg);
			}
			else
			{
				%reshash = %$result;			
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($IPmask);
					$id = substr($key,$len+1);
					$IntMask{$id} = $reshash{$key};
					#logentry ("$id\t$reshash{$key}\n");
				}
			}
			$strCmd = "delete from inventory.dbo.tblInterfaceIP where iDeviceID = $DevID";
			$Cmd->{CommandText} = $strCmd;
			$Cmd->{Execute};
			if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to delete old IntIP info using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
			#logentry ("IP address, mask, Interface\n");
			foreach $key(sort(keys %IntIP))
			{
				#logentry ("$key, $IntMask{$key}, $Int{$IntIP{$key}}{'2'}\n");
				$strCmd  = "insert into inventory.dbo.tblInterfaceIP (iDeviceID,iSNMPInstance,vcIPAddress,vcMask) values ";
				$strCmd .= "($DevID,$IntIP{$key},'$key','$IntMask{$key}')";
				#logentry("Updating database\n$strCmd\n");
				$Cmd->{CommandText} = $strCmd;
				$Cmd->{Execute};
				if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
				#logentry("Successfully saved Int IP info to Database.\n");
				
			}
	    	
			logentry("Fetching vlan names\n");
			$result = $session->get_table($VlanName );
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("vlan name ERROR: $errmsg.\n");
				logerrdb($DevID, "vlan name", -1, $errmsg);
			}
			else
			{
				%reshash = %$result;	
				$strCmd = "delete from inventory.dbo.tblVlanNames where iDeviceID = $DevID";
				$Cmd->{CommandText} = $strCmd;
				$Cmd->{Execute};
				if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to delete old vlan info using:\n$strCmd\n".Win32::OLE->LastError(),1);}		
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($VlanName );
					$id = substr($key,$len+1);
					$VlanNames{$id} = $reshash{$key};
					#logentry ("$id\t$reshash{$key}\n");	
					$strCmd  = "insert into inventory.dbo.tblVlanNames (iDeviceID,iVlanID,vcVlanName) values ";
					$strCmd .= "($DevID,$id,'$reshash{$key}')";
					#logentry("Updating database\n$strCmd\n");
					$Cmd->{CommandText} = $strCmd;
					$Cmd->{Execute};
					if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
					#logentry("Successfully saved Vlan names info to Database.\n");		
				}
			}
			
			logentry("Fetching vlan memberships\n");
			$result = $session->get_table($VlanMembers );
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("vlan member ERROR: $errmsg.\n");
				logerrdb($DevID, "vlan member",-1, $errmsg);
			}
			else
			{
				%reshash = %$result;			
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($VlanMembers );
					$id = substr($key,$len+1);
					$VlanMember{$id} = $reshash{$key};
					#logentry ("$id\t$reshash{$key}\n");
				}
			}
	    	
			$strCmd = "delete from inventory.dbo.tblInterfaces where iDeviceID = $DevID";
			$Cmd->{CommandText} = $strCmd;
			$Cmd->{Execute};
			if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to delete old vlan info using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
	    	
			#logentry ("Inst,Interface,Type,MTU,Speed,MAC,Admin,Oper\n   Description, Vlan Name\n");
			logentry ("Writing interface info to DB\n");
			foreach $key(sort(keys %Int))
			{
				$iMTU = int($Int{$key}{'4'});
				$strMACAddr = substr($Int{$key}{'6'},2);
				$strMACAddr =~ s/\0//g;		
				$strMACAddr =~ s/,//g;
				$strMACAddr =~ s/!//g;
				$strMACAddr =~ s/\$//g;
				$strMACAddr =~ s/\^//g;
				#if (ord(substr($strMACAddr,2,1)) == 0 )
				#{
				#	$strMACAddr = '';
				#}
				#else
				#{
				#	$strMACAddr = substr($Int{$key}{'6'},2);
				#}
	    	
				#logentry ("MAC:*$Int{$key}{'6'}*\n+$strMACAddr+\n");
				#$strMACAddr = '';
				$strDescr = $IntDescr{$key};
				$strDescr =~ s/\0//g;
				$strDescr =~ s/\'//g;
				if ($VlanMember{$key} eq '')#($VlanMember{$key} =~ /^(\d+\.?\d*|\.\d+)$/)
				{
					#logentry ("vlan id is null\n");
					$iVlanID = "Null";
				}
				else
				{
					#logentry ("vlan id is not empty\n");
					$iVlanID = $VlanMember{$key};
				}
				#logentry ("$key, $Int{$key}{'2'}, $IntType{$Int{$key}{'3'}}, $iMTU, $Int{$key}{'5'}, $Int{$key}{'6'}, $IntStat{$Int{$key}{'7'}}, $IntStat{$Int{$key}{'8'}}\n");
				#logentry ("   $IntDescr{$key}, $VlanNames{$VlanMember{$key}}, *$iVlanID*\n");
				$strCmd  = "insert into inventory.dbo.tblInterfaces (iDeviceID,iSNMPInstance,vcInterfaceName,vcInterfacetype,iMTU,iMaxSpeed,vcMACAddr,vcAdminStatus,vcOperStatus,vcDescription,iVlanMember) values ";
				$strCmd .= "($DevID,$key,'$Int{$key}{'2'}','$IntType{$Int{$key}{'3'}}', $iMTU,$Int{$key}{'5'},'$strMACAddr','$IntStat{$Int{$key}{'7'}}','$IntStat{$Int{$key}{'8'}}', '$strDescr', $iVlanID)";
				#logentry("Updating database\n$strCmd\n");
				$Cmd->{CommandText} = $strCmd;
				$Cmd->{Execute};
				if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
				#logentry("Successfully saved interface info to Database.\n");
				
			}
	    	
	    	
			logentry ("fetching arp table\n");
			$result = $session->get_table($arpPhysAddress );
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("Arp Table ERROR: $errmsg.\n");
				logerrdb($DevID, "Arp Table",-1, $errmsg);
			}
			else
			{
				$strCmd = "delete from inventory.dbo.tblArp where iDeviceID = $DevID";
				$Cmd->{CommandText} = $strCmd;
				$Cmd->{Execute};
				if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to delete old IntIP info using:\n$strCmd\n".Win32::OLE->LastError(),1);}
				%reshash = %$result;			
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($arpPhysAddress );
					$id = substr($key,$len+1);
					$inst = substr($id,0,index($id,'.'));
					$rem = substr($id,index($id,'.')+1);
					$ArpTable{$id} = $reshash{$key};
					$strMACAddr = substr($reshash{$key},2);
					$strMACAddr =~ s/\'//g;
					$strMACAddr =~ s/\0//g;
					$strMACAddr =~ s/,//g;
					$strMACAddr =~ s/!//g;
					$strMACAddr =~ s/\$//g;
					$strMACAddr =~ s/\^//g;
					#logentry ("$Int{$inst}{'2'}\t$rem\t$reshash{$key}\n");
					#logentry ("$inst\t$rem\t$strMACAddr\n");
					$strCmd  = "insert into inventory.dbo.tblArp (iDeviceID,iSNMPInstance,vcIPAddress,vcMac) values ";
					$strCmd .= "($DevID,$inst,'$rem','$strMACAddr')";
					#logentry("Updating database\n$strCmd\n");
					$Cmd->{CommandText} = $strCmd;
					$Cmd->{Execute};
					if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}						
				}
			}
			
			logentry ("fetching PortIFIndex\n");
			$result = $session->get_table($dot1dBasePortIfIndex );
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("dot1dBasePortIfIndex Table ERROR: $errmsg.\n");
				logerrdb($DevID, "dot1dBasePortIfIndex",-1, $errmsg);
			}
			else
			{
				%reshash = %$result;			
				foreach $key(sort(keys %reshash)) 
				{ 
					$len = length($dot1dBasePortIfIndex );
					$id = substr($key,$len+1);
					$PortIfIndex{$id} = $reshash{$key};
					#logentry ("$id\t$reshash{$key}\n");
				}
			}
	    	
	    	
			$result = $session->get_table($cdpCacheEntry);
			if (!defined($result)) 
			{
				$errmsg = $session->error;
				logentry ("CDP ERROR: $errmsg.\n");
				logerrdb($DevID, "CDP",-1, $errmsg);
			}
			else
			{
				%reshash = %$result;
				foreach $key(sort(keys %reshash)) 
				{ 
					if ($reshash{$key} ne '')
					{
						$len = length($cdpCacheEntry);
						$tail = substr($key,$len+1);
						($type,$rem,$inst) = split(/\./,$tail);
						$finst = join('.',$rem,$inst);
						$cdpcach{$finst}{$type} = $reshash{$key}
					}
				}
				#logentry  "Local Interface\tRemote Device\tRemoteIP\tRemoteModel\tRemoteOS\tRemoteInt\n";
				$strCmd = "delete from inventory.dbo.tblCDP where iDeviceID = $DevID";
				$Cmd->{CommandText} = $strCmd;
				$Cmd->{Execute};
				if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to delete old IntIP info using:\n$strCmd\n".Win32::OLE->LastError(),1);}		
				#logentry ("Local Interface\tRemote Device\tRemoteIP\tRemoteModel\tRemoteInt\n");
				foreach $key(sort(keys %cdpcach))
				{
					($rem,$inst) = split(/\./,$key);
					$cdpcach{$key}{'5'} =~ s/\n/ /g;
					$IPAddr = $cdpcach{$key}{'4'};
					$IPAddr = hex(substr($IPAddr,2,2)) . '.' . hex(substr($IPAddr,4,2)) . '.' . hex(substr($IPAddr,6,2)) . '.' . hex(substr($IPAddr,8,2));
					$rdevice = $cdpcach{$key}{'6'};
					#logentry ("Found remote device $rdevice with IP $IPAddr\n");
					$rdevice = substr($rdevice,index($rdevice,"(")+1);
					$rdevice =~ s/\)//g;
					$rdevice =~ s/\(//g;
					$rdevice =~ s/\0//g;
					#logentry ("part clean name: $rdevice;\n");
					($rdevice) = split (/\./,$rdevice);
					#logentry ("Clean remote device name $rdevice\n");
					$rdevice = substr($rdevice,0,49);
					#logentry ("Clean and short remote device name $rdevice\n");
					#logentry ("$Int{$rem}\t$rdevice\t$cdpcach{$key}{'4'}\t$cdpcach{$key}{'8'}\t$cdpcach{$key}{'5'}\t$cdpcach{$key}{'7'}\n");
					#logentry ("$Int{$rem}{'2'}\t$rdevice\t$cdpcach{$key}{'4'}\t$cdpcach{$key}{'8'}\t$cdpcach{$key}{'7'}\n");
					#logentry("$rem\t$rdevice\t$IPAddr\t$cdpcach{$key}{'8'}\t$cdpcach{$key}{'7'}\n");
					$strCmd  = "insert into inventory.dbo.tblCDP (iDeviceID,iSNMPInstance, vcRemoteDevice, vcRemoteIP, vcRemoteModel, vcRemoteInt, vcRemoteOSVer) values ";
					$strCmd .= "($DevID,$rem,'$rdevice','$IPAddr','$cdpcach{$key}{'8'}','$cdpcach{$key}{'7'}','$cdpcach{$key}{'5'}')";
					#logentry("Updating database\n$strCmd\n");
					$Cmd->{CommandText} = $strCmd;
					$Cmd->{Execute};
					if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}						
					
				}
			}
			$strCmd = "delete from inventory.dbo.tblCAM where iDeviceID = $DevID";
			$Cmd->{CommandText} = $strCmd;
			$Cmd->{Execute};
			if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to delete old vlan info using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
			
			logentry ("now dumping CAM table by vlan\n");
			foreach $key2(sort(keys %VlanNames)) 
			{ 
				if ($key2 < 1000)
				{
					logentry ("Fetching CAM Table for Vlan $key2  $VlanNames{$key2}\n");
					undef(%FdbAddress);
					undef(%FdbPort);
					($session,$error) = Net::SNMP->session(hostname => $Device, community => "$comstr\@$key2");
					if (!defined($session)) 
					{
						logentry ("Connect Error: $error.\n");
						logerrdb($DevID, "Connect failed", $key2, $error);
					}
					else
					{
						$result = $session->get_table($dot1dTpFdbAddress);
						$error = $session->error;
						if (!defined($result)) 
						{
							logentry ("dot1dTpFdbAddress ERROR: $error.\n");
							logerrdb($DevID, "dot1dTpFdbAddress",$key2, $error);
							
						}
						else
						{
							%reshash = %$result;			
							foreach $key(sort(keys %reshash)) 
							{ 
								$len = length($dot1dTpFdbAddress );
								$id = substr($key,$len+1);
								$FdbAddress{$id} = $reshash{$key};
								#logentry ("$id\t$reshash{$key}\n");
							}
						}
						$result = $session->get_table($dot1dTpFdbPort);
						if (!defined($result)) 
						{
							logentry ("dot1dTpFdbPort ERROR: $error.\n");
							logerrdb($DevID, "dot1dTpFdbPort",$key2, $error);
						}
						else
						{
							%reshash = %$result;			
							foreach $key(sort(keys %reshash)) 
							{ 
								$len = length($dot1dTpFdbPort );
								$id = substr($key,$len+1);
								$FdbPort{$id} = $reshash{$key};
								#logentry ("$id\t$reshash{$key}\n");			
							}
						}	
					}
					#logentry ("CAM Table for Vlan $key2  $VlanNames{$key2}\n");
					foreach $id(sort(keys %FdbAddress))
					{
						$strMACAddr = substr($FdbAddress{$id},2);
						$strMACAddr =~ s/\'//g;
						$strMACAddr =~ s/\0//g;	
						$strMACAddr =~ s/,//g;
						$strMACAddr =~ s/!//g;
						$strMACAddr =~ s/\$//g;
						$strMACAddr =~ s/\^//g;
						#logentry ("vlan:$key2  Mac:$FdbAddress{$id}  Int:$Int{$PortIfIndex{$FdbPort{$id}}}{'2'}  Inst:$PortIfIndex{$FdbPort{$id}}  FdbPort:$FdbPort{$id};\n");
						#logentry ("vlan:$key2  Mac:$strMACAddr  Inst:$PortIfIndex{$FdbPort{$id}}\n");
						$strCmd  = "insert into inventory.dbo.tblCAM (iDeviceID,iVlanID,vcMac,iSNMPInstance) values ";
						$strCmd .= "($DevID,$key2,'$strMACAddr','$PortIfIndex{$FdbPort{$id}}')";
						#logentry("Updating database\n$strCmd\n");
						$Cmd->{CommandText} = $strCmd;
						$Cmd->{Execute};
						if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}
					}
				}
			}
		}
	}			
	$RS->MoveNext;
}
cleanup('Done!',0);

sub logentry
	{
		my($outmsg) = @_;
		print $outmsg;
		print OUT $outmsg;
	}

sub logerrdb
	{
		my($devid, $ErrSect, $ErrSectInst, $ErrMsg) = @_;
		$ErrMsg =~ s/\'/''/g;
		$strErrCmd =  "insert into inventory.dbo.tblsnmperr (ideviceid, vcerrpart, iErrPartInst, vcerrmsg, dtdatetimestamp) ";
		$strErrCmd .= "values ($devid, '$ErrSect', '$ErrSectInst', '$ErrMsg', getdate())";
		$Cmd->{CommandText} = $strErrCmd;
		$Cmd->{Execute};
		if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strErrCmd\n".Win32::OLE->LastError(),1);}
		logentry("Logged $ErrSect # $ErrSectInst error in database.\n");			
	}
	
	
sub cleanup
	{
		my($closemsg,$exitcode) = @_;
		my($isec, $imin, $ihour, $StopTime, $iDay);
		my($iSecs, $iMins, $iHours, $iDays, $iDiff);
		
		if (defined($RS))
			{
				$RS->close;
				undef $RS;
			}
		if (defined($Cmd))
			{
				$Cmd->close;
				undef $Cmd;
			}
		$StopTime = time;
		$isec = $StopTime - $StartTime;
		$imin = $isec/60;
		$ihour = $imin/60;
		$iDay = $ihour/24;
		$iDiff = $isec;
		$iDays = int($iDiff/86400);
		$iDiff -= $iDays * 86400;
		$iHours = int($iDiff/3600);
		$iDiff -= $iHours * 3600;
		$iMins = int($iDiff/60);
		$iSecs = $iDiff - $iMins * 60;
		
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year = $year+1900;
		$min = substr("0$min",-2);	
		$mon = $mon + 1;			
		logentry ("Stopped processing at $mon/$mday/$year $hour:$min\n" );
		logentry ("Processing took $iDays days, $iHours hours, $iMins minutes and $iSecs seconds.\n");
		logentry ("elapse time $isec seconds; $imin minutes; $ihour hours; $iDay days.\n");
		#logentry ($closemsg);
		push @body, "$closemsg\n";
		push @body, "\nStopped processing at $mon/$mday/$year $hour:$min\n";
		push @body, "elapse time $isec seconds; $imin minutes; $ihour hours.\n";
		push @body, "exiting with exit code $exitcode\n";
		logentry (@body);
		send_mail();
		close (OUT) or warn "error while closing log file $logfile: $!" ;
		exit($exitcode);
	}
	
sub send_mail 
{
my ($smtp, $body);
	
	$smtp = Net::SMTP->new($relay, Debug => 0); # Set Debug to 1 if you have any problems
	if (!defined($smtp))
	{
		logentry ("Failed to open mail session to $relay\n");
		close (OUT) or warn "error while closing log file $logfile: $!" ;		
		exit 4;
	}
	else
	{
		$smtp->mail($from) ;
		$smtp->to($to) ;
		
		$smtp->data() ;
		$smtp->datasend("To: $to\n") ;
		$smtp->datasend("From: $from\n") ;
		$smtp->datasend("Subject: $subject\n") ;
		$smtp->datasend("\n") ;
		
		foreach $body (@body) 
		{
			$smtp->datasend("$body") ;
		}
		$smtp->dataend() ;
		$smtp->quit() ;
	}
	undef $smtp;
}		