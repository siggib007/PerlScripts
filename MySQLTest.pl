use strict;
use DBI();
my ($strSQL, $DBName, $DBHost, $DBUser, $DBpwd, $sth, $dbh);

# Connect to the database.
#my $dbh = DBI->connect("DBI:mysql:database=test;host=localhost", "script", "test123", {'RaiseError' => 1});
#$DBHost = "localhost";
$DBHost = "192.168.1.10";
$DBName = "test";
#$DBUser = "tester1";
$DBUser = "script";
$DBpwd = "test123";
$strSQL = "SELECT * FROM foo";

# Connect to the database.
$dbh = DBI->connect("DBI:mysql:database=$DBName;host=$DBHost",
                       "$DBUser", "$DBpwd",
                       {'RaiseError' => 1});
# Drop table 'foo'. This may fail, if 'foo' doesn't exist.
# Thus we put an eval around it.
eval { $dbh->do("DROP TABLE foo") };
print "Dropping foo failed: $@\n" if $@;

# Create a new table 'foo'. This must not fail, thus we don't
# catch errors.
$dbh->do("CREATE TABLE foo (id INTEGER, fname VARCHAR(20), lname varchar(20))");

# INSERT some data into 'foo'. We are using $dbh->quote() for
# quoting the name.
$dbh->do("INSERT INTO foo VALUES (1, " . $dbh->quote("Tim") . ",'test')");

# Same thing, but using placeholders
$dbh->do("INSERT INTO foo VALUES (?, ?, ?)", undef, 2, "Jochen", "jane");

# Same thing, but using literals
$dbh->do("INSERT INTO foo VALUES (3,'johs','james')");

# Same thing, but using variables
my($seq,$name,$lname);
$seq=4;
$name="andy";
$lname = "aims";
$dbh->do("INSERT INTO foo VALUES ($seq, '$name', '$lname')");



# Now retrieve data from the table.
$sth = $dbh->prepare($strSQL);
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {
  print "Found a row: id = $ref->{'id'}, fname = $ref->{'fname'}, lname = $ref->{'lname'}\n";
}
$sth->finish();

# Disconnect from the database.
$dbh->disconnect();