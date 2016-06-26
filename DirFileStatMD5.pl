#!/usr/bin/perl
use strict;
###############################################################################################
# Directory Stats script with MD5 hashing                                                     #
# Author: Siggi Bjarnason                                                                     #
# Date Authored: 7/28/2012                                                                    #
# This script will take in a directory path and gather stats as well as MD5 hash for all      #
# files in that directory along with subdirectories, store them in a database.                #
# Then it will compare the stats and the MD5 hash to previously recorded values               #
# and send out an email if there is difference.                                                #
###############################################################################################

# Start User configurable value variable section

my ($FullName, $from, $to, $subject, $strSQL, $DBName, $DBHost, $DBUser, $DBpwd, $TblName, $relay);
my ($verbose, $LogLevel, $LogPath, $TopLines);

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
$sec = substr("0$sec",-2);

$to       = 'Siggi Bjarnason <siggi@majorgeek.us>';
$from     = 'Perl Scripting <perl@majorgeek.us>';
$subject  = "File Statistics Alert $mon/$mday/$year $hour:$min";
$DBHost   = "localhost";
$DBName   = "siggib_FileStats";
$TblName  = "tblFileHistory";
$DBUser   = "siggib_perlscrip";
$DBpwd    = "~AQwBFyIxO?D";
$relay    = "localhost";
$LogPath  = "/home/siggib/siggi/logs";
$verbose  = 0;
$LogLevel = 2;
$TopLines = 1;


###############################################################################################
#End user configurable section.                                                               #
#Begin Script section. Do not modify below unless you know what you are doing.                #
###############################################################################################
use warnings;
use IO::File;
use Getopt::Long;
use Digest::MD5;
use English;
use Sys::Hostname;
use Net::SMTP;
use DBI();

my (@body,$progname, $ShortName, $logfile, $host, $scriptFullName, @tmp, $pathparts, $dir, $BodyLines);
my ($dbh, @fdata, $sth, $bChanged, $OldFileSize, $OldModTime, $OldMD5, $OldAccessTime, $OldLines, $numin);
$host = hostname;
$scriptFullName = $PROGRAM_NAME;
$scriptFullName =~ s/\\/\//g; 

@body = "";
@tmp = split(/\//,$scriptFullName);
$pathparts = scalar @tmp;
$ShortName = $tmp[$pathparts-1];    
($progname) = split(/\./,$ShortName);
$logfile = "$LogPath/$progname.log";
print "Logging to $logfile\n";
open(LOG,">$logfile") || die "cannot open log file $logfile for write: $!";

$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                      "$DBUser", "$DBpwd",
                      {'RaiseError' => 1});

$numin = scalar(@ARGV);
if ($numin < 1)
{
  $dir = ".";
}
else
{
  $dir = $ARGV[0]; 
}
logentry ("You provided path of $dir\n",2,1);
$dir=~s/\\/\//g;
logentry ("Changed it to $dir for conformance\n",2,1);
logentry ("starting $ShortName for $dir at $mon/$mday/$year $hour:$min on $host\n",0,0);
push @body, "<html>\n<head>\n<style type=\"text/css\">\n table.BT { border-collapse:collapse; }\n table.BT td, table.BT th { border:2px solid black;padding:5px; }\n table.BT td.DU, table.BT th.DU { border-bottom-width:3px; border-bottom-style:dashed; text-align:left}\n </style>\n</head>\n<body>\n";
push @body, "<p>$host has completed processing $ShortName for $dir and found the following changes:</p>\n";
push @body, "<table class=\"BT\">\n<tr><th>Status</th><th>File Name</th><th>File Size</th><th>Access Time</th><th>Modification Time</th><th>MD5 Summary</th></tr>\n";
push @body, "<tr><th colspan=\"6\" class=\"DU\">Top $TopLines lines from file</th></tr>\n";
$bChanged = 0;
ScanDir($dir, $bChanged);
push @body, "</body>\n</html>\n";

$BodyLines = @body;
#print "Body: $BodyLines lines\n";
#foreach (@body) {
#  print "$_\n";
#}
logentry ("Done processing\n",0,0);

if (($relay ne "") and ($to ne ""))
{
  if ($BodyLines > 6)
  {
    logentry ("Sending notification email\n",0,0);
    send_mail();
  }
  else
  {
    logentry ("No changes detected\n",0,0);
  }
}
else
{
  logentry ("No SMTP server configured or no notification email provided, can't send email\n",0,0);
}
logentry ("Done!!!\n",0,0);
close (LOG) or warn "error while closing log file $logfile: $!" ;   
exit 0;

