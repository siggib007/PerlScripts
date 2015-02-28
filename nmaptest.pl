 use Nmap::Parser;

 my $np = new Nmap::Parser;
 my @hosts = @ARGV; #get hosts from cmd line

 #runs the nmap command with hosts and parses it automagically
 $np->parsescan("C:/Program Files (x86)/Nmap/nmap",'-sS O -p 1-1023',@hosts);

 for my $host ($np->all_hosts()){
        print $host->hostname."\n";
        #do mor stuff...
 }