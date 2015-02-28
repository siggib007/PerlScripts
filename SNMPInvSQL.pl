use strict;
use net::SNMP;
use Win32::OLE 'in';
use Net::SMTP;

my ($devicename, $comstr, $session, $error, $sysname, $ifTable, $result, %reshash, $key, $errmsg);
my ($StartTime, $isec, $imin, $len, $id, %reshash, $type, $inst, %IntStat, %vmPortStatus, %vmVlanType);
my ($CN, $SrcRS, $dstRS, $SrcCmdText, $DBServer, $Cmd, $ComCmd, $CmdStr, $Device, $StopTime, $ihour);
my ($CDPCmdText, $CDPrs, $rem, $tail, $finst, %cdpcach, $cdpCacheEntry, %Int, $rdevice, %VlanMember);
my ($to, $from, $subject, @body, $relay, %IntType, %IntDescr, %IntIP, %IntMask, %VlanNames, %ArpTable);
my ($sysname, $cdpCacheEntry, $SysObjID, $SysLocation,$IPonInt, $IPmask, $locIfDescr, $arpPhysAddress, $ChassisSN);
my ($ChassisModel, $VlanMembers, $VlanName, $strSysObjID, $strLocation, $strSerialNum, $strModel);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$DBServer = "SEAVVAS001W02";
$relay = "eagle.alaskaair.com";
$to = "siggi.bjarnason\@alaskaair.com";
$from = "siggi.bjarnason\@alaskaair.com";
$subject = "Inventory job outcome";
$SrcCmdText = "inventory.dbo.tblDevices";
$CDPCmdText = "Inventory.dbo.CDPNeighborRaw";
$ComCmd = "select vcComRO from inventory.dbo.tblClass where iclassid = 3";

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

print "Started processing at $mon/$mday/$year $hour:$min\n" ;
$CN    = new Win32::OLE "ADODB.Connection";
if (!defined($CN) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create conenction object\n".Win32::OLE->LastError(),1);}

$SrcRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SrcRS) or Win32::OLE->LastError() != 0 ) { cleanup("Failed to create source recordset object\n".Win32::OLE->LastError(),1);}

