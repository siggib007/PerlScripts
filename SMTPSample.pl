use Net::SMTP;

$relay = "localhost" ; # This is the mail server, it automatically uses the right port
@maildata = ('Hello','This is a simple test of SMTP via perl.','Have a nice day');
send_mail("Siggi Bjarnason<siggi\@majorgeek.us>", "Perl Scripting<perl\@majorgeek.us>", "More Perl SMTP testing", @maildata);
#print "Mail sent\n";
#notice("Mail sent");
notice();

sub send_mail {

  my($to, $from, $subject, @body) = @_;
  
  my $smtp = Net::SMTP->new($relay, 
                           Debug => 0); # Set Debug to 1 if you have any problems

  if ($salutation eq '') 
  {
  	$salutation="nothing";
  }
  $smtp->mail($from) ;
  $smtp->to($to) ;

  $smtp->data() ;
  $smtp->datasend("To: $to\n") ;
  $smtp->datasend("From: $from\n") ;
  $smtp->datasend("Subject: $subject\n") ;
  $smtp->datasend("\n") ;

#----- This part loops through your file and puts all the lines into your mail one by one
  foreach $body (@body) {
    $smtp->datasend("$body\n") ;
  }
  $smtp->datasend("$salutation\n") ;
  $smtp->dataend() ;
  $smtp->quit() ;
}

sub notice
{
	my($msg) = @_;
	if ($msg eq '')
	{
		print "exit without cause\n";
	}
	else
	{
		print "$msg\n";
	}
}	