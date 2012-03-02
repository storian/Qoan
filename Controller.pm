
package Qoan::Controller;

# Qoan::Controller
#
# xxx

use strict;

our $VERSION = '0.02';

#use Qoan::RequestManager;


# CALLER hierarchy note:
# To determine the identity of the code file Using the Controller package,
# use caller( 0 ) outside of a BEGIN block, or caller( 2 ) inside of a BEGIN
# block.
#
# In BEGIN:
#	caller 0: [ 0 ]: FILE Qoan/Controller.pm,     [ 1 ]: SUB Qoan::Controller::BEGIN
#	caller 1: [ 0 ]: FILE Qoan/Controller.pm,     [ 1 ]: SUB (eval)
#	caller 2: [ 0 ]: FILE [path to calling file], [ 1 ]: SUB (eval); [ 2 ]: evaltext "Qoan/Controller.pm", is_require 1, hints 2
# Outside of BEGIN:
#	caller 0: [ 0 ]: FILE [path to calling file], [ 1 ]: SUB (eval); [ 2 ]: evaltext "Qoan/Controller.pm", is_require 1, hints 2
#	caller 1: [ 0 ]: FILE Qoan/Controller.pm,     [ 1 ]: SUB main::BEGIN
#	caller 2: [ 0 ]: FILE Qoan/Controller.pm,     [ 1 ]: SUB (eval)

our( @ISA, $main_config );

my( $qoan_base_file, $qoan_base_dir );
my( $caller_pkg, $caller_file, $caller_dir, $caller_config );
my( %start_params );


# Configuration default
BEGIN
{
	#our( @ISA, $main_config );
	#@ISA = qw| Qoan::RequestManager  Qoan::Config  Qoan::Logger |;
	#@ISA = qw| Qoan::RequestManager |; 
	
	$qoan_base_dir = $qoan_base_file = ( caller( 0 ) )[ 1 ];
	$qoan_base_dir =~ s|[^/]+$||;
	
	( $caller_pkg, $caller_file ) = ( caller( 2 ) )[ 0, 1 ];
	$caller_config = $caller_dir = $caller_file;
	$caller_dir =~ s|[^/]+$||;
	#print STDERR "callerstuff: $caller_pkg, $caller_file, $caller_dir, $caller_config\n";
	
# Adds caller home directory and caller's sibling Local directory to @INC.
# Caller's directory might contain a Qoan package directory structure.
# Note that Local would not be contained in that structure.
	#use lib ( $caller_dir, $caller_dir . 'Local' );
	unshift( @INC, $caller_dir, $caller_dir . 'Qoan/Local', $qoan_base_dir . 'Local' );
	
# Default names for these two files.
	$main_config = 'qoan.default.config';
	$caller_config =~ s|\.\w+$|.config|;
}


sub DESTROY
{
	;
}


# method _ALLOWED_CALLER  (private, class)
# purpose:
#	To evaluate whether a subroutine has been called by a permitted caller.
# usage:
#	Subroutine caller permission hash reference, with elements:
#	 ???