$CDPrs = new Win32::OLE "ADODB.Recordset";
if (!defined($CDPrs) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a CDP recordset object\n".Win32::OLE->LastError(),1);}

$Cmd   = new Win32::OLE "ADODB.Command";
if (!defined($Cmd) or Win32::OLE->LastError() != 0 ) { cleanup("failed to create a command object\n".Win32::OLE->LastError(),1);}

$CN->{Provider} = "sqloledb";
$CN->{Properties}{"Data Source"}->{value} = $DBServer;
$CN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open Connection\n";
$CN->open; 
if (Win32::OLE->LastError() != 0 ) { cleanup("cannot open source database connection\n".Win32::OLE->LastError(),1);}

#$Cmd->{ActiveConnection} = $CN;
#$Cmd->{CommandText} = $Update1Cmd;
#$Cmd->{Execute}; 
#if (Win32::OLE->LastError() != 0 ){ cleanup("error while executing command: \n$Update1Cmd \n".Win32::OLE->LastError(),1);}

print "fetching com string\n";
$SrcRS->Open ($ComCmd, $CN);
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch comstr\n".Win32::OLE->LastError(),1);}

$comstr = $SrcRS->{fields}{vcComRO}->{value};
$SrcRS->Close;
$Device = @ARGV[0];
print "Device: $Device\tStr:$comstr\n";

($session,$error) = Net::SNMP->session(hostname => $Device, community => $comstr);
if (!defined($session)) 
{
	printf("Connect Error: %s.\n", $error);
}
else	
{
	$result = $session->get_request($sysname);
	$errmsg = "";
	if (!defined($result)) 
	{
		printf("Sysname ERROR: %s.\n", $session->error);
		$devicename = "";
	}
	else
	{
		$devicename = $result->{$sysname};
		print "Sysname: $devicename\n";
	}
	$result = $session->get_request($SysObjID);
	$errmsg = "";
	if (!defined($result)) 
	{
		printf("SysObjID ERROR: %s.\n", $session->error);
		$strSysObjID = "";
	}
	else
	{
		$strSysObjID = $result->{$SysObjID};
		print "SysObjID: $strSysObjID\n";
	}

	$result = $session->get_request($SysLocation );
	$errmsg = "";
	if (!defined($result)) 
	{
		printf("SysLocation  ERROR: %s.\n", $session->error);
		$strLocation  = "";
	}
	else
	{
		$strLocation = $result->{$SysLocation};
		print "Location: $strLocation\n";
	}
	
	$result = $session->get_request($ChassisSN );
	$errmsg = "";
	if (!defined($result)) 
	{
		printf("ChassisSN  ERROR: %s.\n", $session->error);
		$strSerialNum  = "";
	}
	else
	{
		$strSerialNum = $result->{$ChassisSN};
		print "SN: $strSerialNum\n";
	}
	
	$result = $session->get_request($ChassisModel );
	$errmsg = "";
	if (!defined($result)) 
	{
		printf("ChassisModel  ERROR: %s.\n", $session->error);
		$strModel  = "";
	}
	else
	{
		$strModel = $result->{$ChassisModel};
		print "Model: $strModel\n";
	}

	$result = $session->get_table($ifTable);
	if (!defined($result)) 
	{
		printf("If Table ERROR: %s.\n", $session->error);
	}
	else
	{
		%reshash = %$result;			
		foreach $key(sort(keys %reshash)) 
		{ 
			$len = length($ifTable);
			($type,$id) = split(/\./,substr($key,$len+1));
			$Int{$id}{$type} = $reshash{$key};
			#print "$id\t$reshash{$key}\n";
		}
	}

	$result = $session->get_table($locIfDescr);
	if (!defined($result)) 
	{
		printf("Int Desc ERROR: %s.\n", $session->error);
	}
	else
	{
		%reshash = %$result;			
		foreach $key(sort(keys %reshash)) 
		{ 
			$len = length($locIfDescr);
			$id = substr($key,$len+1);
			$IntDescr{$id} = $reshash{$key};
			#print "$id\t$reshash{$key}\n";			
		}
	}

	$result = $session->get_table($IPonInt);
	if (!defined($result)) 
	{
		printf("Int IP ERROR: %s.\n", $session->error);
	}
	else
	{
		%reshash = %$result;			
		foreach $key(sort(keys %reshash)) 
		{ 
			$len = length($IPonInt);
			$id = substr($key,$len+1);
			$IntIP{$id} = $reshash{$key};
			#print "$id\t$reshash{$key}\n";			
		}
	}

	$result = $session->get_table($IPmask);
	if (!defined($result)) 
	{
		printf("Int mask ERROR: %s.\n", $session->error);
	}
	else
	{
		%reshash = %$result;			
		foreach $key(sort(keys %reshash)) 
		{ 
			$len = length($IPmask);
			$id = substr($key,$len+1);
			$IntMask{$id} = $reshash{$key};
			#print "$id\t$reshash{$key}\n";			
		}
	}
	
	print "IP address, mask, Interface\n";
	foreach $key(sort(keys %IntIP))
	{
		print "$key, $IntMask{$key}, $Int{$IntIP{$key}}{'2'}\n";
	}
	
	$result = $session->get_table($VlanName );
	if (!defined($result)) 
	{
		printf("vlan name ERROR: %s.\n", $session->error);
	}
	else
	{
		%reshash = %$result;			
		foreach $key(sort(keys %reshash)) 
		{ 
			$len = length($VlanName );
			$id = substr($key,$len+1);
			$VlanNames{$id} = $reshash{$key};
			#print "$id\t$reshash{$key}\n";			
		}
	}
	
	$result = $session->get_table($VlanMembers );
	if (!defined($result)) 
	{
		printf("vlan member ERROR: %s.\n", $session->error);
	}
	else
	{
		%reshash = %$result;			
		foreach $key(sort(keys %reshash)) 
		{ 
			$len = length($VlanMembers );
			$id = substr($key,$len+1);
			$VlanMember{$id} = $reshash{$key};
			#print "$id\t$reshash{$key}\n";			
		}
	}


	print "Inst,Interface,Type,MTU,Speed,MAC,Admin,Oper\n   Description, Vlan Name\n";
	foreach $key(sort(keys %Int))
	{
		print "$key, $Int{$key}{'2'}, $IntType{$Int{$key}{'3'}}, $Int{$key}{'4'}, $Int{$key}{'5'}, $Int{$key}{'6'}, $IntStat{$Int{$key}{'7'}}, $IntStat{$Int{$key}{'8'}}\n";
		print "   $IntDescr{$key}, $VlanNames{$VlanMember{$key}}\n";
	}
	
	$result = $session->get_table($arpPhysAddress );
	if (!defined($result)) 
	{
		printf("Arp Table ERROR: %s.\n", $session->error);
	}
	else
	{
		%reshash = %$result;			
		foreach $key(sort(keys %reshash)) 
		{ 
			$len = length($arpPhysAddress );
			$id = substr($key,$len+1);
			$inst = substr($id,0,index($id,'.'));
			$rem = substr($id,index($id,'.')+1);
			$ArpTable{$id} = $reshash{$key};
			print "$Int{$inst}{'2'}\t$rem\t$reshash{$key}\n";			
		}
	}
	

	$result = $session->get_table($cdpCacheEntry);
	if (!defined($result)) 
	{
		printf("CDP ERROR: %s.\n", $session->error);
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
		#print "Local Interface\tRemote Device\tRemoteIP\tRemoteModel\tRemoteOS\tRemoteInt\n";
		#print "Local Interface\tRemote Device\tRemoteIP\tRemoteModel\tRemoteInt\n";
		foreach $key(sort(keys %cdpcach))
		{
			($rem,$inst) = split(/\./,$key);
			$cdpcach{$key}{'5'} =~ s/\n/ /g;
			$rdevice = $cdpcach{$key}{'6'};
			$rdevice = substr($rdevice,index($rdevice,"(")+1);
			$rdevice =~ s/\)//g;
			$rdevice =~ s/\(//g;
			($rdevice) = split (/\./,$rdevice);
			#print "$Int{$rem}\t$rdevice\t$cdpcach{$key}{'4'}\t$cdpcach{$key}{'8'}\t$cdpcach{$key}{'5'}\t$cdpcach{$key}{'7'}\n";
			#print "$Int{$rem}{'2'}\t$rdevice\t$cdpcach{$key}{'4'}\t$cdpcach{$key}{'8'}\t$cdpcach{$key}{'7'}\n";
		}
	}
}	
	