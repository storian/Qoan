
package Qoan::Interface::IRequest_CGIMinimal;
our $VERSION = '0.03';

# Qoan::Interface::Request
# 
# This component interface is the default one for the Request component,
# and assists the CGI::Minimal module.

use strict;
use Qoan::Interface ();

our @ISA = qw| Qoan::Interface |;

#my( $accessor );


sub accessor
{
	my( $controller ) = shift();
	return $controller->component( @_ );
}


# method _AFTER_NEW  (public, object)
# purpose:
#	Loads input from the request to the controller's functional environment.
# usage:
#	Receives controller and request objects.
# security:
#	Writes to functional environment
#	Returns true value.

sub _after_new
{
	my( $controller, $request, @multival, %input );
	
	$controller = shift();
	$request = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
	return ! warn 'Valid request object not received' unless ref( $request );
	
# The following loads request parameters into env.
#  - sensitive to multiple values per input name;
#  - substitutes true value '1' for params without a value.
	for ( $request->param )
	{
		@multival = $request->param( $_ );
		$input{ lc( $_ ) } = @multival > 1 ? [ @multival ] : ( $multival[ 0 ] || '1' );
	}
	
	$controller->env( 'request' => \%input );
	
	$controller->report( "** added to env:  $_ => $input{ $_ }" ) for sort keys %input;
	
# Gives access to the request accessor to the Action Manager.
	$controller->publish( 'action_manager' => 'request' );
	
	return 1;
}


# method _BEFORE_NEW (public, object)
# purpose:
#	Returns true value in order to prompt loading of request component.
# usage:
#	Controller reference.

sub _before_new
{
	return undef unless $_[ 0 ]->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
	return 1;
}


#sub set_name
#{
#	#return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
## Shift off evoker.
#	shift();
#	
#	$accessor = shift() unless defined $accessor;
#	return $accessor;
#}


1;
