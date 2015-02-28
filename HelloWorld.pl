print "Hello $ARGV[0] World\n";
$numin = scalar(@ARGV);
print "There were $numin arguments passed in\n";
while ($ARGV[1]=~/\\/)
{
	$ARGV[1]=~s/\\/\//;
}
print "static in 1 $ARGV[1]\n";
print "static in 2 $ARGV[2]\n";
print "static in 3 $ARGV[3]\n";
print "static in 4 $ARGV[4]\n";
print "static in 5 $ARGV[5]\n";
$i=0;
foreach $Input (@ARGV)
{
	print "input $i : $Input \n";
	$Input=~s/\\/\//g;
	print "cleaned input $i : $Input \n";
	$i++;
}
print "Enter you name: ";
$line = <STDIN>;
print "Hello $line \nPlease enter your non echo string: ";

use Term::ReadKey;

ReadMode('noecho');
$nonEcho = ReadLine(0);
chomp $password;
ReadMode 'normal';
print "\nYou entered: $nonEcho \n";