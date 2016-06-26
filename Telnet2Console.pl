#!/perl/bin/perl
use Net::Telnet 3.00;
use strict;
use Win32::OLE 'in';
use Win32::OLE::Variant;
use Time::Local;

my ($login, $password, $DevUID, $DevPWD, $hostname, $port, $prompt, $t, $output, $match, $devname, $fh);
my (%pwdlist, $pwdfile, @pwdline, $autopwdfile, %autopwd, $SQLCN, $SQLRS, $DBServer, $dstTable, $line);
my ($errormsg, $logfile, $serverUID,$ConTimeout, @ret);

$ConTimeout = 30;
$DBServer = "by2netsql01";
$dstTable = "brix.dbo.devices";
$pwdfile = "//by2netsql01/Brix/BrixAccounts.txt";
$autopwdfile = "//by2netsql01/siggib_auto/Scriptpwd.txt";
$logfile = "H:/PerlScript/BrixConsole.log";
$login = "username1";
$DevUID = "username2";
$serverUID = "username3";
$prompt = '/\n/';

open(OUT,">$logfile") || die "cannot open log file $logfile for write: $!";
logentry ("initializing....\n");

open(IN,$pwdfile) || die "cannot open password file $pwdfile for reading: $!";
while(<IN>)
{
	@pwdline = split(/\t/);
	if (scalar @pwdline > 1) {	$pwdlist{$pwdline[0]}= $pwdline[1]; }
}
close(IN) or warn "error while closing password file: $!" ;

open(IN,$autopwdfile) || die "cannot open password file $autopwdfile for reading: $!";
while(<IN>)
{
	@pwdline = split(/\t/);
	if (scalar @pwdline > 1) {	$autopwd{$pwdline[0]}= $pwdline[1]; }
}
close(IN) or warn "error while closing password file $autopwdfile: $!" ;

$SQLCN    = new Win32::OLE "ADODB.Connection";
if (!defined($SQLCN) or Win32::OLE->LastError() != 0 ) 
{
	die "Failed to create SQL conenction object\n".Win32::OLE->LastError();
}

$SQLRS = new Win32::OLE "ADODB.Recordset";
if (!defined($SQLRS) or Win32::OLE->LastError() != 0 ) 
{
	die "Failed to create SQL recordset object\n".Win32::OLE->LastError();
}

$SQLCN->{Provider} = "sqloledb";
$SQLCN->{Properties}{"Data Source"}->{value} = $DBServer;
$SQLCN->{Properties}{"Integrated Security"}->{value} = "SSPI";

logentry ("Attempting to open Connection to the SQL server $DBServer\n");
$SQLCN->open; 
if (Win32::OLE->LastError() != 0 ) 
{
	die "cannot open database connection to $DBServer\n".Win32::OLE->LastError();
}

logentry ("opening up the destination table $dstTable\n");
$SQLRS->{LockType} = 3; #adLockOptimistic
$SQLRS->{ActiveConnection} = $SQLCN;
$SQLRS->{Source} = $dstTable;
$SQLRS->Open;
if (Win32::OLE->LastError() != 0 ) 
{
	die "Unable to open destination table $dstTable\n".Win32::OLE->LastError();
}

logentry ("got the recordset, starting processing...\n");
while ( !$SQLRS->EOF )
{
	$line = $SQLRS->{fields}{ConsolePort}->{value};
	if ($line eq '')
	{
		nextloop();
		next;
	}			
	($hostname,$port) = split(/ /,$line);
	$t = Net::Telnet->new(  Timeout => $ConTimeout, Prompt=> $prompt, Errmode => "return" );
	$fh = $t->input_log("h:/perlscript/logs/OOB_$hostname\_$port.log");
	logentry ("Attempting to login to $hostname port $port\n");
	unless (defined $t->open(Host => $hostname, Port => $port))
	{
		$errormsg = $t->errmsg;
		logentry ("Failed to open connection to $hostname $port\nerrmsg: $errormsg\n");
		$devname = $errormsg;
		nextloop();
		next;
	}	
	@ret = $t->waitfor('/name:/');
	if (scalar @ret == 0)
	{
		$errormsg = $t->errmsg;
		logentry ("errmsg: $errormsg\n");
		$devname = $errormsg;
		nextloop();
		next;
	}	
	$t->print($login);
	@ret = $t->waitfor('/word:/');
	if (scalar @ret == 0)
	{
		$errormsg = $t->errmsg;
		logentry ("errmsg: $errormsg\n");
		$devname = $errormsg;
		nextloop();
		next;
	}		
	$t->print($autopwd{$login});
	logentry ("Login to OOB complete\n");
	$prompt = '/>/';
	$t->print("");
	@ret = $t->waitfor('/name:|>|\#|console login:/');
	if (scalar @ret == 0)
	{
		$errormsg = $t->errmsg;
		logentry ("errmsg: $errormsg\n");
		$devname = $errormsg;
		nextloop();
		next;
	}
	($output, $match) = @ret;		
	if ($match eq "console login:")
	{
		logentry ("Found the Brix server on $hostname $port\n");
		$devname = "tuk-bcol-1";
		nextloop();
		next;		
	}
	if ($match =~ />|\#/)
	{
		logentry ("Already logged into device $output\n");
	}
	else
	{
		logentry ("attempting to log into console\n");
		$t->print($DevUID);
		@ret = $t->waitfor('/word:/');
		$t->print($pwdlist{$DevUID});
		@ret = $t->waitfor($prompt);
	}
	($output, $match) = @ret;	
	if ($match eq "\#")
	{
		logentry ("Device was left in enable mode, exit back to user mode\n");
		$t->print ("exit");
		($output, $match) = $t->waitfor($prompt);
	}
	$t->print ("");
	($output, $match) = $t->waitfor($prompt);
	$devname = $output;
	$t->print ("exit");
	($output, $match) = $t->waitfor('/:/');
	$t->close();
	nextloop();
}
close (OUT) or warn "error while closing log file $logfile: $!" ;

sub logentry
{
	my($outmsg) = @_;
	print $outmsg;
	print OUT $outmsg;
}

sub nextloop
{
	$devname =~ s/\n//g;
	logentry ("Found $devname on $hostname $port\n");
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year = $year+1900;
	$min = substr("0$min",-2);
	$mon = $mon + 1;
	logentry ("Saving $devname $mon/$mday/$year $hour:$min to database\n");
	$SQLRS->{fields}{vcOOBVerified}->{value} = $devname;
	$SQLRS->{fields}{dtOOBVerified}->{value} = "$mon/$mday/$year $hour:$min";
	$SQLRS->Update;
	$SQLRS->MoveNext;
}