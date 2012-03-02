#!/usr/bin/perl -w

package Qafe::Helper::Component_Process; # ActionManager ?
our $VERSION = '0.02';

# Qafe::Helper::Component_Process
# 
# This component helper is the default one for the Process component,
# and assists the ActionManager module (or derived).

use strict;
use Qafe::Helper;

our( @ISA, @EXPORT, @EXPORT_OK );

@ISA = qw| Qafe::Helper |;
@EXPORT = @EXPORT_OK = qw| _before_process_load _after_process_load _process_cleanup |;


# method _AFTER_PROCESS_LOAD  (private, object)
# purpose:
#	Returns true value.

sub _after_process_load ($)
{
	1;
}


# method _BEFORE_PROCESS_LOAD (private, object)
# purpose:
#	To identify a process object for loading.
# usage:
#	Receives controller reference.
# security:
#	Reads controller ISA array
#	Reads from functional env
#	Reads requested process from REQUEST_URI
#	Writes to functional env
#	Returns true/false value

sub _before_process_load ($)
{
	my( $controller, $allowed, $requested_process, $processid );
	
	$controller = shift();
	
# Protected packages and ?? routine only.
	#$allowed = { ':packages' => [ '??' ], ':routines' => [ '??' ] };
	#return undef unless $controller->_allowed_caller( $allowed );
	
# Check the controller's ISA array to see if we AM a process (action manager).
# If so, scram.
	{
	 no strict 'refs';
	 for ( @{ ref( $controller ) . '::ISA' } )
	 {
		return 0 if $_ =~ m|^Qoan::ActionManager|;
	 }
	}
	
# At this point, if we amn't a process, then one MUST load.  Therefore this routine
# returns a true value ALWAYS, and raises errors if things go wrong.
	
# Get process name from request string.  Default regex grabs process name.
	for ( @{ $controller->env( 'uri_maps' ) } )
	{
		$requested_process = ( $controller->env( 'request_uri' ) =~ m|$_| )[ 0 ];
		$controller->env( 'matching_uri_map' => $_ );
		last if $requested_process;
	}
	
# Check for active processes.
# Note that this check must still happen for controllers which contain the process
# routines (are standalone apps).  Otherwise a client can call controller routines
# which it should not.
	for ( @{ $c->env( 'active_processes' ) } )
	{
		last if $processid = ( $_ =~ m|^$requested_process\s+[=:]?\s*(\w+)| )[ 0 ];
	}
	#return 0 if ! $processid; # ??
	
	$controller->env( 'processid' => $requested_process );
	#$processid = ucfirst( lc( $processid ) );
	$controller->env( 'process_module' => 'Qoan::ActionManager::' . ucfirst( lc( $processid ) ) );
	
	return 1;
	return 1 if $controller->env( 'processid' ) && $controller->env( 'process_module' );
	return 0;
}


# method _PROCESS_CLEANUP (private, object)
# purpose:
#	Sets state values in session record prior to object destruction.
# usage:
#	Receives controller ref.
# security:
#	Reads from functional environment
#	Writes to session record.
#	Returns success/failure of session record write.

sub _process_cleanup ($)
{
	my( $controller, $allowed );
	
	$controller = shift();
	
# Protected packages and ?? routine only.
	#$allowed = { ':packages' => [ '??' ], ':routines' => [ '??' ] };
	#return undef unless $controller->_allowed_caller( $allowed );
	
	#$controller->session->set( 'last_step' => $controller->env( 'current_step' ) );
	#$controller->session->set( 'last_request' => $ENV{ 'REQUEST_URI' } );
	#$controller->session->set( 'last_request_at' => time() );
	#$controller->session->set( 'last_step' => $controller->env( 'last_step' ) );
	
	#$controller->session->cache;
}


1;
