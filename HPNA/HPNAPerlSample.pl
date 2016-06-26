#!/usr/bin/perl


$dir    = "./";
opendir(myDir, $dir) || die ("Cannot open directory");
@files=readdir(myDir);
closedir (myDir);

foreach $file (@files) {
  if ($file =~ /.txt/) {
    &config_check($file);
  }
} 

sub config_check {
  open (config, "$file");
  $ospf = 0;
  @sections = <config>;
  foreach $section (@sections) {
    $line = $section;
    if ($line =~ /router ospf [0-9]+/) {
      #print "$line";
      $ospf = 1;
    }
    elsif ($ospf == 1 && $line !~ /!/) {
      #print "$line";
      if ($line =~ /redistribute connected/) {
        print "***** redistribute connected DETECTED in file $file****\n";
      }
    }
    elsif ($line =~ /!/) {
      $ospf = 0;
    }
  }
}
