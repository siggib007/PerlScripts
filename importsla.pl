use strict;   
use Net::FTP;
use Win32::OLE 'in';
use Net::SMTP;
use Win32::OLE::Variant;
use Time::Local;


my ($ftp, @filelist, $file, $server, $uid, $rdir, $ldir, $pwdfile, %pwdlist, @pwdline, $DBuser);
my ($Conn, $cmdText, $OracleCN, $OracleRS, %SLA, $DBServer, $dstTable, $SQLCN, $SQLRS, $dateRS);
my($to, $from, $subject, @body, $relay, $ORADS, $totalcount);

#$relay = "tk2smtp.phx.gbl";
$relay = "satsmtpa01";
$to = "siggib\@microsoft.com";
$from = "siggib\@microsoft.com";
$subject = "Import Brix SLA job failure";

$server = "tuk-bcol-1";
$DBServer = "satnetengfs01";
$cmdText = "SELECT DISTINCT sla_id, sla_name FROM sld where end_time is null";
$dstTable = "reports.dbo.VLANAvailability";
$uid = "brix";
$rdir = "scripts/bcp";
$ldir = "d:/siggib/brix";
$pwdfile = "//by2netsql01/Brix/BrixAccounts.txt";
$DBuser = "registry";
$ORADS = "BrixOracle";

print "initializing....\n";
$totalcount = 0;

$SQLCN    = new Win32::OLE "ADODB.Connection";
if (!defined($SQLCN) or Win32::OLE->LastError() != 0 ) 
{
	cleanup("Failed to create SQL conenction object\n".Win32::OLE->LastError(),1);
}

$SQLRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SQLRS) or Win32::OLE->LastError() != 0 ) 
{
	cleanup("Failed to create SQL recordset object\n".Win32::OLE->LastError(),1);
}

$dateRS = new Win32::OLE "ADODB.Recordset";
if (!defined($dateRS) or Win32::OLE->LastError() != 0 ) 
{
	cleanup("Failed to create second SQL recordset object\n".Win32::OLE->LastError(),1);
}

$OracleCN    = new Win32::OLE "ADODB.Connection";
if (!defined($OracleCN) or Win32::OLE->LastError() != 0 ) 
{
	cleanup("Failed to create Oracle conenction object\n".Win32::OLE->LastError(),1);
}

$OracleRS = new Win32::OLE "ADODB.Recordset";
if (!defined($OracleRS) or Win32::OLE->LastError() != 0 ) 
{
	cleanup("Failed to create Oracle recordset object\n".Win32::OLE->LastError(),1);
}

open(IN,$pwdfile) || die "cannot open password file $pwdfile for reading: $!";
while(<IN>)
{
	@pwdline = split(/\t/);
	if (scalar @pwdline > 1) {	$pwdlist{$pwdline[0]}= $pwdline[1]; }
}
close(IN) or warn "error while closing password file: $!" ;

print "opening connection to the Brix Database...\n";
$Conn = "Data Source=$ORADS;UID=$DBuser;PWD=$pwdlist{$DBuser};";
$OracleCN->{ConnectionString} = $Conn;
$OracleCN->open; 
if (Win32::OLE->LastError() != 0 ) 
{
	cleanup("Failed to open a connection to Brix Oracle\n".Win32::OLE->LastError(),1);
}

print "fetching SLA list from the Brix Database...\n";
$OracleRS->Open ($cmdText, $OracleCN);
if (Win32::OLE->LastError() != 0 ) 
{
	cleanup("Failed to fetch SLA List\n".Win32::OLE->LastError(),1);
}

print "loading SLA list into memory ... \n";
while ( !$OracleRS->EOF )
{
	$SLA{$OracleRS->{fields}{sla_id}->{value}} = $OracleRS->{fields}{sla_name}->{value};
	$OracleRS->MoveNext;
}

$OracleRS->Close;
$OracleCN->Close;

$SQLCN->{Provider} = "sqloledb";
$SQLCN->{Properties}{"Data Source"}->{value} = $DBServer;
$SQLCN->{Properties}{"Integrated Security"}->{value} = "SSPI";

print "Attempting to open Connection to the SQL server $DBServer\n";
$SQLCN->open; 
if (Win32::OLE->LastError() != 0 ) 
{
	cleanup("cannot open database connection to $DBServer\n".Win32::OLE->LastError(),1);
}

print "opening up the destination table\n";
$SQLRS->{LockType} = 3; #adLockOptimistic
$SQLRS->{ActiveConnection} = $SQLCN;
$SQLRS->{Source} = $dstTable;
$SQLRS->Open;
if (Win32::OLE->LastError() != 0 ) 
{
	cleanup("Unable to open destination table $dstTable\n".Win32::OLE->LastError(),1);
}

print "\n\nNow connecting to $server ...\n";
$ftp = Net::FTP->new($server, Passive=>0, Debug=>0) or die "Cannot connect to $server: $@";

print "connection successful, login in as $uid ... \n";
$ftp->login($uid,$pwdlist{$uid}) or die "Cannot login as $uid", $ftp->message;

