use File::stat;
$DNSAge = 60*60*24;
$DNSDumpFile = "/var/tmp/DNSDumps.txt";
if (-e $DNSDumpFile)
{
	if (-f $DNSDumpFile)
	{
		print "$DNSDumpFile is a regular file\n";
		if (-T $DNSDumpFile)
		{
			print "$DNSDumpFile is a text file\n";
		}
		else
		{
			print "$DNSDumpFile is NOT a text file\n";
		}
		if (-z $DNSDumpFile)
		{
			print "$DNSDumpFile is zero lenght\n";
		}
		else
		{
			$fileSize = -s $DNSDumpFile;
			print "$DNSDumpFile is $fileSize bytes long\n";
		}
		$fileAge = -M $DNSDumpFile;
		$LastAccess = -A $DNSDumpFile;
		print "$DNSDumpFile is $fileAge days old. \nLast accessed $LastAccess \n";
	}
	else
	{
		print "$DNSDumpFile is a directory or a link\n";
	}
	($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
	    $atime, $mtime, $ctime, $blksize, $blocks) = stat($DNSDumpFile);
	
	print("dev     = $dev\n");
	print("ino     = $ino\n");
	print("mode    = $mode\n");
	print("nlink   = $nlink\n");
	print("uid     = $uid\n");
	print("gid     = $gid\n");
	print("rdev    = $rdev\n");
	print("size    = $size\n");
	print("atime   = $atime\n");
	print("mtime   = $mtime\n");
	print("ctime   = $ctime\n");
	print("blksize = $blksize\n");
	print("blocks  = $blocks\n");	
}
else
{
	print "$DNSDumpFile does not exists\n";
}
$mtime = (stat($DNSDumpFile))[9];

print("modified time in epoc sec: $mtime\n");

$ModTime = stat($DNSDumpFile)->mtime;

print("modified time in epoc sec by ref: $ModTime\n");

$TimeDiff = time() - $ModTime ;

print "mtime diff = $TimeDiff\t Age=$DNSAge\n";

if ($TimeDiff > $DNSAge)
{
	print "$DNSDumpFile is older than DNSAge\n";
}
else
{
	print "$DNSDumpFile is NOT older than DNSAge\n";
}

$iDiff = $TimeDiff;
$iDays = int($iDiff/86400);
$iDiff -= $iDays * 86400;
$iHours = int($iDiff/3600);
$iDiff -= $iHours * 3600;
$iMins = int($iDiff/60);
$iSecs = $iDiff - $iMins * 60;

if ($iDays > 0)
{
	$strTimeEst .= "$iDays days, ";
}
if ($iHours > 0)
{
	$strTimeEst .= "$iHours hours, ";
}
if ($iMins > 0)
{
	$strTimeEst .= "$iMins minutes and ";
}
$strTimeEst .= "$iSecs seconds";

print "$DNSDumpFile is $strTimeEst old\n";