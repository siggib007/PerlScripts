#!/usr/bin/perl -w

use strict;
use RRDs;

# this data structure drives which devices get polled for what reports
my %devlist;
%devlist = (
	Messenger => {
		"6500s"	=> [
			"Bay-6nx-msgr-1a",
			"Bay-6nx-msgr-1b",
			"Bay-6nx-msgr-2a",
			"Bay-6nx-msgr-2b",
			"Bay-6nx-msgr-3a",
			"Bay-6nx-msgr-3b",
			"Bay-6nx-msgr-4a",
			"Bay-6nx-msgr-4b",
			"Bay-6nx-msgr-5a",
			"Bay-6nx-msgr-5b",
			"By2-6nx-msgr-1a",
			"By2-6nx-msgr-1b",
			"By2-6nx-msgr-2a",
			"By2-6nx-msgr-2b",
			"Blu-65x-msgr-2-06",
			"Blu-65x-msgr-2-05"
			],
		F5s	=> [
			"Bay-f6f-msgr-1a",
			"Bay-f6f-msgr-1b",
			"Bay-f6f-msgr-2a",
			"Bay-f6f-msgr-2b",
			"Bay-f6b-msgr-2a",
			"Bay-f6b-msgr-2b",
			"Bay-f6f-msgr-3a",
			"Bay-f6f-msgr-3b",
			"Bay-f6b-msgr-3a",
			"Bay-f6b-msgr-3b",
			"Bay-f6f-msgr-4a",
			"Bay-f6f-msgr-4b",
			"Bay-f6b-msgr-4a",
			"Bay-f6b-msgr-4b",
			"Bay-f6f-msgr-5a",
			"Bay-f6f-msgr-5b",
			"Bay-f6b-msgr-5a",
			"Bay-f6b-msgr-5b",
			"By2-f6f-msgr-1a",
			"By2-f6f-msgr-1b",
			"By2-f6b-msgr-1a",
			"By2-f6b-msgr-1b",
			"By2-f6b-msgr-1c",
			"By2-f6b-msgr-1d",
			"By2-f6f-msgr-2a",
			"By2-f6f-msgr-2b",
			"By2-f6b-msgr-2a",
			"By2-f6b-msgr-2b",
			"By2-f6b-msgr-2c",
			"By2-f6b-msgr-2d"
			]
		}
);


# devlist:
# %devlist{Property}{6500s || F5s}[host1, ...]

my $rrdbasepath = "\\\\phx.gbl\\public\\MSN_Ops_Tools\\crickethome\\cricket-data\\";

my %DCList = (
	bay	=> "dc-SJ-Metro\\bay\\",
	bl2	=> "dc-VA-Metro\\bl2\\",
	blu	=> "dc-VA-Metro\\blu\\",
	by2	=> "dc-SJ-Metro\\by2\\",
	tuk	=> "dc-PS-Metro\\tuk\\",
	tuk2	=> "dc-PS-Metro\\tuk\\",
	tuk2f	=> "dc-PS-Metro\\tuk\\"
);

# put the polling interval on a 2 hour boundary
my $rrdendtime = int(time() / 7200) * 7200;

my $dirname = "reports-$rrdendtime";
mkdir($dirname);

