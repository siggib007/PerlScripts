use Data::UUID;
  
  $ug    = new Data::UUID;
  $uuid1 = $ug->create();
  $uuid2 = $ug->create_from_name(NameSpace_URL, "www.clear.com");

  $res   = $ug->compare($uuid1, $uuid2);

  $str   = $ug->to_string( $uuid );
  $uuid  = $ug->from_string( $str );
  $struuid  = $ug->create_str();
  $strLen = length($struuid);
  print "uuid1: $uuid1\n";
  print "uuid2: $uuid2\n";
  print "res: $res\n";
  print "str: $str\n";
  print "uuuidg: $uuid\n";
  print "struuid: $struuid\n";
  print "Length of strUUID is $strLen\n";
  