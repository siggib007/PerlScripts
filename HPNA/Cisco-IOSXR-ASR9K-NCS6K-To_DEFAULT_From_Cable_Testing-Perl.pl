#!/usr/bin/perl
# Set port config to default from "Auto_Cable_Test" for ASR9K/NCS6K (IOS-XR)
# Zach Denton 2015/02/04 - Expand configurable ports to HundredGigE for NCS6K
#  Created by Zach Denton 4/22/2014 (copy from 49xx default Auto_Cable_Test script)

use strict;
use warnings;
use Getopt::Long;
use Opsware::NAS::Connect;

# Start main 
# HP NA connections
my($host, $port, $user, $pass) = ('localhost','$tc_proxy_telnet_port$','$tc_user_username$','$tc_user_password$');
my $device = '#$tc_device_id$';
my $con = Opsware::NAS::Connect->new(-user => $user, -pass => $pass, -host => $host, -port => $port);

# My personal Variables
my @output;
my $prompt = qr/\#/m;
my @results ="";

$con->login();
$con->connect( $device , $prompt ) or die "Failed to connect.";

@results = $con->cmd("show run interface $Interface$\n");
if (validate_filter(@results) == -1 ) 
{
  print "The port $Interface$ does not match filter criteria (It is not Cable testing description) or any of the inputs is not valid\n";
  print "The port $Interface$ was not configured\n";
  }
else
{
  print "The port $Interface$ matches filter criteria\n";
  print "Configuring the port $Interface$\n";
  configure_port();
  print "The port $Interface$ was configured\n";
}
@output = $con->disconnect();
$con->logout();
undef $con;
exit(0);
# End main 


sub validate_filter {
# This is used to determine what filter to use according to the device's type
my @listVar = ("(HundredGigE|hu|h|TenGigE|te|t|GigabitEthernet|gi|g)[ ]*[0-9]+\/[0-9]+","=:=descriptionAuto_Cable_Testing_");
my $portSt = 0;
my $myVar = "";
my $start = 0;
my $end = 0;
  foreach my $line (@results) {
        chomp($line);
  if ($line =~ m/^interface/) {
    $start = 1;
    }
  if (($line =~ m/^end/) && $start == 1) {
    $end = 1;
    }
  if ($start == 1 && $end != 1) {  
    $line =~ s/\s+//g;
    $line = lc($line);
    print "line:$line\n";
    $myVar = join "", $myVar, $line,"=:=";
  }  
  }
  print "Full interface value:$myVar\n";
  my  $tFound = 1;
  my  $notFound = "";
  my  $tmpList = "";
  my  $pFilter = "";
  foreach my $valChk (@listVar) {
    $tmpList = lc($valChk);
 $pFilter = $tmpList; 
 if ($myVar =~ m/${pFilter}/){ 
   $tFound++;
   print "Find match value:$pFilter\n";
   }
 else 
  {
    my $noPat = $tmpList;
    $noPat =~ s/.*\<//g;
    $noPat =~ s/\>.*//g;
    if (( $tmpList =~ m/:null:/) && ( $myVar !~ m/${noPat}/)) { 
      $tFound++;
      print "Find match of not find:$noPat\n";
   }
      else
    {
      $notFound = join "", $notFound, "-:(-" , $tmpList; 
      print "Failing based on the rule $tmpList !!!\n";
   }
  }  
 }
 if ($tFound > ($#listVar + 1) )  
 {
  $portSt = 0;
  }
 else 
 {
  $portSt = -1;
  }
    return $portSt;
}

sub configure_port {

my $port_base = <<PBASE;
terminal length 0    
!  
config exclusive
!   
interface $Interface$   
no description
no ip address
no cdp
no mtu
no speed
no duplex
no negotiation
shutdown   
exit  
!   
commit label WO$WorkOrderNumber$ comment WO$WorkOrderNumber$ Cable Testing 
end  
!   
PBASE

#my @pbCmd = split ( / \n/, $port_base );
# foreach my $cmdProc (@pbCmd) {
#     $con->cmd($cmdProc);  
# }
my @pbCmd = split ( /\n/, $port_base );
my $cmdString = "";
 foreach my $cmdProc (@pbCmd) {
      $cmdProc =~ s/\/\//!/g;
      $cmdString .= "${cmdProc} \n ";
 }
 @output = $con->cmd($cmdString);  
}