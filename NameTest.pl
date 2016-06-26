use English;
$seq = 1;
$LogPath = "c:/tmp/log/script/test/";
$scriptFullName = $PROGRAM_NAME;
print "Scriptname: $scriptName\n";
$scriptName =~ s/\\/\//g;	
print "Clean Scriptname: $scriptName\n";
@tmp = split(/\//,$scriptName);
$pathparts = scalar @tmp;
$sname = $tmp[$pathparts-1];
print "There are $pathparts parts in the scriptname $scriptname. The last one is $sname\n";
($progname) = split(/\./,$sname);
$logfile = "$LogPath$progname-$seq.log";
print "Logfile: $logfile\n";