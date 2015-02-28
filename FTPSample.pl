   use Net::FTP;
	print "now connecting...\n";
    $ftp = Net::FTP->new("tuk-bcol-1")
      or die "Cannot connect to tuk-bcol-1: $@";
	
	print "connection successful, login in ... \n";
    $ftp->login("brix",'test123')
      or die "Cannot login ", $ftp->message;

	print "logged in, now changing remote directory\n";
    $ftp->cwd("scripts/bcp")
      or die "Cannot change working directory ", $ftp->message;
    #print "issuing port command\n";
	#$ftp->port or die "Failed on port command " , $ftp-message;
	print "listing directory\n";
	@filelist = $ftp->ls or die "Cannot get directory listing " , $ftp->message;
	#print @filelist;
	foreach $file (@filelist)
	{
		print "Fetching $file\n";
	    $ftp->get($file, "D:/siggib/PerlScript/bcp/$file")
      		or warn "get failed ", $ftp->message;
    }
	print "done, exiting.\n";
    $ftp->quit;