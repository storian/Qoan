#!/usr/bin/perl -w

package Qoan::Helper::Adapt_CGI_Minimal;
our $VERSION = '0.01';

# Qoan::Helper::Adapt_CGI_Minimal
# 

use strict;
use Qoan::Helper;

our( @ISA, @EXPORT, @EXPORT_OK );

@ISA = qw| Qoan::Helper |;
@EXPORT = @EXPORT_OK = qw| populate_controller_env |;


# method POPULATE_CONTROLLER_ENV  (public, object)
# purpose:
#	To return values to the controller (the caller).
# usage:
#	Receives object ref only.
# security:
#	Routine receives only the object reference.
#	Returns data taken from the request object.

sub populate_controller_env ($)
{
	my( $adapter, @multi, %input );
	$adapter = shift();
	
	for ( $adapter->param )
	{
		@multi = $adapter->param( $_ );
		$input{ lc( $_ ) } = @multi > 1 ? [ @multi ] : $multi[ 0 ];
	}
	
	return \%input;
}


1;
