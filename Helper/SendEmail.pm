
package Qoan::Helper::SendEmail;

# Qoan::Helper::SendEmail
# 

use strict;
use Qoan::Helper;

our( $VERSION, @ISA, @EXPORT, @EXPORT_OK );

$VERSION = '0.01';

@ISA = qw| Qoan::Helper |;
@EXPORT = @EXPORT_OK = qw| _send_email |;


sub _send_email
{
	my( $controller, %email_parts, $ok, $email, $sendmail );
	
	$controller = shift();
	%email_parts = @_;
	$ok = 0;
	
# Email::Sender is not on NFS.net.
	#use Email::Sender::Simple;
	use Email::Simple;
	use Email::Simple::Creator;
	
	$email = Email::Simple->create(
		'header' => [
			'From'    => $email_parts{ 'from' },
			'To'      => $email_parts{ 'to' },
			'Subject' => $email_parts{ 'subject' } ],
		'body' => $email_parts{ 'body' } );
	
# Can't use this since we can't use Email::Sender.
	#$ok = 1 if Email::Sender::Simple->try_to_send( $email );
	if ( eval( open( $sendmail, "|/usr/bin/sendmail -t" ) ) )
	{
		$ok = 1 if print $sendmail $email->as_string;
		close $sendmail;
	}
	else
	{
		$controller->report( "Send Email helper failed to open sendmail pipe: $@" );
	}
	
	$controller->report( "Sending error alert by e-mail.. @{[ $ok ? 'successful.' : 'failed.' ]}\n" );
	
	return $ok;
}


1;