foreach (sort keys %devlist) {
	my $property = $_;
	print STDOUT "\n\n*** $property ***\n";

	open(REPORT, ">$dirname/${property}.csv");
	select(REPORT);

	print("\"$property\",\"85-100 percentile peak averages for one month ending: ", scalar localtime($rrdendtime), "\"\n");

	print STDOUT "\n6500s:\n";

	print("\"6500s:\"\n\"Host\",\"CPU Utilization\",\"Used Memory (MB)\",\"Free Memory (MB)\"\n");
	my $routers = $devlist{$property}{"6500s"};
	foreach (sort @$routers) {
		# 6500 stats include CPU, MEM, and throughput
		my $host = $_;
		$host =~ tr/A-Z/a-z/;

		print STDOUT "Processing $host ...\n";
		print("\"$host\",");

		my @hostfields = split(/-/, $host);
		my $rrdpath = $rrdbasepath . $DCList{$hostfields[0]} . "routers\\$host\\";

		if (getcpumem($rrdpath . "system.rrd") == -1) {
			print("\"NO DATA: $host\\system.rrd\",\"\",\"\"\n");
		}
	}

	print STDOUT "\nF5s:\n";
	print("\n\"F5s:\"\n\"Host\",\"Client Mbit/s\",\"Server Mbit/s\",\"Client Connections\",\"Server Connections\",\"TMM Utilization\"\n");
	my $SLBs = $devlist{$property}{F5s};
	foreach (sort @$SLBs) {
		# F5 stats include CPU, Active Connections, and throughput
		my $host = $_;
		$host =~ tr/A-Z/a-z/;

		print STDOUT "Processing $host ...\n";
		print("\"$host\",");

		my @hostfields = split(/-/, $host);
		my $rrdpath = $rrdbasepath . $DCList{$hostfields[0]} . "generics\\$host\\";

		if (getsysstat($rrdpath . "SystemStats\\${host}-sysstat.rrd") == -1) {
			print("\"NO DATA: ${host}-sysstat.rrd\",\"\",\"\",\"\",\"\"\n");
		}

	}

	print STDOUT "\nReport for $property written to $dirname\n";

	close(REPORT);
}


sub getsysstat
{
	my $selectedRRD = $_[0];

	my ($start,$step,$names,$data) = RRDs::fetch
						("$selectedRRD",
						'AVERAGE',
						'-r', "2h",
						'-e', $rrdendtime,
						'-s', "e-1m" );

	if ($#$data == -1) {
		return -1;
	}

	my(@cliBytes, @cliCurConns, @srvBytes, @srvCurConns, @tmmUtil);

	foreach my $line (@$data) {
		my ($cliBytesIn, $cliBytesOut, $cliCurConns, $srvBytesIn, $srvBytesOut, $srvCurConns, $tmmCycleTotal, $tmmCycleIdle) = ($$line[1], $$line[3], $$line[6], $$line[8], $$line[10], $$line[13], $$line[39], $$line[40]);

	
		($cliBytesIn && $cliBytesOut && $cliCurConns && $srvBytesIn && $srvBytesOut && $srvCurConns && $tmmCycleTotal && $tmmCycleIdle) || next;

		# TMM Utilization percent is computed on the fly
		my($tmmUtil) = (1 - ($tmmCycleIdle / $tmmCycleTotal)) * 100;

		# ok so I named it Bytes cuz that's what the rrd gives us but i'm converting it to Mbits here
		push(@cliBytes, ($cliBytesIn + $cliBytesOut) * 8 / 1024 / 1024);
		push(@cliCurConns, $cliCurConns);
		push(@srvBytes, ($srvBytesIn + $srvBytesOut) * 8 / 1024 / 1024);
		push(@srvCurConns, $srvCurConns);
		push(@tmmUtil, $tmmUtil);
	}

	my($cliBytesMean, $cliConnMean, $srvBytesMean, $srvConnMean, $tmmUtilMean);

	if ($#cliBytes == -1) {
		$cliBytesMean = 0;
	} else {
		$cliBytesMean = getMean(@cliBytes);
	}

	if ($#cliCurConns == -1) {
		$cliConnMean = 0;
	} else {
		$cliConnMean = getMean(@cliCurConns);
	}

	if ($#srvBytes == -1) {
		$srvBytesMean = 0;
	} else {
		$srvBytesMean = getMean(@srvBytes);
	}

	if ($#srvCurConns == -1) {
		$srvConnMean = 0;
	} else {
		$srvConnMean = getMean(@srvCurConns);
	}

	if ($#tmmUtil == -1) {
		$tmmUtilMean = 0;
	} else {
		$tmmUtilMean = getMean(@tmmUtil);
	}

	my($cliBytesDev, $cliConnDev, $srvBytesDev, $srvConnDev, $tmmUtilDev) = (0, 0, 0, 0, 0);

	if ($cliBytesMean != 0) {
		$cliBytesDev = getStdDev($cliBytesMean, @cliBytes);
		$cliBytesMean = get85pctMean($cliBytesMean + $cliBytesDev, @cliBytes);
	}

	if ($cliConnMean != 0) {
		$cliConnDev = getStdDev($cliConnMean, @cliCurConns);
		$cliConnMean = get85pctMean($cliConnMean + $cliConnDev, @cliCurConns);
	}

	if ($srvBytesMean != 0) {
		$srvBytesDev = getStdDev($srvBytesMean, @srvBytes);
		$srvBytesMean = get85pctMean($srvBytesMean + $srvBytesDev, @srvBytes);
	}

	if ($srvConnMean != 0) {
		$srvConnDev = getStdDev($srvConnMean, @srvCurConns);
		$srvConnMean = get85pctMean($srvConnMean + $srvConnDev, @srvCurConns);
	}

	if ($tmmUtilMean != 0) {
		$tmmUtilDev = getStdDev($tmmUtilMean, @tmmUtil);
		$tmmUtilMean = get85pctMean($tmmUtilMean + $tmmUtilDev, @tmmUtil);
	}

	printf("\"%0.2f\",\"%0.2f\",\"%0.2f\",\"%0.2f\",\"%0.2f%%\"\n", $cliBytesMean, $srvBytesMean, $cliConnMean, $srvConnMean, $tmmUtilMean);
}


