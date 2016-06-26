use Socket;

    ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire) = getpw*
    print "getpw results:\n";
    print "name: $name\n";
    print "pwd: $passwd\n";
    print "uid: $uid\n";
    print "gid: $gid\n";
    print "quota: $quota\n";
    print "comment: $comment\n";
    print "gcos: $gcos\n";
    print "dir: $dir\n";
    print "shell: $shell\n";
    print "expire: $expire\n";
    print "---------------------------\n";
    ($name,$passwd,$gid,$members) = getgr*
    print "\ngetgr results:\n";
    print "name: $name\n";
    print "pwd: $passwd\n";
    print "gid: $gid\n";
    print "members: $members\n";
    print "---------------------------\n";
    ($name,$aliases,$addrtype,$length,@addrs) = gethost*
    print "\ngethost results:\n";
    print "name: $name\n";
    print "aliases: $aliases\n";
    print "addrtype: $addrtype\n";
    print "length: $length\nAddresses:\n";
    foreach $addr (@addrs)
    	{
    		print "$addr\n";
    	}
    print "---------------------------\n";
    ($name,$aliases,$addrtype,$net) = getnet*
    print "\ngetnet results:\n";
    print "name: $name\n";
    print "aliases: $aliases\n";
    print "addrtype: $addrtype\n";    
    print "net: $net\n"; 
    print "---------------------------\n";
    ($name,$aliases,$proto) = getproto*
    print "\ngetproto results:\n";
    print "name: $name\n";
    print "aliases: $aliases\n";
    print "proto: $proto\n";    
    print "---------------------------\n";
    ($name,$aliases,$port,$proto) = getserv*
    print "\ngetserv results:\n";
    print "name: $name\n";
    print "aliases: $aliases\n";
    print "port: $port\n";    
    print "proto: $proto\n";    
    print "---------------------------\n";
    
    $packed_ip = gethostbyname("seaingw");
    if (defined $packed_ip) 
    	{
        $ip_address = inet_ntoa($packed_ip);
    	}
    else
    	{
    		print "Unable to resolve\n";
    	}
    print "packedIP: $packed_ip\n";
    print "IP Addr: $ip_address\n";
    $iaddr = inet_aton($ip_address);
    $name  = gethostbyaddr($iaddr, AF_INET);
    print "iaddr: $iaddr\n";
    print "host addr: $name\n";