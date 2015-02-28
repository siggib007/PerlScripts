use File::stat;
use Time::localtime;
$DNSDumpFile = "/var/tmp/siggib_sgb.sql";

my $epoch_timestamp = (stat($DNSDumpFile))[9];
print $epoch_timestamp;

#my $timestamp = ctime(stat($DNSDumpFile)->mtime);
#print $timestamp;