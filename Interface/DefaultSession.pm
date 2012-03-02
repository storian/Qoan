
package Qoan::Interface::DefaultSession;

use strict;

our $VERSION = '0.03';

# Qoan::Interface::Session
# 
# This component interface is the default one for the Session component, and
# assists the Minicache module.  The session object is loaded read-write.

use Qoan::Interface ();

our @ISA = qw| Qoan::Interface |;
our @EXPORT = qw| create |;

my( $accessor );


sub accessor
{
	my( $controller ) = shift();
	return $controller->component( @_ );
}


sub _after_load
{
	my( $controller, $session, %session_vals, $userid_variable );
	
	$controller = shift();
	$session = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
	unless ( ref $session )
	{
		$controller->warn( 'Valid session object not received' );
		return 0;
	}
	
# Copy session data to functional env.
# Note that if session creation is triggered by existence of a session value
# to env, the following should NOT overwrite it (env values are not changeable
# after the request handling has started).
	%session_vals = $session->get;
	$controller->$accessor( %session_vals ); # unless $controller->env( $accessor );
	%session_vals = $controller->$accessor( 'data' );
	
	$controller->report( "** added to env:  $_ => $session_vals{ $_ }" ) for sort keys %session_vals;
	
# The session must publish the user ID to where the default user interface can find it.
	if ( $userid_variable = $controller->env( 'userid_variable' ) )
	{
		$controller->env( $userid_variable => $controller->$accessor( $userid_variable ) );
	}
	
	return 1;
}


sub _before_load
{
	my( $controller, $sessionid_variable, $cookie, $sessionid );
	
	$controller = shift(); 
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
	$sessionid_variable = $controller->env( 'sessionid_variable' ) || '';
	$cookie = $controller->env( 'sys_env:http_cookie' ) || '';
	
# If we are in context loading stage, Session ID will be in HTTP cookie; otherwise
# we are creating a new session, so check for a new ID.
	$sessionid = ( $controller->env( 'request_stage' ) == $controller->_load_stage )
		? ( $cookie =~ m|$sessionid_variable=([^;\s]+)| )[ 0 ]
		: $controller->$accessor( 'new_id' );
	
	$sessionid = '' unless defined $sessionid;
	$sessionid =~ s|\s||g;
	
	if ( $sessionid =~ m|\W| )
	{
		$controller->warn( "Session ID contains invalid characters ($sessionid)" );
		return 0;
	}
	
# Store the session object constructor args to functional env.
	if ( $sessionid )
	{
		$controller->$accessor( 'id' => $sessionid );
		$controller->$accessor( 'settings:init' => [
			'source' => $controller->$accessor( 'store' ) . $sessionid,
			'mode' => 'RW' ] );
	}
	
# Load object criteria.
	return 1 if $controller->$accessor( 'id' ) && $controller->$accessor( 'init' );
	return 0;
}


sub _cleanup
{
	my( $controller, %set );
	
	$controller = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_unload_component' ] );
	
	%set = ( 'last_action' => $controller->env( 'action:name' ),
		'last_action_manager' => $controller->env( 'action_manager:name' ),
		'last_request' => $controller->env( 'uri:complete' ),
		'last_request_at' => time() );
	
# Set session values in functional env.
	$controller->$accessor( %set );
	
# Set session object values from functional env, and then cache to file.
	$controller->$accessor->set( $controller->env( $accessor ) );
	$controller->$accessor->cache;
}


sub create
{
	my( $controller, $sessionid, $created );
	
	$controller = shift();
	$sessionid = shift();
	
	return if ref( $controller->$accessor );
	
# Create session ID if not submitted and not in functional env.
	unless ( $sessionid ||= $controller->$accessor( 'settings:new_id' ) )
	{
		my( $id_generator );
		
# This is an optional helper.
		if ( $id_generator = $controller->$accessor( 'id_generator' ) )
		{
			$sessionid = $controller->$id_generator;
		}
# Internal generation.
		else
		{
			require Data::Uniqid;
# Concatting two IDs together.. should increase the uniqueness space somewhat..
			$sessionid = Data::Uniqid->luniqid . Data::Uniqid->luniqid;
			$sessionid =~ s|(.{5})|$1_|g;
			$controller->report( "Generated Session ID: $sessionid" );
		}
		
		$controller->$accessor( 'settings:new_id' => $sessionid );
	}
	
# Abort if no ID.
	unless ( $controller->$accessor( 'new_id' ) )
	{
		$controller->warn( "Failed to find or generate new session ID" );
		return 0;
	}
	
# Create session.
	$controller->_load_component( $accessor );
	$created = ref( $controller->$accessor );
	
# Create cookie header to transmit session ID to client.
	if ( $created )
	{
		my( $sessionid_variable, $cookie, $app_path, $expires );
		
		require POSIX;
# Expires setting format e.g.: Tue, 15 Jan 2013 21:47:38 GMT
		$expires = POSIX::strftime(
			"%a, %e %b %Y %H:%M:%S GMT",
			gmtime( time() + $controller->env( 'cookie:expires_in' ) ) );
		
		$sessionid_variable = $controller->env( 'sessionid_variable' );
		$app_path = $controller->env( 'application_alias' );
		
# Note the cookie is good for the entire /story application.  The session will
# hold references to all story tracks the user creates.
		$cookie = "$sessionid_variable=$sessionid; " .
			"Expires=$expires; " .
			"Path=/$app_path; " .
			"Domain=.dysgasmia.net";
		
		$controller->response( 'headers:set-cookie' => $cookie );
	}
	
	return 1 if $created && $controller->response( 'headers:set-cookie' );
	return 0;
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
