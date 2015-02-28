#----------
# This is a simple program designed to poll Fabric stats 
# at a faster rate than we currently get via Cricket
#----------


foreach ($i=0; $i<2160; $i++) {

#----- Open the output file and check current time

open(FABRIC_STAT, '>>fabrica_stat.txt') ;
$time = time ;

#----- Get Stats (rxErrors, Fab_In, Fab_Out)
@fab_err = `snmpwalk -v2c -c 427cipower7 blu-65ag-srch-4a 1.3.6.1.4.1.9.9.217.1.3.1.1.3` ;
@fab_In_Util = `snmpwalk -v2c -c 427cipower7 blu-65ag-srch-4a 1.3.6.1.4.1.9.9.217.1.3.1.1.6` ;
@fab_Out_Util = `snmpwalk -v2c -c 427cipower7 blu-65ag-srch-4a 1.3.6.1.4.1.9.9.217.1.3.1.1.7` ;

print FABRIC_STAT "$time:\n" ;

print FABRIC_STAT "Fab_rxError	" ;

#----- Get FABRIC_Err 

   foreach $fabr_err (@fab_err) {
      chomp $fabr_err ;
      $fabr_err =~ s/.*Counter32: // ;
      print FABRIC_STAT "$fabr_err	" ;
   }

print FABRIC_STAT "\n" ;
print FABRIC_STAT "Fab_Ingress%	" ;

#----- Get Fabric_Util_In

   foreach $fab_In (@fab_In_Util) {
      chomp $fab_In ;
      $fab_In =~ s/.*INTEGER: // ;
      print FABRIC_STAT "$fab_In	" ;
   }

print FABRIC_STAT "\n" ;
print FABRIC_STAT "Fab_Egress%	" ;

#----- Get Fabric_Util_Out

   foreach $fab_Out (@fab_Out_Util) {
      chomp $fab_Out ;
      $fab_Out =~ s/.*INTEGER: // ;
      print FABRIC_STAT "$fab_Out	" ;
   }

print FABRIC_STAT "\n" ;

close(FABRIC_STAT) ;

print "sleeping for 40 sec\n" ;
sleep 40 ;

}