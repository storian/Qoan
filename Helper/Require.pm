#!/usr/bin/perl -w

package Qoan::Helper::Require;
our $VERSION = '0.02';

# Qoan::Helper::Require provides uniform and safe runtime require functions.
# 

use strict;
use Qoan::Helper;

our( @ISA, @EXPORT, @EXPORT_OK );

@ISA = qw| Qoan::Helper |;
@EXPORT = @EXPORT_OK = qw| _require _unimport |;


# method _REQUIRE  (private, class)
# purpose:
#	To securely require a module.
# usage:
#	Receives name of module to require.  Caller ref will preceed for
#	object method style calls.
# security:
#	This routine works only with the single value it receives.
#	It returns only a true/false value generated separate from the input.

sub _require ($;$)
{
	return ! warn 'Call to Require helper as class method or to load itself'
		if grep { $_ eq __PACKAGE__ } @_[ 0, 1 ];
	
	my( $calling_pkg, $host, $module, $ok );
	
	$calling_pkg = ( caller( 0 ) )[ 0 ];
	$host = shift() if ref $_[ 0 ];
	
# Caller restriction: Require expects object method style calls from all importing
# packages, except main.
	#return ! warn 'Require helper expects object method style calls (except from Main)'
	#	unless $host || $calling_pkg eq 'main';
	
	$module = shift();
	
# Regexes allow module barewords only.
	return ! warn "Module name $module failed name check" unless
		$module =~ m|^[\w:]+$| &&  # Verifies only allowed bareword chars.
		$module !~ m|^[\d:]| &&    # Verifies allowed starting char.
		$module !~ m|:$| &&        # Verifies allowed ending char.
		$module !~ m|::\d|;        # Verifies allowed starting char on each segment.
	
	local $@;
	$ok = eval "require $module; 1;";
	
	return ! warn "Error on @{[ ref $host ]} module $module require: $@" if ! $ok;
	return $ok;
}


#sub _unimport ($;$)
#{
#	return ! warn 'Call to Require helper as class method or to load itself'
#		if grep { $_ eq __PACKAGE__ } @_[ 0, 1 ];
#	
#	my( $calling_pkg, $host, $module, $ok );
#	
#	$calling_pkg = ( caller( 0 ) )[ 0 ];
#	$host = shift() if ref $_[ 0 ];
#	
## Caller restriction: Require expects object method style calls from all importing
## packages, except main.
#	#return ! warn 'Require helper expects object method style calls (except from Main)'
#	#	unless $host || $calling_pkg eq 'main';
#	
#	$module = shift();
#	
## Regexes allow module barewords only.
#	return ! warn "Module name $module failed name check" unless
#		$module =~ m|^[\w:]+$| &&  # Verifies only allowed bareword chars.
#		$module !~ m|^[\d:]| &&    # Verifies allowed starting char.
#		$module !~ m|:$| &&        # Verifies allowed ending char.
#		$module !~ m|::\d|;        # Verifies allowed starting char on each segment.
#	
#	local $@;
#	$ok = eval "no $module; 1;";
#	
#	return ! warn "Error on @{[ ref $host ]} module $module unimport: $@" if ! $ok;
#	return $ok;
#	;
#}


1;
