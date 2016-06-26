#!/usr/bin/perl

    use strict;
    use warnings;
    my ($atime, $mtime, @fdata);
    
    my $dir = 'C:/scripts/PerlScript/sysuptime';

    opendir(DIR, $dir) or die $!;

    while (my $file = readdir(DIR)) {

        # Use a regular expression to ignore files beginning with a period
        next if ($file =~ m/^\./);
        #print "$file\n";
        #($atime, $mtime) = (stat ($dir.'/'.$file) )[7, 8,9];
        @fdata = stat($dir.'/'.$file);
        print "$file, $fdata[7], $fdata[8], $fdata[9]\n";
        #print "$file, " . localtime($atime) . ", " . localtime($mtime) . "\n";
    }

    closedir(DIR);
    exit 0;