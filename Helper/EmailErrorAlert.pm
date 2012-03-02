
package Qoan::Helper::EmailErrorAlert;

# Qoan::Helper::EmailErrorAlert
# 

use strict;
use Qoan::Helper;

our( $VERSION, @ISA, @EXPORT, @EXPORT_OK );

$VERSION = '0.01';

@ISA = qw| Qoan::Helper |;
@EXPORT = @EXPORT_OK = qw| _email_error_alert |;


sub _email_error_alert
{
	my( $controller, $email, $ok, $sendmail );
	
	$controller = shift();
	$ok = 0;
	
# Email::Sender is not on NFS.net.
	#use Email::Sender::Simple;
	use Email::Simple;
	use Email::Simple::Creator;
	
	$email = Email::Simple->create(
		'header' => [
			'From'    => $controller->env( 'alert_on_error:email:from' ),
			'To'      => $controller->env( 'alert_on_error:email:to' ),
			'Subject' => $controller->env( 'alert_on_error:email:subject' ) ],
		'body' => $controller->captured_output );
	
# Can't use this since we can't use Email::Sender.
	#$ok = 1 if Email::Sender::Simple->try_to_send( $email );
	eval( open( MAIL, "|/usr/bin/sendmail -t" ) );
	print STDERR "Failed to open sendmail pipe: $@\n" if $@;
	$ok = 1 if print MAIL $email->as_string;
	close MAIL;
	
	print STDERR "Sending error alert by e-mail.. @{[ $ok ? 'successful.' : 'failed.' ]}\n";
	
	return $ok;
}


1;