sub _allowed_caller
{
	my( $self, %criteria, $caller, $callee, $ok, $msg );
	
# Shift off first param if object.. or package name?
# WARN  pkg name?
	#shift() if ref( $_[ 0 ] ); # || $_[ 0 ] =~ m|^[\w:]+$|;
	$self = shift() if ref( $_[ 0 ] ) || $_[ 0 ] !~ m@^(?:=~|!~|eq|ne)$@;
	
# Caller( 0 ): contains PKG which called this sub ([ 0 ]), and this sub's fully qualified name ([ 3 ]).
# Caller( 1 ): contains CALLED's fully qualified sub name ([ 3 ]), and caller's pkg name ([ 0 ]).
# Caller( 2 ): contains CALLER's fully qualified sub name ([ 3 ]); we don't care who called it.
# CALLED/CALLEE is always in caller( 1 )[ 3 ].
# CALLER is in caller( 2 )[ 3 ] if it exists, otherwise caller( 1 )[ 0 ].
	$callee = ( caller( 1 ) )[ 3 ];
	$caller = caller( 2 ) ? ( caller( 2 ) )[ 3 ] : ( caller( 1 ) )[ 0 ];
	
	#_report( "Call:  $caller  ->  $callee" );
	
	return 1 unless %criteria = @_;
	
# Criteria are organized as follows:
# Inexact matches first, whitelist (=~) followed by blacklist (!~).
# Exact matches second, whitelist follwed by blacklist.
# Blacklists override whitelists and exact matches override inexact matches.
	$ok = 0;
	
	for ( @{ $criteria{ '=~' } } )
	{
		$ok = 1 if $caller =~ m|$_|;
	}
	
	for ( @{ $criteria{ '!~' } } )
	{
		$ok = 0 if $caller =~ m|$_|;
	}
	
	for ( @{ $criteria{ 'eq' } } )
	{
		$ok = 1 if $caller eq $_;
	}
	
	for ( @{ $criteria{ 'ne' } } )
	{
		$ok = 0 if $caller eq $_;
	}
	
	$msg = "Unauthorized call to $callee made by $caller.  Only the following may call $callee:\n";
	$msg .= 'Disallowed callers, exact match: ' . join( ', ', @{ $criteria{ 'ne' } } ) . "\n" if @{ $criteria{ 'ne' } };
	$msg .= 'Allowed callers, exact match: ' . join( ', ', @{ $criteria{ 'eq' } } ) . "\n" if @{ $criteria{ 'eq' } };
	$msg .= 'Disallowed callers, inexact match: ' . join( ', ', @{ $criteria{ '!~' } } ) . "\n" if @{ $criteria{ '!~' } };
	$msg .= 'Allowed callers, inexact match: ' . join( ', ', @{ $criteria{ '=~' } } ) . "\n" if @{ $criteria{ '=~' } };
	
	#$self->report( $msg ) if ! $ok && ! $criteria{ 'suppress_alerts' };
	if ( ! $ok && ! $criteria{ 'suppress_alerts' } )
	{
		$self->can( 'report' ) ? $self->report( $msg ) : print STDERR $msg;
	}
	
	return $ok;
}


sub caller_config
{
	return $caller_config;
}


sub caller_dir
{
	return $caller_dir;
}


sub caller_file
{
	return $caller_file;
}


sub caller_package
{
	return $caller_pkg;
}


# method _FLATTEN

sub _flatten
{
# WARN  HACK SOLUTION to the problem of returning "flattened" action map to action stage handlers.
# Someday come up with a better solution?
#	return %action_map if $caller1 eq 'Qoan::RequestManager::action_map';
#	
	my( $self, %flat, $hash_found, $compound, $fk );
	
	$self = shift();
	
	%flat = @_;
	$hash_found = 1;
	$compound = '';
	
	while ( $hash_found )
	{
		$hash_found = 0;
		
		for $fk ( keys %flat )
		{
			if ( ! ref( $flat{ $fk } ) )
			{
				next;
			}
			elsif ( ref( $flat{ $fk } ) eq 'ARRAY' )
			{
				$flat{ $fk } = join( ', ', @{ $flat{ $fk } } );
			}
			elsif ( ref( $flat{ $fk } ) eq 'HASH' )
			{
				$hash_found = 1;
				$compound = "$fk:";
				$flat{ "$compound$_" } = ${ $flat{ $fk } }{ $_ } for keys %{ $flat{ $fk } };
				delete $flat{ $fk };
			}
# "Stringify" value if an object ref.
			elsif ( ref $flat{ $_ } )
			{
				$flat{ $fk } = ref $flat{ $fk };
			}
		}
	}
	
	return %flat;
}


# method HANDLE_PARAMS
# public, class
# purpose:
#	Utility.  Configures option hash and returns to caller.
# usage:
#	self or class ref (not used)
#	array ref of option names
#	array ref of received option values, and optionally names

