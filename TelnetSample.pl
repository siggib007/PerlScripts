#!/perl/bin/perl
use Net::Telnet 3.00;
alarm(300);
$workdir = "/";
chdir($workdir);
$login = "";
$prompt = "/\>/";
open DATAFILE, "<$workdir/dbfile.db";
foreach $line (<DATAFILE>)
{
chomp($line);
@split = split/:/, $line;
$dbhash{@split[0].@split[1].@split[2]}=$line;
}

close(DATAFILE);

$password ="";

chomp($password);
$hostname = @ARGV[0];
$hostip = @ARGV[1];
sub login()
{
$t = Net::Telnet->new(  Timeout => 150,
                        Prompt=> '/sername:/',
                        Host => $hostip,
                        Errmode => 'return',
                       
                        );

$t->open();
$t->prompt('/assword/');
$t->cmd("$login");
$t->prompt('/>/');
$t->cmd("$password");
}
login();

$t->cmd("terminal length 0");
@build = $t->cmd("show ip bgp sum");
foreach $line (@build)
{

$as = $1 if ($line =~/local AS number\S+(\s+)/);

   if ($line =~/(\S+\.\S+\.\S+\.\S+)\s+4\s+(\S+)/)
   {
   $hash{$2}->{as} = $2;
   $as = $2;
   $intip = $1;      

       @routing = $t->cmd("show ip route $1");
          foreach $newline (@routing)
          {
          $knownvia = "static" if ($newline =~ /static/);
         
                if (($newline =~ /(\S+\.\S+\.\S+\.\S+)/) and ($knownvia eq "static"))
		{
                
                @output = $t->cmd("show ip route $1");
                  
                     foreach $nextline (@output)
                     {
                      
		      push @{$hash{$as}->{ints}}, $1 if ($nextline =~/directly connected\,\s+via\s+(\S+)/);
                      
                     }
               
		}

             if ($newline =~/directly connected\,\s+via\s+Vlan(\S+)/)
             {
             @output = $t->cmd("show vlan id $1");
             $vlan = $1;
              
                     foreach $newnewline (@output)
                     {
 			if ($newnewline =~ /active\s+(\S+)/)
           		{
                        $hashvlan{$hostip."Vlan".$vlan} = $1;
                       
                     	}
                     }
             }

            
             push @{$hash{$as}->{ints}}, $1 if ($newline =~/directly connected\,\s+via\s+(\S+)/);
            
           
          }  
         $knownvia = "unk";   
       
   }
}

foreach $line (keys %hash)
{

  foreach $newline (@{$hash{$line}->{ints}})
  {
  
     @showip = $t->cmd("show ip int $newline");
     foreach $nextline (@showip)
     {   
     push @{$hash{$line}->{ips}}, $1.":$newline" if ($nextline =~ /is\s+(\S+\.\S+\.\S+\.\S+)\//);
     push @{$hash{$line}->{acls}}, $1.":$newline" if ($nextline =~ /Inbound\s+access\s+list\s+is\s+(\S+)/);
     }
  }
}

open ACLs, ">>aclstuff.db";

foreach $line (keys %hash)
{

  foreach $newline (@{$hash{$line}->{ips}})
  {
  @split = split/\:/, $newline;
  $dbhash{$line.$hostip.@split[0]} = "$line:$hostip:$newline:$hostname:$hashvlan{$hostip.@split[1]}:"
  }

  foreach $newline (@{$hash{$line}->{acls}})
  {
  print ACLs "$line $hostip @split[0] $newline\n";
  }


}

close ACLs;

$t->close();
open DBFILE, ">$workdir/dbfile.db";
foreach $line (keys %dbhash)
{
print DBFILE $dbhash{$line}."\n";

}
close DBFILE;
exit;