print "logged in, now changing remote directory to $rdir\n";
$ftp->cwd($rdir) or die "Cannot change working directory to $rdir ", $ftp->message;
print "listing directory\n";
@filelist = $ftp->ls or die "Cannot get directory listing " , $ftp->message;

foreach $file (@filelist)
{
	print "Fetching $file\n";
    $ftp->get($file, "$ldir/$file") or warn "get failed on $file ", $ftp->message;
    parse("$ldir/$file");
}
cleanup ("done\n",0);


sub parse
{
	my ($count, @lines, @lineparts, @fileparts, $SLAid, $line);
	my ($maxdate, $DateCmd, @datepart, $maxtime, $linedate, $linetime);
	my($file) = @_;
	
	$count = 0;
	@fileparts = split(/\//,$file);
	($SLAid) = split(/\./,$fileparts[(scalar @fileparts)-1]);

	if ($SLA{$SLAid} =~ /VLANAvailability/)
	{
		$DateCmd = "select max(dateofdata) maxdate from $dstTable where summary = '$SLA{$SLAid}'";
		$dateRS->Open ($DateCmd, $SQLCN);
		if (Win32::OLE->LastError() != 0 ) 
		{
			cleanup("Failed to fetch maxdate\n".Win32::OLE->LastError(),1);
		}
	
		$maxdate = $dateRS->{fields}{maxdate}->{value};
		$dateRS->Close;
		print "$SLA{$SLAid} last date is $maxdate\n";
		my($mon,$day,$year)= split(/\//,$maxdate);
		$maxtime = timelocal(0,0,0,$day,$mon-1,$year);
		#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($maxtime);
		#print "converted is $mon/$mday/$year\n";

		open(IN, $file) or die "failed to open $file after downloading it: $!";
		while(<IN>)
		{
			@lines = split(/\#\#/);
			foreach $line (@lines)
			{
				@lineparts = split(/\,/,$line);
				if (scalar @lineparts > 5 )
				{
					($linedate) = split(/ /,$lineparts[0]);
					my($mon,$day,$year)= split(/\//,$linedate);
					$linetime = timelocal(0,0,0,$day,$mon-1,$year);
					if ($linetime > $maxtime)
					{
						$SQLRS->AddNew;
							if (Win32::OLE->LastError() != 0 ) 
							{
								cleanup("error while adding record to destination table\n".Win32::OLE->LastError(),1);
								exit 1;
							}			
							$SQLRS->{fields}{DateOfData}->{value} = $lineparts[0];
							$SQLRS->{fields}{AppName}->{value}    = $lineparts[1];
							$SQLRS->{fields}{Datacenter}->{value} = $lineparts[2];
							$SQLRS->{fields}{Devicename}->{value} = $lineparts[3];
							$SQLRS->{fields}{DataName}->{value}   = $lineparts[4];
							$SQLRS->{fields}{DataValue}->{value}  = $lineparts[5];
							$SQLRS->{fields}{Summary}->{value}    = $SLA{$SLAid};
						$SQLRS->Update; 
						if (Win32::OLE->LastError() != 0 ) 
						{
							cleanup("error while saving new record\n".Win32::OLE->LastError(),1);
						}
						$count = $count + 1;
					}
				}
			}
		}
	}
	print "Imported $count lines for $SLA{$SLAid}\n";
	$totalcount = $totalcount + $count;
}

sub cleanup
{
	my($closemsg,$exitcode) = @_;
	
	if ($exitcode eq '')
	{
		$exitcode = 3;
	}

	if ($exitcode == 0 and $totalcount == 0)
	{
		$exitcode = 4;
	}	
	if (defined($ftp))
	{
		$ftp->quit;
		undef $ftp;	
	}
	
	if (defined($OracleRS))
	{	
		undef $OracleRS;
	}
	
	if (defined($SQLRS))
	{	
		$SQLRS->Close;
		undef $SQLRS;
	}
	
	if (defined($dateRS))
	{	
		undef $dateRS;
	}
	
	if (defined($OracleCN))
	{			
		undef $OracleCN;
	}

	if (defined($SQLCN))
	{			
		$SQLCN->Close;
		undef $SQLCN;
	}

	push @body, "$closemsg\n";
	push @body, "Imported $totalcount lines\n";
	push @body, "Exiting with exit code $exitcode\n";
	print @body;
	if ($exitcode > 0) { send_mail(); }
	exit $exitcode;
}

sub send_mail 
{
  my ($smtp, $body);
  $smtp = Net::SMTP->new($relay, Debug => 0); # Set Debug to 1 if you have any problems

  $smtp->mail($from) ;
  $smtp->to($to) ;

  $smtp->data() ;
  $smtp->datasend("To: $to\n") ;
  $smtp->datasend("From: $from\n") ;
  $smtp->datasend("Subject: $subject\n") ;
  $smtp->datasend("\n") ;

#----- This part loops through your file and puts all the lines into your mail one by one
  foreach $body (@body) {
    $smtp->datasend("$body") ;
  }
  $smtp->dataend() ;
  $smtp->quit() ;
}
