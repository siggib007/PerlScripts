use Socket;
use Net::Ping::External qw(ping);

    $packed_ip = gethostbyname($ARGV[0]);
    if (defined $packed_ip) 
    	{
        $ip_address = inet_ntoa($packed_ip);
    		print "IP Addr: $ip_address\n";
    		$iaddr = inet_aton($ip_address);
    		$name  = gethostbyaddr($iaddr, AF_INET);
		    print "host addr: $name\n";
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
		}
    else
    	{
    		print "Unable to resolve\n";
    	}