sub ScanDir
{
  my ($dir, $bChanged) = @_;
  my ($file, $LineCount, $line, $strTopLines, $bRecReturned, $md5sum, $md5, $dh, $fh);

  if (substr ($dir,-1) ne "/")
  { 
    $dir .= "/";
  }
  opendir($dh, $dir) or die $!;
  while ($file = readdir($dh)) 
  {
    next if ($file =~ m/^\.|^error_log$/);
    $FullName = $dir.$file;
    if (-d $FullName)
    {
      logentry ("$FullName is a directory, recursion time\n",1,2);
      ScanDir($FullName);
    }
    else
    {
      next unless (-T $FullName);
      @fdata = stat($FullName);
      open($fh, $FullName) or die "Error: Could not open $FullName for MD5 checksum";
      binmode($fh);
      $md5 = Digest::MD5->new;
      $md5sum = $md5->addfile(*$fh)->hexdigest; 
      close $fh;
      undef($md5);
      $strTopLines = "";
      if (-T $FullName)
      {
        open(IN,"<",$FullName) || die "cannot open File $FullName for read: $!";
        logentry ("reading from $FullName ...\n",4,3);
        $LineCount = 0;
        $strTopLines = "";
        foreach $line (<IN>)
        {
          $LineCount += 1;
          chomp($line);
          $strTopLines .= substr($line,0,100) . "\n";
          logentry ("collecting top $TopLines lines, on line $LineCount\n",6,6);
          logentry ("Line contains: $line \n",8,8);
          logentry ("strTopLines:\n $strTopLines",7,7);
          if ($LineCount == $TopLines)
          {
            last;
          }
        }
      }
#     $strTopLines = substr($strTopLines,0,100);
      $strTopLines=~s/\'/\'\'/g;
      $strTopLines=~s/\\/\\\\/g;
      $strTopLines=~s/</&lt;/g;
      $strTopLines=~s/>/&gt;/g;
      $strTopLines=~s/\n/<br>\n/g;
      $FullName=~s/\'/\'\'/g;
      $bChanged = 0;
      $strSQL = "SELECT dtTimestamp,vcFileName, iFileSize, iLastAccess, iLastModified, vcMD5Hash, tTopLines
                  FROM tblFileHistory
                  WHERE vcFileName = '$FullName' and dtTimestamp = ( 
                    select MAX(dtTimestamp) FROM tblFileHistory where vcFileName = '$FullName' 
                    );";
      logentry ("$strSQL\n",3,2);
      $bRecReturned = 0;
      $sth = $dbh->prepare($strSQL);
      $sth->execute();
      while (my $ref = $sth->fetchrow_hashref()) 
      {
        $OldFileSize = $ref->{'iFileSize'};
        $OldAccessTime = $ref->{'iLastAccess'};
        $OldModTime = $ref->{'iLastModified'};
        $OldMD5 = $ref->{'vcMD5Hash'};
        $OldLines = $ref->{'tTopLines'};
        $bRecReturned = 1;
      }
      if ($bRecReturned == 1)
      {
        if ($OldFileSize != $fdata[7])
        {
          $bChanged = 1;
        }
        if ($OldModTime != $fdata[9])
        {
          $bChanged = 1;
        }
        if ($OldMD5 ne $md5sum)
        {
          $bChanged = 1;
        }
        if ($bChanged == 1)
        {
#         $OldLines = substr($OldLines,0,100);
          $OldLines=~s/\'/\'\'/g;
          $OldLines=~s/</&lt;/g;
          $OldLines=~s/>/&gt;/g;
          $OldLines=~s/\n/<br>\n/g;
          push @body, "<tr><td>Previous</td><td>$FullName</td><td>$OldFileSize</td><td>" . localtime($OldAccessTime) . "</td><td>" . localtime($OldModTime) ."</td><td>$OldMD5</td></tr>\n";        
          push @body, "<tr><td colspan=\"6\">$OldLines</td></tr>\n";      
          push @body, "<tr><td>Current</td><td>$FullName</td><td>$fdata[7]</td><td>" . localtime ($fdata[8]) . "</td><td>" . localtime($fdata[9]) . "</td><td>$md5sum</td></tr>\n"; 
          push @body, "<tr><td colspan=\"6\" class=\"DU\">$strTopLines</td></tr>\n";
        }
      }
      else
      {
          push @body, "<tr><td>New</td><td>$FullName</td><td>$fdata[7]</td><td>" . localtime ($fdata[8]) . "</td><td>" . localtime($fdata[9]) . "</td><td>$md5sum</td></tr>\n"; 
          push @body, "<tr><td colspan=\"6\" class=\"DU\">$strTopLines</td></tr>\n";      
        }       
      $strSQL = "INSERT INTO tblFileHistory (dtTimestamp, vcFileName, iFileSize, iLastAccess, iLastModified, vcMD5Hash, tTopLines)";
      $strSQL .= "VALUES (now(), '$FullName',$fdata[7], $fdata[8], $fdata[9], '$md5sum', '$strTopLines');";
      logentry ("$strSQL\n",3,2);
      $dbh->do($strSQL);      
      logentry ("$FullName, $fdata[7], $fdata[8], $fdata[9], $md5sum\n",3,2);
    }
  }
  closedir($dh);
}

sub send_mail 
{
  if ($host ne "WABELHLP0567730")
  {
    my ($smtp, $body);
    $smtp = Net::SMTP->new($relay, Debug => 0); # Set Debug to 1 if you have any problems
    if (!defined($smtp))
    {
      logentry ("Failed to open mail session to $relay\n");
      close (LOG) or warn "error while closing log file $logfile: $!" ;   
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
      $smtp->datasend("Content-Type: text/html; charset=ISO-8859-1\n");
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
  else
  {
    logentry ("Can't send email while testing on $host\n",0,0);
  }
} 

sub logentry
  {
    my($outmsg, $ConLevel, $FileLevel) = @_;
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year = $year+1900;
    $min = substr("0$min",-2);
    $mon = $mon + 1;
    $sec = substr("0$sec",-2);
    
    if ($ConLevel <= $verbose)
    {
      print "$mon/$mday/$year $hour:$min:$sec $outmsg";
    }
    if ($FileLevel <= $LogLevel)
    {
      print LOG "$mon/$mday/$year $hour:$min:$sec $outmsg";
    }
  }
  
