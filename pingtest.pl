 use Net::Ping::External qw(ping);
use File::Basename;
$scriptName = basename($0);

  # Ping a single host
  my $hostname = "seavvas001w02";
  my $alive = ping(host => $hostname);
  print "$hostname is online according to $scriptName\n" if $alive;
print "update inventory.dbo.tbldevices set vcIPAddress = '', vcDNSName = '$hostname', dtLastUpdated = getdate(), dtLastUpdatedBy = '$scriptName', dtLastReached = getdate() where ideviceid = -55\n";