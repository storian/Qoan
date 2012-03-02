#!/usr/bin/perl

package Qoan::Helper::AllowedCaller;
our $VERSION = '0.01';

# Qoan::Helper::AllowedCaller
# 
# THIS HAS BEEN REDESIGNED IN THE CONTROLLER PACKAGE as of March 2012.

use strict;
use Qoan::Helper;

our @ISA = qw| Qoan::Helper |;

@EXPORT = @EXPORT_OK = qw| _allowed_caller |;


# method _ALLOWED_CALLER  (private, class)
# purpose:
#	To evaluate whether a subroutine has been called by a permitted caller.
# usage:
#	Subroutine caller permission hash reference, with elements:
#	 :packages => [  ]  e.g. main, __PACKAGE__, ref( $c )
#	 :routines => [  ]  e.g. &_REQ_PROCESSING, the accessor subs
# security:
#	This routine works only with the data passed to it, and returns only
#	a true/false value which is not calculated with received data.

sub _allowed_caller ($)
{
	my( $criteria, $caller, $callee, $sub_caller, $pkg_caller, $sub_ok, $pkg_ok );
	
# Called sub (callee) is always in the subroutine position of the previous stack record.
# Caller is in sub position of record previous to that, or in package position if that
# record does not exist (this means the sub was called by main).
	$callee = ( caller( 1 ) )[ 3 ];
	$caller = caller( 2 ) ? ( caller( 2 ) )[ 3 ] : ( caller( 1 ) )[ 0 ];
	
# Uncomment for basickest debugging.  Note that __ANON__ means a closure.
	#_report "Call to $callee from $caller\n";
	
	return 1 unless $criteria = shift();
	
	( $sub_caller ) = ( $caller =~ m|:(\w+)$| );
	( $pkg_caller ) = $caller =~ /:/ ? ( $caller =~ m|^(.*?):{2}\w+$| ) : $caller;
	
	$sub_ok = $pkg_ok = 0;
	$pkg_ok = 1 if ! exists( ${ $criteria }{ ':packages' } );
	$sub_ok = 1 if ! exists( ${ $criteria }{ ':routines' } );
	
	for ( @{ $criteria->{ ':routines' } } )
	{
		$sub_ok = 1 if $sub_caller eq $_;
	}
	
	for ( @{ $criteria->{ ':packages' } } )
	{
		$pkg_ok = 1 if $pkg_caller eq $_;
	}
	
	die "Unauthorized call to $callee made by $caller.  Only the following may call $callee:\n" .
		'  Packages: ' . join( ', ', @{ $criteria->{ ':packages' } } ) . "\n" .
		'  Routines: ' . join( ', ', @{ $criteria->{ ':routines' } } ) . "\n"
		if ! ( $pkg_ok && $sub_ok );
	
	return $pkg_ok && $sub_ok;
}


1;