sub _handle_params
{
	#return undef unless $c->_allowed_caller( _PRIVATE() );
	#my( $c, @a, @set_true, %h, @tmp, $re );
	my( @opt_names, @opt_vals, $re, @tmp, %opts );
	
	#$c = shift if ref( $_[ 0 ] ) =~ /^q/i;
# Get rid of controller ref or class string.
	( undef ) = shift();
	
	@opt_names = @{ shift() };
	#@set_true = @{ $set_true[ 0 ] };
	@opt_vals = @{ shift() };
	
	$re = '^:[a-z_]+$';
	
# If first item in submitted option values list is not an option name,
# assume no names in values list; interleave with submitted names.
	if ( $opt_vals[ 0 ] !~ /$re/ )
	{
		$opts{ $opt_names[ $_ - 1 ] } = $opt_vals[ $_ - 1 ] for 1 .. @opt_names;
	}
	else
	{
		while ( $opt_vals[ 0 ] )
		{
# Shift leftmost value off @opt_vals if it's not an option name.
			if ( $opt_vals[ 0 ] !~ /$re/ ) { shift( @opt_vals ); next; }
# Shift off option name and following array item if it's a value (not a name). 
			$opts{ shift( @opt_vals ) } = ( $opt_vals[ 0 ] && $opt_vals[ 0 ] !~ /$re/ ) ? shift( @opt_vals ) : 1;
		}
	}
	
	return %opts;
	
#	for ( @set_true )
#	{
#		$opts{ $_ } = 1 if exists $opts{ $_ };
#	}
}


sub import
{
	my( $server, $ok );
	
	shift() if $_[ 0 ] eq __PACKAGE__;
	
	%start_params = @_;
	
# UNTAINT %start_params !!
# Main Config - file name only ???
# Caller Config - full path allowed.
# Server - string or hash ref..
	
# Default always includes config handler, logger, view renderer, request manager..
	$start_params{ 'server_load_order' } ||= [ ];
	
	for ( qw| request_manager  view  logger  config | )
	{
		next if join( ' ', @{ $start_params{ 'server_load_order' } } ) =~ m|\b$_\b|;
		unshift( @{ $start_params{ 'server_load_order' } }, $_ );
	}
	
# Server settings passed with the USE statement.
	$start_params{ 'server' } ||= { };
	$server = $start_params{ 'server' };
	
# If $server is a string, it names a config file which should contain server component
# settings.  $server will be changed to the expected hash reference (note that the
# retrieve call does not get the entire file, which would return a list, but a single
# member in the file, which should be a hash ref).
# The file must be readable by Qoan::Config.
	if ( $server && ! ref( $server ) )
	{
		__PACKAGE__->_require( 'Qoan::Config' );
		$server = Qoan::Config::retrieve_config( $server, 'server' );
	}
	
# Issue format warning; code will die below if the server parameter format is wrong.
	warn "Server parameter not in required hash ref format" unless ref( $server ) eq 'HASH';
	
# Default server packages.  Components without an interface setting will be superclassed.
	$server->{ 'config' }          ||= { 'module' => 'Qoan::Config' };
	$server->{ 'logger' }          ||= { 'module' => 'Qoan::Logger' };
	$server->{ 'request_manager' } ||= { 'module' => 'Qoan::RequestManager' };
# NOTE  view has no module declared; it works only through the interface.
	$server->{ 'view' }            ||= { 'interface' => 'Qoan::Interface::DefaultView',
					     'store' => 'views/' };
	
# Load Server components.
	for ( @{ $start_params{ 'server_load_order' } } )
	{
		$ok = 0;
		
# This block is for default Qoan packages, with no specified interface.
		if ( ( $server->{ $_ }{ 'module' } || '' ) =~ m|^Qoan::| && ! $server->{ $_ }{ 'interface' } )
		{
			$ok = __PACKAGE__->_require( $server->{ $_ }{ 'module' } );
			push @ISA, $server->{ $_ }{ 'module' };

		}
# This block is for any package with an interface, which is required for non-Qoan packages.
		elsif ( $server->{ $_ }{ 'interface' } )
		{
			$ok = __PACKAGE__->_load_component( $_, $server->{ $_ } );
		}
		
		die qq|Controller "$_" component failed to load: $@| unless $ok;
	}
	
# Change defaults if appropriate parameters received.
# Note that the "exists" check means the caller can pass empty values for the two
# config file variables, which means the controller will load nothing later.
	$main_config = $start_params{ 'main_config' } if exists $start_params{ 'main_config' };
	$caller_config = $start_params{ 'local_config' } if exists $start_params{ 'local_config' };
	
# Note that by passing empty main_config and caller_config parameters, the caller
# can prevent loading of these two config files.
	__PACKAGE__->load_config( $main_config ) if $main_config;
	__PACKAGE__->load_config( $caller_config ) if $caller_config;
# Startup parameters.
	__PACKAGE__->load_config( 'controller_start' => \%start_params );
	
	return 1;
}


