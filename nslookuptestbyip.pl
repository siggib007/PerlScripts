use Socket;
use Net::Ping::External qw(ping);

    $ip_address = $ARGV[0];
   	$iaddr = inet_aton($ip_address);
   	$name  = gethostbyaddr($iaddr, AF_INET);
    if (defined $name) 
    {
		  print "host addr: $name\n";
		}
    else
    {
    	print "Unable to resolve\n";
    }
		  
		if ($name ne "")
		{
			$alive = ping(host => $ip_address);
		}
		else
		{
			$alive = 0;
		}
		if ($alive)
		{
			print "host is pingable $alive\n";
		}
		else
		{
			print "host is not pingable\n";
		}

