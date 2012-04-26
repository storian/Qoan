
package Qoan::Interface::ISubrequest_HTTPTiny;

# Qoan::Interface::ISubrequest_HTTPTiny
# 
# XX

use strict;
use Qoan::Interface ();
#use HTTP::Tiny;

our $VERSION = '0.01';
our @ISA = qw| Qoan::Interface |;
our @EXPORT = qw| http_fetch |;

my $subrequest;


sub accessor
{
	my( $controller ) = shift();
	
	$subrequest = shift() if ref( $_[ 0 ] ) eq 'HTTP::Tiny' && ! defined( $subrequest );
	
	return $subrequest unless @_;
	return $controller->component( @_ );
}


# method _AFTER_NEW
# purpose:
#	??
# usage:
#	Receives controller and subrequest objects.

sub _after_new
{
	my( $controller, $request, @multival, %input );
	
	$controller = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
# Gives access to the request accessor to the Action Manager.
	$controller->publish( 'action_manager' => 'subreq_http_fetch' );
	
	return 1;
}


# method _BEFORE_NEW
# purpose:
#	Returns true value in order to prompt loading of subrequest component.
# usage:
#	Controller reference.

sub _before_new
{
	my( $controller ) = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
	# GET HTTP-TINY ATTRIBUTES FROM CONTROLLER ENV
	
	return 1;
}


sub http_fetch
{
	my( $controller, $uri, $headers, $form_data, $response );
	
	$controller = shift();
	$uri = shift();
	$headers = shift() || '';
	$form_data = shift() || '';
	
	$controller->report( "Calling: $uri" );
	$controller->report( 'With headers:' );
	$controller->report( " $_ => $$headers{ $_ }" ) for sort keys %{ $headers };
	if ( $form_data )
	{
		$controller->report( 'And form values:' );
		$controller->report( " $_ => $$form_data{ $_ }" ) for sort keys %{ $form_data };
	}
	
	$response = $form_data
		? $subrequest->post_form( $uri, $form_data, $headers )
		: $subrequest->get( $uri, $headers );
	
	unless ( ref( $response ) eq 'HASH' )
	{
		warn 'Sub-request response in unexpected format (not hashref)';
		return;
	}
	
# Currently doing it the sweet-n-easy way: just return the entire response,
# let the caller sort it out.
	#return $response->{ 'content' } if length $response->{ 'content' };
	return $response;
}


1;
