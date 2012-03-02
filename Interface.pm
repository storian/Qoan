
package Qoan::Interface;

use strict;

our $VERSION = '0.01';

# Qoan::Interface
# 
# Documentation here

# WARN  Using Qoan::Helper at this time (Oct 2011) really accomplishes nothing.
#       Might be worthwhile to inherit from a more specific Helper class, later.
#use Qoan::Helper;

our( @ISA, @EXPORT, @EXPORT_OK );

#@ISA = qw| Qoan::Helper |;
@EXPORT = @EXPORT_OK = qw| _before_load  _after_load  _cleanup  accessor |;


# Defaults to returning undef for components which do not require instantiation.
sub accessor
{
	return undef;
}


# For interfaces which define _before_load, _after_load defaults to returning
# a true value (which is success for _load_component).
sub _after_load
{
	return 1;
}


# Components which require instantiation should overload _before_load and
# return a true value.  A false value indicates load success (interface loaded
# but instantiation not required).
sub _before_load
{
	return 0;
}


# Defaults to returning true value.
sub _cleanup
{
	return 1;
}


sub import
{
	my( $pkg, $controller, $component, $call_pkg, %export_map, @exports, $import_name, $sub_defined );
	
	$pkg = shift();
	$controller = shift();
	$component = shift();
	
	if ( $component =~ m|\W| )
	{
		$controller->warn( qq|Received component name $component contains characters illegal for subroutine names| );
		return 0;
	}
	
	$call_pkg = caller( 0 );
	#$controller->_report( "interface import:  $pkg => $call_pkg" );
	
# The intention for %export_map is so that each interface subclass can define how the routine
# names are set in the Request Manager.  Not used currently.
	#%export_map = (
	#	'accessor' => ( $controller->env( "component:$component:accessor_alias" ) || $component ),
	#	'_after_load' => "_${component}_after_load",
	#	'_before_load' => "_${component}_before_load",
	#	'_cleanup' => "_${component}_cleanup",
	#	);
	
	no strict 'refs';
	
	push( @exports, @{ "$pkg\::EXPORT" }, @EXPORT );
	#$controller->_report( "exports: @exports" );
	
	for ( @exports )
	{
		if ( m|\W| )
		{
			$controller->warn( qq|Subroutine for import "$_" contains characters illegal for subroutine names| );
			next;
		}
		
		#$import_name = "_$component$_" if m|^_|;
		#$import_name = "${component}_$_" if m|^[a-z]| && ! m|^accessor$|;
		#$import_name = ( $controller->env( "component:$component:accessor_alias" ) || $component ) if m|^accessor$|;
		if ( m|^accessor$| )
		{
			$import_name = $controller->env( "component:$component:accessor_alias" ) if $controller->can( 'env' );  # SERVER COMPONENT ?
			$import_name ||= $component;
		}
		else
		{
			$import_name = "_$component$_" if m|^_|;
			$import_name = "${component}_$_" if m|^[a-z]|;  # && ! m|^accessor$|;
		}
		
# Set calling package reference to component interface routine.
# Uses routine in base Interface package (this) if named routine is undefined in subclass.
		if ( defined( &{ "$pkg\::$_" } ) )
		{
			#$controller->report( "Aliasing: $pkg\::$_ => $call_pkg\::$import_name" );
			*{ "$call_pkg\::$import_name" } = \&{ "$pkg\::$_" };
		}
		elsif ( defined( &{ __PACKAGE__ . "\::$_" } ) )
		{
			#$controller->report( "Aliasing: @{[ __PACKAGE__ ]}\::$_ => $call_pkg\::$import_name" );
			*{ "$call_pkg\::$import_name" } = \&{ __PACKAGE__ . "\::$_" };
		}
		else
		{
			$controller->warn( "Routine $_ (to export from $pkg to $call_pkg) is not defined." );
		}
		
		return 0 unless defined( &{ "$call_pkg\::$import_name" } );
	}
	
	return 1;
}


1;
