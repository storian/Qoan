
package Qoan::Interface::IUser_QoanModelMinicache;
our $VERSION = '0.03';

# Qoan::Interface::User
# 
# This component interface is the default one for the User component, and
# assists the Minicache module.  The user object is loaded read-only.

use strict;
use Qoan::Interface ();

our @ISA = qw| Qoan::Interface |;

#my( $accessor );


sub accessor
{
	my( $controller ) = shift();
	return $controller->component( @_ );
}


sub _after_new
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
	
	$controller->user( %user_vals );
	%user_vals = $controller->user( 'data' );
	
	$controller->report( "added to env:  $_ => $user_vals{ $_ }" ) for sort keys %user_vals;
	
	return 1;
}


sub _before_new
{
	my( $controller, $userid_variable, $userid );
	
	$controller = shift();
	
	return unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
# Gives access to the User accessor to the Action Manager.
	$controller->publish( 'action_manager' => 'user' );
	
	$userid_variable = $controller->env( 'userid_variable' );
	$userid = $controller->env( $userid_variable );
	$userid = $controller->session( $userid_variable ) if ! $userid && $controller->can( 'session' );
	
# Store user id and user object constructor args to functional env.
	if ( $userid )
	{
		$controller->env( 'userid' => $userid );
		$controller->user( 'init' => [ 'source' => $controller->user( 'store' ) . $userid ] );
	}
	
# Only load object if we found a user id.
	return 1 if $controller->env( 'userid' ) && $controller->env( 'component:user:init' );
	return 0;
}


sub _cleanup
{
	1;
}


1;
