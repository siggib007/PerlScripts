#!/usr/bin/perl -w
# $Id: cisco.passwords.html 1799 2003-05-08 20:33:12Z fyodor $
#
# Credits for orginal code and description hobbit@avian.org,
# SPHiXe, .mudge et al. and for John Bashinski <jbash@CISCO.COM>
# for Cisco IOS password encryption facts.
#
# Use for any malice or illegal purposes strictly prohibited!
#

@xlat = ( 0x64, 0x73, 0x66, 0x64, 0x3b, 0x6b, 0x66, 0x6f, 0x41,
          0x2c, 0x2e, 0x69, 0x79, 0x65, 0x77, 0x72, 0x6b, 0x6c,
          0x64, 0x4a, 0x4b, 0x44, 0x48, 0x53 , 0x55, 0x42 );

#print @ARGV, "\n";
#$dirname = 'D:/TrueControl/';
#print "1: $ARGV[0]\n";
#print "2: $ARGV[1]\n";

$numin = scalar(@ARGV);
if ($numin != 3)
	{
		print "Three arguments are required in this order:\n";
		print "usage: decrypwd.pl dirname pwd logfile\n\n";
		print "dirname: the complete path of the config file directory. Ex: D:/TrueControl/\n";
		print "pwd: The correct password to compare against.\n";
		print "logfile: filename with complete path of where you want the results saved. Ex: y:/tools/pwdstat.csv \n";
		exit();
	}

$dirname = $ARGV[0]; #'h:/netpro/';
$pwd = $ARGV[1];
$outfile = $ARGV[2];#"y:/tools/pwdstat.txt";
while ($dirname=~/\\/)
{
	$dirname=~s/\\/\//;
}
while ($outfile=~/\\/)
{
	$outfile=~s/\\/\//;
}

if ($dirname !~/\/$/)
	{
		$dirname .= "/";
	}
print "Dirname = $dirname\n";
	
open(OUTFILE,">$outfile") or die "Can't open $outfile $!";
opendir(DIR,$dirname) or die "can not opendir $dirname: $!";
while (defined($FileName=readdir(DIR))) 
	{
		if ($FileName=~/conf$/)
			{
				$status = "OK";
				$section = "other";
				$FilePath = $dirname.$FileName;
				#print $FilePath, "\n";
				#$FileName = 'H:\NetPro\bay-6nb-5a.conf';
				open(F, $FilePath) || die "open: $FilePath $!";
				while (<F>) 
					{
				   	if ($_ eq "line con 0\n") 
				   		{
				   			$section = "Line";
				   			#print "found the line section \n";
				   		}
				   	else 
				   		{
				   			#print $_;
				   		}
				   	if ($section eq "Line") 
				   		{
						   	if (/(password|md5)\s+7\s+([\da-f]+)/io) 
						        	{
						            if (!(length($2) & 1)) 
						            	{
												$ep = $2; $dp = "";
												($s, $e) = ($2 =~ /^(..)(.+)/o);
												for ($i = 0; $i < length($e); $i+=2) {
												  $dp .= sprintf "%c",hex(substr($e,$i,2))^$xlat[$s++];
												}
												s/7\s+$ep/$dp/;
						            	}
						            #print $dp, "\n";
						            if ($dp ne $pwd)
						            	{
						            		$status = $ep;
						            	}
						        }
						        #print;
						   }
					}
				close(F) || die "close: $!";
				($file) = split /\./, $FileName;
            if ($status eq "OK")
            	{
            		print $FileName . " is OK\n";
            		print OUTFILE "$file,OK\n";
            	}
            else
            	{
            		print $FileName . " has the wrong password\n";
            		print OUTFILE "$file,FAILED\n";
            	}
			}
	}
closedir(DIR);

# eof
