foreach $fileName (@ARGV)
{
	if (-e $fileName)
	{
		if (-M $fileName > 1)
		{
			print "$fileName exists and is older than a day\n";
		}
		else
		{
			print "$fileName exists and is younger than a day\n";
		}
	}
	else
	{
		print "$fileName does not exists\n";
	}
}