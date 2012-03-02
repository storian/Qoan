
package Qoan::Interface::DefaultUser;
our $VERSION = '0.03';

# Qoan::Interface::User
# 
# This component interface is the default one for the User component, and
# assists the Minicache module.  The user object is loaded read-only.

use strict;
use Qoan::Interface ();

our @ISA = qw| Qoan::Interface |;

my( $accessor );


sub accessor
{
	my( $controller ) = shift();
	return $controller->component( @_ );
}


sub _after_load
{
	my( $controller, $user, %user_vals );
	
	$controller = shift();
	$user = shift();
	
	return unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
	unless ( ref $user )
	{
		$controller->warn( 'Valid user object not received' );
		return 0;
	}
	
	%user_vals = $user->get;
	
	$controller->$accessor( 'data' => \%user_vals );
	%user_vals = $controller->$accessor( 'data' );
	
	$controller->report( "added to env:  $_ => $user_vals{ $_ }" ) for sort keys %user_vals;
	
	return 1;
}


sub _before_load
{
	my( $controller, $userid_variable, $userid );
	
	$controller = shift();
	
	return unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
	$userid_variable = $controller->env( 'userid_variable' );
	$userid = $controller->env( $userid_variable );  # || $controller->session( $userid_variable );
	
# Store user id and user object constructor args to functional env.
	if ( $userid )
	{
		$controller->env( 'userid' => $userid );
		$controller->env( 'component:$accessor:init' =>
			[ 'source' => $controller->env( 'component:$accessor:store' ) . $userid ] );
	}
	
# Only load object if we found a user id.
	return 1 if $controller->env( 'userid' ) && $controller->env( 'component:$accessor:init' );
	return 0;
}


sub _cleanup
{
	1;
}


sub create
{
	;
}


sub set_name
{
	#return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
# Shift off evoker.
	shift();
	
	$accessor = shift() unless defined $accessor;
	return $accessor;
}


1;
