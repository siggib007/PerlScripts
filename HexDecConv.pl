    $int = 0xac1040fe;
    $dec = sprintf("%d", $int);
    print $int;
    print $dec;
    $int = hex("ac");
    $dec = sprintf("%d", $int);  
    print $int;
    print $dec;

$int = int('AC');
print "\n$int\n";

$IPAddr = '0xac1040fe' . chr(0);;
$dotdec = hex(substr($IPAddr,2,2)) . '.' . hex(substr($IPAddr,4,2)) . '.' . hex(substr($IPAddr,6,2)) . '.' . hex(substr($IPAddr,8,2));
print "\n$dotdec\n";
$dotdec =~ s/\./\'/g;
print "\n$dotdec\n";
$dotdec =~ s/\'/./g;
$dotdec .= chr(0);
print "\n$dotdec;\n";
$dotdec =~ s/\0//g;
chomp $dotdec;
print "\n$dotdec;\n";

