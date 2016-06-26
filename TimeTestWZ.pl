$ENV{TZ} = 'America/Los_Angeles';
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = $year+1900;
$min = substr("0$min",-2);
$mon = $mon + 1;
print "$mon/$mday/$year $hour:$min:$sec";