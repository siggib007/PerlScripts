print "Gimme a number in decimal, octal, or hex: ";
$num = <STDIN>;
chomp $num;
exit unless defined $num;
$num = oct($num) if $num =~ /^0/; # does both oct and hex
printf "%d %x %o\n", $num, $num, $num;
