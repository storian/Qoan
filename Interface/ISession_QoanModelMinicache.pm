
package Qoan::Interface::ISession_QoanModelMinicache;

use strict;

our $VERSION = '0.03';

# Qoan::Interface::Session
# 
# This component interface is the default one for the Session component, and
# assists the Minicache module.  The session object is loaded read-write.

use Qoan::Interface ();

our @ISA = qw| Qoan::Interface |;
our @EXPORT = qw| create |;

#my( $accessor );


sub accessor
{
	my( $controller ) = shift();
	return $controller->component( @_ );
}


sub _after_new
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
	$controller->session( %session_vals ); # unless $controller->env( $accessor );
	%session_vals = $controller->session( 'data' );
	
	$controller->report( "** added to env:  $_ => $session_vals{ $_ }" ) for sort keys %session_vals;
	
# The session must publish the user ID to where the default user interface can find it.
	if ( $userid_variable = $controller->env( 'userid_variable' ) )
	{
		$controller->env( $userid_variable => $controller->session( $userid_variable ) );
	}
	
	return 1;
}


sub _before_new
{
	my( $controller, $sessionid_variable, $cookie, $sessionid );
	
	$controller = shift(); 
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	
# Gives access to the Session interface to the Action Manager.
	$controller->publish( 'action_manager' => 'session' );
	$controller->publish( 'action_manager' => 'session_create' );
	
	$sessionid_variable = $controller->env( 'sessionid_variable' ) || '';
	$cookie = $controller->env( 'sys_env:http_cookie' ) || '';
	
# If we are in context loading stage, Session ID will be in HTTP cookie; otherwise
# we are creating a new session, so check for a new ID.
	$sessionid = ( $controller->request_stage( 'current' => 'load' ) )
		? ( $cookie =~ m|$sessionid_variable=([^;\s]+)| )[ 0 ]
		: $controller->session( 'new_id' );
	
	$sessionid = '' unless defined $sessionid;
	$sessionid =~ s|\s||g;
	
	if ( $sessionid =~ m|\W| )
	{
		$controller->warn( "Session ID contains invalid characters ($sessionid)" );
		return 0;
	}
	
# Client might pass ID for nonexistant session.  Delete such IDs in Load stage.
	if ( $sessionid && $controller->request_stage( 'current' => 'load' ) )
	{
		$sessionid = undef unless -e $controller->session( 'store' ) . $sessionid;
	}
	
# Store the session object constructor args to functional env.
	if ( $sessionid )
	{
		$controller->session( 'id' => $sessionid );
		$controller->session( 'settings:init' => [
			'source' => $controller->session( 'store' ) . $sessionid,
			'mode' => 'RW' ] );
	}
	
# Load object criteria.
	return 1 if $controller->session( 'id' ) && $controller->session( 'init' );
	return 0;
}


sub _cleanup
{
	my( $controller, %set );
	
	$controller = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_unload_component' ] );
	
	%set = ( 'last_action' => $controller->env( 'action:name' ),
		'last_action_manager' => $controller->env( 'action_manager:name' ),
		'last_request' => $controller->env( 'uri:virtual' ),
		'last_request_at' => time() );
	
# Set session values in functional env.
	$controller->session( %set );
	
# Set session object values from functional env, and then cache to file.
	$controller->session->set( $controller->env( 'session' ) );
	$controller->session->cache;
}


sub create
{
	my( $controller, $sessionid, $created );
	
	$controller = shift();
	$sessionid = shift();
	
	return if ref( $controller->session );
	$controller->report( 'No extant session..' );
	
# Create session ID if not submitted and not in functional env.
	unless ( $sessionid ||= $controller->session( 'settings:new_id' ) )
	{
		my( $id_generator );
		
# This is an optional helper.
		if ( $id_generator = $controller->session( 'id_generator' ) )
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
		
		$controller->session( 'settings:new_id' => $sessionid );
	}
	
# Abort if no ID.
	unless ( $controller->session( 'new_id' ) )
	{
		$controller->warn( "Failed to find or generate new session ID" );
		return 0;
	}
	
# Create session.
	$controller->_load_component( 'session' );
	$created = ref( $controller->session );
	
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
# Note, we prepend with uri:app_root in case the Qoan redirector lives below the httpd docroot.
		#$app_path = $controller->env( 'uri:app_root' ) .
		#	'/' . $controller->env( 'application_alias' );
		$app_path = $controller->env( 'uri:app_root' );
		$app_path .= '/' . $controller->env( 'application_alias' ) if $controller->env( 'uri:alias:virtual' );
		
# Note the cookie is good for the entire /story application.  The session will
# hold references to all story tracks the user creates.
		$cookie = "$sessionid_variable=$sessionid; " .
			"Expires=$expires; " .
			"Path=$app_path; " .
			"Domain=.dysgasmia.net";
		
		$controller->response( 'headers:set-cookie' => $cookie );
	}
	
	return 1 if $created && $controller->response( 'headers:set-cookie' );
	return 0;
}


1;
