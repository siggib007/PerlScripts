$a=0x4500;
$b=0x003c;
print "Adding $a and $b\n";
$c = $a + $b;
$d = "0x" . hex($c);
print "result = $c\nin hex: $d\n";