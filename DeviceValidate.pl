use strict;
use Socket;
use Net::Ping::External qw(ping);
use File::Basename;
use Win32::OLE 'in';
use Net::Telnet 3.00;
use Net::SMTP;
use English;
use Sys::Hostname;
use File::Basename;
use constant Cat1900Model => 76;
use constant Cat1900cModel => 78;
use constant Cat1900LiteFxModel => 77;


my ($SrcCN, $SrcRS, $strSQL, $srcDBServer, $i, $DevName, $alive, $DevID, $login, $prompt, $t, $IP, $Reachable);
my ($packed_ip, $ip_address, $iaddr, $HostName, $strCmd, $scriptName, $Cmd, $password, $TelResult, $DNS, $progDir);
my ($to, $from, $subject, @body, $relay, $StartTime, $logfile, $SSHPortTest, $SSHport, $Model, $TelTest);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

($logfile) = split(/\./,$PROGRAM_NAME);
$logfile .= ".log";
print "Logging to $logfile\n";

open(OUT,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing....\n");

$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$login = "cwuser";
$password ="CW2Work?";
#$prompt = '/#/';
$prompt = '/\#|\>/';
$scriptName = basename($0);
$i = 1;
$SSHport = 22;
$srcDBServer = hostname();
$strSQL = "select iDeviceID, vcDeviceName, iModelID, vcIPAddress from inventory.dbo.tbldevices where istatusid in (1,2) and imakeid = 1";
$relay = "eagle.alaskaair.com";
$to = "siggi.bjarnason\@alaskaair.com";
$from = "siggi.bjarnason\@alaskaair.com";
$subject = "DeviceValidate job outcome";
$StartTime = time;

$t = Net::Telnet->new(  Timeout => 30,
                        Prompt=> $prompt,
                        Errmode => "return" );
$SrcCN = new Win32::OLE "ADODB.Connection";
$SrcRS = new Win32::OLE "ADODB.Recordset";
$Cmd   = new Win32::OLE "ADODB.Command";

$SrcCN->{Provider} = "sqloledb";
$SrcCN->{Properties}{"Data Source"}->{value} = $srcDBServer;
$SrcCN->{Properties}{"Integrated Security"}->{value} = "SSPI";

logentry ("Started processing at $mon/$mday/$year $hour:$min\n" );
logentry ("Attempting to open Connection to database on $srcDBServer\n");
$SrcCN->open;
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to Open Connection\n".Win32::OLE->LastError(),1);}
logentry ("attempting to execute query to retrieve device list\n");
$SrcRS->Open ($strSQL, $SrcCN);
if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to fetch data\n".Win32::OLE->LastError(),1);}
$Cmd->{ActiveConnection} = $SrcCN;
while ( !$SrcRS->EOF )
	{
		$DevName = $SrcRS->{fields}{vcDeviceName}->{value};
		$DevID = $SrcRS->{fields}{iDeviceID}->{value};
		$Model = $SrcRS->{fields}{iModelID}->{value};
		$IP = $SrcRS->{fields}{vcIPAddress}->{value};
		$TelResult = "";
		$SSHPortTest = 0;
		$TelTest = 0;
		if ($DevName =="")
		{
			$DevName = $IP;
			logentry ("blank device name, switching to IP\n");
		}
		logentry ("$i: $DevName  ID:$DevID  Model:$Model\n");
		$strCmd  = "update inventory.dbo.tbldevices set dtLastReachAttempt = getdate() where ideviceid = $DevID";
   		$Cmd->{CommandText} = $strCmd;
		$Cmd->{Execute};
		if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
		logentry("Successfully updated Database with reach attempt.\n");
		
    	$packed_ip = gethostbyname($DevName);
    	if (defined $packed_ip) 
    		{
    	    	$ip_address = inet_ntoa($packed_ip);
    			logentry ("IP Addr: $ip_address\n");
    			if ($ip_address ne $IP)
    			{
		   			$iaddr = inet_aton($IP);
    				$HostName  = gethostbyaddr($iaddr, AF_INET);
    				if ($HostName eq "")
    				{
    					$HostName = $IP;
    					$DNS = 0;
    				}
    				else
    				{
    					$DNS = 1;
    				}
    				$alive = ping(host => $HostName);
  					if ($alive)
  					{
  						TelnetTest ($HostName);
  						PortTest ($HostName,$SSHport);
  						$Reachable = "getdate()";
					    $strCmd = "vcTelnetResults = '$TelResult', bSSHTest = $SSHPortTest, bTelnetTest = $TelTest, bDNSLookup = 1";
  					}
  					else
  					{
					    $Reachable = "Null";
  					}
    				$strCmd = "insert tbldevices (vcDeviceName, iMakeID, iModelID, vcIPAddress, dtLastUpdated, iClassID, vcLastUpdatedBy, iStatusID, vcTelnetResults, bSSHTest, bTelnetTest, bDNSLookup, dtLastReached, dtLastReachAttempt)";
    				$strCmd .= "values ('$HostName',1,0,'$IP',getdate(),3,'$scriptName',2,'$TelResult',$SSHPortTest,$TelTest,$DNS, $Reachable, getdate())";
    				$Cmd->{CommandText} = $strCmd;
					$Cmd->{Execute};
					if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
					logentry("Successfully added new record for IP mismatch.\n");    				
    			}
    			$DNS = 0;
    			$iaddr = inet_aton($ip_address);
    			$HostName  = gethostbyaddr($iaddr, AF_INET);
			    logentry ("DNS Name: $HostName\n");
   				if ($HostName eq "")
   				{
   					$DNS = 0;
   				}
   				else
   				{
   					$DNS = 1;
   				}
   				$alive = ping(host => $DevName);
			    
  				if ($alive)
  				{
  					logentry ("$DevName is online\n");
  					TelnetTest ($DevName);
  					PortTest ($DevName,$SSHport);
  					$Reachable = "getdate()";
  					$DNS = 1;
				    $strCmd = "update inventory.dbo.tbldevices set vcIPAddress = '$ip_address', vcDNSName = '$HostName', dtLastUpdated = getdate(), vcLastUpdatedBy = '$scriptName', dtLastReached = getdate(), vcTelnetResults = '$TelResult', bSSHTest = $SSHPortTest, bTelnetTest = $TelTest, bDNSLookup = 1 where ideviceid = $DevID";
  				}
  				else
  				{
  					logentry ("$DevName is not reachable from this station via ICMP\n");
  					$Reachable = "Null";
				    $strCmd = "update inventory.dbo.tbldevices set vcIPAddress = '$ip_address', vcDNSName = '$HostName', dtLastUpdated = getdate(), vcLastUpdatedBy = '$scriptName', bDNSLookup = 1 where ideviceid = $DevID ";
  				}
  				$strCmd = "update inventory.dbo.tbldevices set vcIPAddress = '$ip_address', vcDNSName = '$HostName', dtLastUpdated = getdate(), vcLastUpdatedBy = '$scriptName', dtLastReached = $Reachable, vcTelnetResults = '$TelResult', bSSHTest = $SSHPortTest, bTelnetTest = $TelTest, bDNSLookup = $DNS where ideviceid = $DevID";
			}
    	else
    		{
    			logentry ("Unable to resolve\n");
    			$DNS = 0;
    			$strCmd = "update inventory.dbo.tbldevices set dtLastUpdated = getdate(), vcLastUpdatedBy = '$scriptName', bDNSLookup = 0 where ideviceid = $DevID ";
    		}
    	if ($strCmd ne '')
    		{
    		logentry("Updating database\n");
    		$Cmd->{CommandText} = $strCmd;
			$Cmd->{Execute};
			if (Win32::OLE->LastError() != 0 ) { cleanup("Failed to update database using:\n$strCmd\n".Win32::OLE->LastError(),1);}			
			logentry("Successfully updated Database.\n");
			}
		$SrcRS->MoveNext;
		$i += 1;
	}
$SrcRS->Close;
undef $SrcRS;
$SrcCN->Close;
undef $SrcCN;

cleanup("Done",0);

sub cleanup
	{
		my($closemsg,$exitcode) = @_;
		my($isec, $imin, $ihour, $StopTime);
		my($iSecs, $iMins, $iHours, $iDays, $iDiff);
		
		if (defined($t))
			{
				$t->close;
				undef $t;
			}
		if (defined($SrcCN))
			{
				$SrcCN->close;
				undef $SrcCN;
			}
		if (defined($SrcRS))
			{
				$SrcRS->close;
				undef $SrcRS;
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
		logentry ("elapse time $isec seconds; $imin minutes; $ihour hours.\n");
		logentry ("exiting with exit code $exitcode\n");
		logentry ($closemsg);

		push @body, "$closemsg\n";
		push @body, "\nStopped processing at $mon/$mday/$year $hour:$min\n";
		push @body, "Processing took $iDays days, $iHours hours, $iMins minutes and $iSecs seconds.\n";
		push @body, "elapse time $isec seconds; $imin minutes; $ihour hours.\n";
		push @body, "exiting with exit code $exitcode\n";
		#logentry (@body);
		send_mail();
		close (OUT) or warn "error while closing log file $logfile: $!" ;
		exit($exitcode);
	}

sub TelnetTest
	{
		my($hostname) = @_;
		my($errormsg, $output, $match, @ret);
		if (!defined($t->open(Host => $hostname, Port => 23)))
			{
				$errormsg = $t->errmsg();
				logentry ("Failed telnet to $hostname port 23: $errormsg\n");
				$TelResult = $errormsg;
				$TelTest = 0;
			}
		else
			{
				if ($Model == Cat1900Model or $Model == Cat1900cModel or $Model == Cat1900LiteFxModel)
					{
						@ret = $t->waitfor('/Menu/');
						if (scalar @ret == 0)
							{
								$errormsg = $t->errmsg;
								logentry ("1900ErrOnMenu: $errormsg\n");
								$TelResult = $errormsg;
								$TelTest = 0;
							}
						else
							{
								$t->print("k");
								@ret = $t->waitfor($prompt);
								if (scalar @ret == 0)
									{
										$errormsg = $t->errmsg;
										logentry ("1900ErrOnCLI: $errormsg\n");
										$TelResult = $errormsg;
										$TelTest = 0;
									}
								else
									{
										($output, $match) = @ret;
										$TelResult = substr($output,1);
										if (rindex($TelResult, chr(13)) > -1)
										{
											$TelResult = substr($TelResult,rindex($TelResult, chr(13)));
										}
										logentry ("1900TelnetTestOutput:$TelResult\n");
										$TelTest = 1;
									}
								}
					}
				else
					{
						@ret = $t->login($login,$password);
						if (scalar @ret == 0)
							{
								$errormsg = $t->errmsg;
								logentry ("Failed to login to $hostname: $errormsg\n");
								$TelResult = $errormsg;
								$TelTest = 0;
							}
						else
							{
								$t->print("");
								@ret = $t->waitfor($prompt);
								if (scalar @ret == 0)
									{
										$errormsg = $t->errmsg;
										logentry ("Failedprompt: $errormsg\n");
										$TelResult = $errormsg;
										$TelTest = 0;
									}
								else
									{
										($output, $match) = @ret;
										$TelResult = substr($output,1);
										if (rindex($TelResult, chr(13)) > -1)
										{
											$TelResult = substr($TelResult,rindex($TelResult, chr(13)));
										}
										logentry ("TelnetTestOutput:$TelResult\n");
										$TelTest = 1;
									}
							}
						}
				$t->close();
			}
	}
	
sub PortTest
	{
		my($hostname, $port) = @_;
		if (defined($t->open(Host => $hostname, Port => $port)))
			{
				$SSHPortTest="1";
			}
		else
			{
				$SSHPortTest="0";
			}
	}

sub logentry
	{
		my($outmsg) = @_;
		print $outmsg;
		print OUT $outmsg;
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