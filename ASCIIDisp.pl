$str = "This is a string\n" . chr(0);
for ($x=0; $x<length($str);$x++)
{
	$char = substr($str,$x,1);
	$val = ord($char);
	print("$x: $char = $val\n");
}