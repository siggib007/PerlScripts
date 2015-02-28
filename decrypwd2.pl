#!/usr/bin/perl -w
# $Id: cisco.passwords.html 1799 2003-05-08 20:33:12Z fyodor $
#
# Credits for orginal code and description hobbit@avian.org,
# SPHiXe, .mudge et al. and for John Bashinski <jbash@CISCO.COM>
# for Cisco IOS password encryption facts.
#
# Use for any malice or illegal purposes strictly prohibited!
#
use strict;
use Win32::ODBC;

my ($dirname,%pwd,%dclist,$dcpwd,$outfile,$FileName,$FilePath,$dp,$e,$ep,$file,$i,$input,$s,$section,$status,$key,$device);
my ($O,$sqlQuery,%sqlData, $pwdtype, $DC);
my @xlat = ( 0x64, 0x73, 0x66, 0x64, 0x3b, 0x6b, 0x66, 0x6f, 0x41,
          0x2c, 0x2e, 0x69, 0x79, 0x65, 0x77, 0x72, 0x6b, 0x6c,
          0x64, 0x4a, 0x4b, 0x44, 0x48, 0x53 , 0x55, 0x42 );
my $defpwdname = "Standard";
$dclist{$defpwdname} = "All Production DC's";
$dclist{"Remote"} = "Radio Stations;Shanghai - CNC IDC; Shanghai - Metro";
#print @ARGV, "\n";
#$dirname = 'D:/TrueControl/';
#print "1: $ARGV[0]\n";
#print "2: $ARGV[1]\n";

my $numin = scalar(@ARGV);
if ($numin != 2)
	{
		print "Two arguments are required in this order:\n";
		print "usage: decrypwd2.pl dirname logfile\n\n";
		print "dirname: the complete path of the config file directory. Ex: D:/TrueControl/\n";
		#print "pwd: The correct password to compare against.\n";
		print "logfile: filename with complete path of where you want the results saved. Ex: y:/tools/pwdstat.csv \n";
		exit();
	}

$dirname = $ARGV[0]; #'h:/netpro/';
#$pwd = $ARGV[1];
$outfile = $ARGV[1];#"y:/tools/pwdstat.txt";
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
#print "Dirname = $dirname\n";

if (-e $outfile) 
{
	print "The output file $outfile does exists. \n";
	print "Would you like to overwrite it? (anything but yes will abort) ";
	chop($input =<STDIN>);
	#print "your answer was: *$input*\n";
	if ($input !~ /^y/i) 
	{
		print "OK Exiting\n";
		exit;
	}
}

#print "Please enter the standard password: ";
#chop($input=<STDIN>);
foreach $key (keys %dclist)
{
	print "Please enter the password for $key datacenter: ";
	chop($pwd{$key}=<STDIN>);
}

#foreach $key (keys %dclist)
#{
#	print "DCType: $key \t DC: $dclist{$key} \t pwd:$pwd{$key}\n";
#}
#exit;	
if (!($O = new Win32::ODBC("driver=sql Server;server=satnetengfs01;UID=readonly;PWD=readonly;"))){
	print 'Error: ODBC Open Failed: ',Win32::ODBC::Error(),"\n";
	die "  Open configAccessDB: ".Win32::ODBC::Error();
}

open(OUTFILE,">$outfile") or die "Can't open $outfile $!";
print OUTFILE "DeviceName;DataCenter;DCType;Results\n";
opendir(DIR,$dirname) or die "can not opendir $dirname: $!";
while (defined($FileName=readdir(DIR))) 
	{
		if ($FileName=~/conf$/)
			{
				($file) = split /\./, $FileName;
				$sqlQuery = "select datacentername from reports.dbo.NetInvList where DeviceName = '$file'";
				
				if (! $O->Sql($sqlQuery)) 
				{
					$O->FetchRow();
					%sqlData = $O->DataHash();
					$DC = $sqlData{datacentername};
				}
				$DC = "UNKNONW" if !$DC;
				$pwdtype = $defpwdname;
				foreach $key (keys %dclist)
				{
					if ($dclist{$key} =~/$DC/i)
					{
						$pwdtype = $key
					}
				}
				$status = "OK";
				$section = "other";
				$FilePath = $dirname.$FileName;
				$dcpwd = $pwd{$pwdtype};
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
						            if ($dp ne $dcpwd)
						            	{
						            		$status = $ep;
						            	}
						        }
						        #print;
						   }
					}
				close(F) || die "close: $!";
            $device = "$file; $DC; $pwdtype";
            if ($status eq "OK")
            	{
            		print $device . " is OK\n";
            		print OUTFILE "$device;OK\n";
            	}
            else
            	{
            		print $device . " has the wrong password\n";
            		print OUTFILE "$device;FAILED\n";
            	}
			}
	}
closedir(DIR);
$O->Close();

# eof