sub getcpumem
{
	my $selectedRRD = $_[0];

	my ($start,$step,$names,$data) = RRDs::fetch
						("$selectedRRD",
						'MAX',
						'-r', "2h",
						'-e', $rrdendtime,
						'-s', "e-1m" );

	if ($#$data == -1) {
		return -1;
	}

	my(@cpu5min, @memused, @memfree);

	foreach my $line (@$data) {
		my ($cpu5min, $memused, $memfree) = ($$line[1], $$line[2], $$line[3]);

		($cpu5min && $memused && $memfree) || next;

		# B -> MB
		$memused = $memused / 1024 / 1024;
		$memfree = $memfree / 1024 / 1024;

		push(@cpu5min, $cpu5min);
		push(@memused, $memused);
		push(@memfree, $memfree);
	}

	my ($cpu5minMean, $memUsedMean, $memFreeMean);
	if ($#cpu5min == -1) {
		$cpu5minMean = 0;
	} else {
		$cpu5minMean = getMean(@cpu5min);
	}

	if ($#memused == -1) {
		$memUsedMean = 0;
	} else {
		$memUsedMean = getMean(@memused);
	}

	if ($#memfree == -1) {
		$memFreeMean = 0;
	} else {
		$memFreeMean = getMean(@memfree);
	}

	my($cpu5minDev, $memUsedDev, $memFreeDev) = (0, 0, 0);

	if ($cpu5minMean != 0) {
		$cpu5minDev = getStdDev($cpu5minMean, @cpu5min);
		$cpu5minMean = get85pctMean($cpu5minMean + $cpu5minDev, @cpu5min);
	}

	if ($memUsedMean != 0) {
		$memUsedDev = getStdDev($memUsedMean, @memused);
		$memUsedMean = get85pctMean($memUsedMean + $memUsedDev, @memused);
	}

	if ($memFreeMean != 0) {
		$memFreeDev = getStdDev($memFreeMean, @memfree);
		$memFreeMean = get85pctMean($memFreeMean + $memFreeDev, @memfree);
	}

	printf("\"%0.2f%%\",\"%0.2f\",\"%0.2f\"\n", $cpu5minMean, $memUsedMean, $memFreeMean);
}


# simple arithmetic mean of array members
sub getMean {
	my @values = @_;
	my $sum = 0;

	foreach (@values) {
		$sum += $_;
	}

	return $sum / ($#values + 1);
}


# standard deviation: first array member is the mean
sub getStdDev {
	my @values = @_;
	my $mean = shift(@values);
	my $sum = 0;

	foreach (@values) {
		$sum += ($_ - $mean) ** 2;
	}

	return sqrt($sum / ($#values + 1));
}


# gets the arithmetic mean of all array members greater than the first element
# the first element should be the whole set's arithmetic mean + 1 standard deviation
sub get85pctMean {
	my @values = @_;
	my $limit = shift(@values);

	my @val85;
	foreach(@values) {
		$_ > $limit && push(@val85, $_);
	}

	$#val85 == -1 && return($limit);

	my $sum = 0;

	foreach (@val85) {
		$sum += $_;
	}

	return $sum / ($#val85 + 1);
}