sub _load_component ($$)
{
	my( $self, $component, %component, $before_load, $after_load, $object, $accessor, $stored_ref );
	
# For Controller-level components, $self will be the controller package name.
# For Request-Manager-level components, $self will be the Qoan controller object.
	$self = shift();
# This is the component NAME.
	$component = lc( shift() );
	%component = %{ shift() } if $_[ 0 ];  # SERVER COMPONENT ?
	
	return unless $self->_allowed_caller(
		'eq' => [ 'Qoan::Controller::import', 'Qoan::RequestManager::process_request' ],
		'=~' => [ 'Qoan::Interface::\w+::create' ]
	    );
	
# Get component settings.
	%component = $self->env( "component:$component" ) unless %component;

	
# Require interface module.  Import interface routines.
	$self->report( "Requiring component interface: $component{ 'interface' }.." );
	return 0 unless $self->_require( $component{ 'interface' } );
	return 0 unless $component{ 'interface' }->import( $self, $component );
	
# Pass request handler's environment name for component, if component
# allows aliases.
	if ( $component{ 'interface' }->can( 'set_name' ) )
	{
		$self->report( qq|Setting component's environment name to "$component"..| );
		$component{ 'interface' }->set_name( $component );
	}
	
# Routines imported from interface.
	$before_load = "_${component}_before_load";
	$after_load = "_${component}_after_load";
	
# Before Load handler must return a true value (indication that component
# must be loaded) or we skip component.
# Skipping non-necessary component counts as a load SUCCESS.
# It can also return contructor arguments as an ARRAY REF.
	$self->report( "Running before-load handler.." );
	return 1 unless $component{ 'init' } = $self->$before_load;
	
# Store init args if array ref was received.
# WARN?  remove? have before_load handler insert directly via component call?
	$self->env( "component:$component:init" => $component{ 'init' } )
		if ref( $component{ 'init' } ) eq 'ARRAY';
	
# Require component module.
	$self->report( "Requiring component module: $component{ 'module' }.." );
	return 0 unless $self->_require( $component{ 'module' } );
	
# Instantiate.  Uses returned argument array ref, or arguments saved to functional env.
	$self->report( 'Instantiating component object..' );
	$component{ 'init' } = [ $self->env( "component:$component:init" ) ]
		unless ref( $component{ 'init' } ) eq 'ARRAY';
	return 0 unless $object = $component{ 'module' }->new( @{ $component{ 'init' } } );
	
# After Load handler must return a true value to proceed.
	$self->report( "Running after-load handler for $object.." );
	return 0 unless $self->$after_load( $object );
	
# Supply object to accessor.
	$self->report( 'Submitting object to accessor..' );
	$accessor = $component{ 'accessor_alias' } || $component;
	$stored_ref = ref( $self->$accessor( $object ) );
	$self->report( "Ref from stored object: $stored_ref" );
	
	return 1 if $stored_ref eq $component{ 'module' };
	return 0;
}


sub load_helper
{
	my( $self, $helper, @helpers, $can_report, $msg, $ok );
	
	$self = shift();
	@helpers = @_;
	
	$can_report = $self->can( 'report' );
	$ok = 1;
	
	for $helper ( @helpers )
	{
		$ok &&= $self->_require( $helper );
		
# WARN  For some reason, running the following line as:
#         $ok &&= $helper->import;
#       causes the program to Die Without Passing Go.  In other words,
#       completely fails to generate error message.
		eval { $helper->import; };
		$ok &&= $@ ? 0 : 1;
		
		$msg = "Loading helper $helper.. " . ( $ok ? 'succeeded.' : "failed. $@" );
		$can_report ? $self->report( $msg ) : print STDERR "$msg\n";
		
		last unless $ok;
	}
	
	return $ok;
}


sub qoan_base_dir
{
	return $qoan_base_dir;
}


sub qoan_base_file
{
	return $qoan_base_file;
}


# method _REQUIRE  (private, class)
# purpose:
#	To securely require a module.
# usage:
#	Receives name of module to require.  Caller ref will preceed for
#	object method style calls.
# security:
#	This routine works only with the single value it receives.
#	It returns only a true/false value generated separate from the input.

sub _require
{
	my( $self, $module, $calling_pkg, $msg, $ok );
	
# $self will be either a Qoan::Controller (or subclass) object, or package name.
	$self = shift();
	$module = shift();
	$calling_pkg = ( caller( 0 ) )[ 0 ];
	
	if ( ! $module || ! $self )
	{
		$msg = 'Module to load missing or package self-identification missing.';
		$self->can( 'warn' ) ? $self->warn( $msg ) : warn( $msg );
		return 0;
	}
	
# WARN  commenting out self-load check; shouldn't matter anyway.
	#if ( $module eq __PACKAGE__ )
	#{
	#	$msg = "Call to Require to load its own package from $calling_pkg";
	#	#$self->warn( $msg ) if $self->can( 'warn' );
	#	$self->can( 'warn' ) ? $self->warn( $msg ) : warn( $msg );
	#	return 0;
	#}
	
# Regexes allow module barewords only.
	unless ( $module =~ m|^[\w:]+$| &&  # Verifies only allowed bareword chars.
		$module !~ m|^[\d:]| &&     # Verifies allowed starting char.
		$module !~ m|:$| &&         # Verifies allowed ending char.
		$module !~ m|::\d| )        # Verifies allowed starting char on each segment.
	{
		$msg = "Module name $module failed name check";
		$self->can( 'warn' ) ? $self->warn( $msg ) : warn( $msg );
		return 0;
	}
	
	local $@;
	$ok = eval "require $module; 1;";
	
	if ( ! $ok )
	{
		$msg = "Error on @{[ ref $self ]} module $module require: $@";
		$self->can( 'warn' ) ? $self->warn( $msg ) : warn( $msg );
		return 0;
	}
	
	return 1 if $ok;
}


sub _unload_component ($$)
{
	my( $self, $component, %component, $cleanup, $accessor, $object );
	
	$self = shift();
	$component = lc( shift() );
	
	return unless $self->_allowed_caller( 'eq' => [ 'Qoan::RequestManager::process_request' ] );
	
	%component = $self->env( "component:$component" );
	$accessor = $component{ 'accessor_alias' } || $component;
	
# If there's nothing to unload, we're good.
# Note that the 'return_object' parameter string is passed only because
# parameter-less calls to accessors from _unload_component will delete the
# component.
	unless ( $self->$accessor )
	{
		$self->report( 'No object to unload.' );
		return 1;
	}
	
# Cleanup routine imported from interface.
	$cleanup = "_${component}_cleanup";
	
	$self->report( 'Cleaning up for component..' );
	return 0 unless $self->$cleanup;
	
# Destroy component.
	$self->report( 'Destroying component..' );
	$object = $self->$accessor( 'remove' );
	$self->report( "@{[ $object ? 'FAILED.' : 'destroyed.' ]}" );
	
	return 1 unless $object;
	return 0;
}


1;
