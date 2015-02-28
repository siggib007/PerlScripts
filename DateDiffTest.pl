use Date::Calc qw(Add_Delta_Days);

$dtLastRun = "2011-03-09";
$iDayInterval = 3;
$Today = "2011-03-11";
$iToday = "20110311";

#($lrYear,$lrMonth,$lrDay) = split /-/,$dtLastRun ;
#($nrYear,$nrMonth,$nrDay) = Add_Delta_Days($lrYear,$lrMonth,$lrDay,$iDayInterval);
($nrYear,$nrMonth,$nrDay) = Add_Delta_Days(split (/-/,$dtLastRun),$iDayInterval);
#$dtNextRun = join("-",$nrYear,$nrMonth,$nrDay);
#$dtNextRun = sprintf("%02s-%02s-%02s",$nrYear,$nrMonth,$nrDay);
#$iNextRun = sprintf("%02s%02s%02s",$nrYear,$nrMonth,$nrDay);
$dtNextRun = sprintf("%02s-%02s-%02s",Add_Delta_Days(split (/-/,$dtLastRun),$iDayInterval));
$iNextRun = sprintf("%02s%02s%02s",Add_Delta_Days(split (/-/,$dtLastRun),$iDayInterval));
print "Today is $Today, Last Run is $dtLastRun, Next Run is $dtNextRun\n";
print "Numerical Today $iToday and numerical next run is $iNextRun\n";
if ($dtNextRun eq $Today)
{
	print "Today is the day to do the Run\n";
}
else
{
	print "Today is not the day to do the Run\n";
}

if ($iNextRun <= $iToday)
{
	print "Running is due or overdue\n";
}
else
{
	print "Running is not yet due\n";
}