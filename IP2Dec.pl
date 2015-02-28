$strIP  = "10.15.32.12";
@subnetquads = split(/\./, $strIP);
$hexIP  = sprintf "%02x%02x%02x%02x", $subnetquads[0], $subnetquads[1], $subnetquads[2], $subnetquads[3];
$decIP  = hex($hexIP);
print "string: $strIP\nHex: $hexIP\nDecimal: $decIP\n";