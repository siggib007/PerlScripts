use strict;   
use Net::FTP;

my ($ftp, @filelist, $file, $server, $uid, $rdir, $ldir, $pwdfile, %pwdlist, @pwdline, $ArraySize);

$server = "tuk-bcol-1";
$uid = "brix";
$rdir = "scripts/bcp";
$ldir = "D:/siggib/PerlScript/bcp";
$pwdfile = "//by2netsql01/Brix/BrixAccounts.txt";

open(IN,$pwdfile) || die "cannot open devicelist $pwdfile for reading: $!";
while(<IN>)
{
	@pwdline = split(/\t/);
	$ArraySize = @pwdline;
	if ($ArraySize > 1) {	$pwdlist{$pwdline[0]}= $pwdline[1]; }
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
}
print "done, exiting.\n";
$ftp->quit;
undef $ftp;
