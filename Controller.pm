
package Qoan::Controller;

# Qoan::Controller
#
# xxx

use strict;
#use Encode;


our $VERSION = '0.10';
our( @ISA );

my(
    $qoan_base_file,	# Controller package file
    $qoan_base_dir,	# Controller package home directory
    $qoan_base_config,	# Main Qoan configuration file
    $app_pkg,		# Calling application package name
    $app_script,	# Application script file
    $app_dir,		# Application script home directory
    $app_config,	# Application configuration file
    $handler_base,	# Base (pre-request-context) handler object
    %env_base,		# Base environment
    %env_default,	# Internal default environment values
    %env_startup,	# Environment values passed with USE statement
    $used,		# flag indicating import() called (usually by USE statement)
    );


# Setting variables prior to call to import().
BEGIN
{
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
	$qoan_base_dir = $qoan_base_file = ( caller( 0 ) )[ 1 ];
	$qoan_base_dir =~ s|[^/]+$||;
	
	( $app_pkg, $app_script ) = ( caller( 2 ) )[ 0, 1 ];
	$app_config = $app_dir = $app_script;
	$app_dir =~ s|[^/]+$||;
	#print STDERR "callerstuff: $app_pkg, $app_script, $app_dir, $app_config\n";
	
# Adds calling app's home directory and Qoan Local dirs for both main Qoan install
# and calling app's sibling Qoan respository.
	unshift( @INC, $app_dir, $app_dir . 'Qoan/Local', $qoan_base_dir . 'Local' );
	
# Default names for these two files.  These might be altered in import().
	$qoan_base_config = 'qoan.default.config';
	$app_config =~ s|\.\w+$|.config|;
	
	
# BASE HANDLER SET-UP
# The base handler is not intended for use during request handling, but rather only for
# access to the base environment prior to request handling.  Basically, it provides an
# interface to the base env that is consistent with that provided during request handling.
# This allows the same routines to call env within and without a request context.
	$handler_base = sub {
		local *__ANON__ = 'base_closure';
		my( $store, $k, $v, @keypath, $index, $loc, $i );
		
# Only env may access the base closure.
		return unless __PACKAGE__->_allowed_caller( 'eq' => [ 'Qoan::Controller::env' ] );
		
		$store = \%env_base;
		return %{ $store } unless @_;
		
# Closure receives either a set of key-value pairs, to update a hash,
# or a single hash key, to read; hence the unusual stepping used here.
		for ( $i = 0; $i < @_; $i += 2 )
		{
			( $k, $v ) = @_[ $i, $i + 1 ];
			
# Compound index processing.
			@keypath = split( ':', $k );
			$index = pop( @keypath );
			$loc = $store;
			for ( @keypath )
			{
				$loc->{ $_ } = { } unless defined $loc->{ $_ };
				$loc = $loc->{ $_ };
			}
			
# Update if value submitted with key.
			if ( $v )
			{
				if ( $v =~ m|^\[ARRAY\]| )
				{
					$v =~ s|^\[ARRAY\]||;
					$v = [ split( " \e ", $v ) ];
					$loc->{ $index } = $v;
				}
				elsif ( ref( $loc->{ $index } ) eq 'ARRAY' && ! ref $v )
				{
					push( @{ $loc->{ $index } }, $v );
				}
				else
				{
					#if ( $v =~ m|\e| )
					#{
					#	$v =~ s|^\[ARRAY\]||;
					#	$v = [ split( "\e", $v ) ];
					#}
					
					$loc->{ $index } = $v;
				}
			}
		}
		
# Return last index's value.
		return %{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'HASH';
		return @{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'ARRAY';
		return $loc->{ $index } if exists ${ $loc }{ $index };
# Return zero-len string if non-existent value requested (stops "uninitialized" warnings).
# NOTE, not using this currently.
		#return '' if $index;
# Probably not useful, so, for sanity's sake.
		return;
	};
	
	bless( $handler_base, __PACKAGE__ );
	
# DEFAULT INTERNAL ENV SET-UP
	%env_default = (
		'action_stages'        => [ qw| identify  check  execute  cleanup | ],
		'request_stages'       => [ qw| prestart  map  load  action  render  unload  response  cleanup  finished | ],
		'component_load_order' => [ qw| request  session  user | ],
# NOTE  that the config tool ALWAYS loads first, so does not appear in server_load_order.
		'server_load_order'    => [ qw| logger  view | ],
		'qoan_view_store'      => 'views/',
		'uri_source_header'    => 'request_uri',
		'sessionid_variable'   => 'qoan_session',
		'userid_variable'      => 'qoan_user',
		'qoan_started'         => time(),
		'closure_accessors'    => [ map { __PACKAGE__ . "::$_" } qw| action_map  component  env  ok  publish  response | ],
		'publish'              => { 
			'action_manager' => { 'env' => 'env' },
			'view'           => { 'env' => 'env' },
		},
		'component'            => {
			'request' => {
				'module'    => 'CGI::Minimal',
				'interface' => 'Qoan::Interface::IRequest_CGIMinimal'
			},
# NOTE  the session store path is wrong; it should include the tmp dir path.
# Set here as a placeholder.  Set again after config file load.
			'session' => {
				'module'    => 'Qoan::Model::Minicache',
				'interface' => 'Qoan::Interface::ISession_QoanModelMinicache',
				'store'     => 'sessions/'
			},
			'user'    => {
				'module'    => 'Qoan::Model::Minicache',
				'interface' => 'Qoan::Interface::IUser_QoanModelMinicache',
				'store'     => 'users/'
			},
			'view'    => {
				'interface' => 'Qoan::Interface::IView_QoanView',
				'module' => 'Qoan::View',
				'store' => 'views/'
			},
			'config'  => { 'module' => 'Qoan::Config' },
			'logger'  => { 'module' => 'Qoan::Logger' },
			#'request_manager' => { 'module' => 'Qoan::RequestManager' },
		},
	);
}


# Just being present and accounted for.
sub DESTROY
{
	;
}

sub _action_check
{
	my( $q, $manager, $action, %checks, @order, $handler, $check_ok );
	
	$q = shift();
	
	$manager = $q->env( 'action_manager:name' );
	$action = $q->env( 'action:name' );
	
# Note, following line is for if main closure returns '' (instead of nothing)
# on request for non-existent member.
	#%checks = ( $q->action_map( "$action:checks" ) || ( ) ) if $action;
	%checks = $q->action_map( "$action:checks" ) if $action;
	
	#$q->report( "checks: *@{[ join( '*', sort keys %checks ) ]}*" );
	
	@order = sort { $checks{ $a }{ 'order' } <=> $checks{ $b }{ 'order' } } keys %checks;
	$q->report( 'Checks defined for this action: ' . @order );
	
	$check_ok = 1;
	
	for ( @order )
	{
# If there is no handler in the check, use the check name to find one.
		$handler = $checks{ $_ }->{ 'handler' } || $_;
		
		if ( ref( $handler ) eq 'CODE' )
		{
			$check_ok &&= $handler->();
		}
		else
		{
			{
			 no strict 'refs';
			 $handler = \&{ $manager . '::' . $handler };
			}
			
			$check_ok &&= $handler->();
		}
		
		$q->env( "action:check:$_:ok" => $check_ok );
		$q->report( "Check $_ ran with result: $check_ok" );
		
		unless ( $check_ok )
		{
			$q->env( 'render_view' => $checks{ $_ }->{ 'view_on_fail' } );
			last;
		}
	}
	
	return 1 if $check_ok;
	return 0;
}


sub _action_cleanup
{
	my( $q );
	$q = shift();
	
	
	return 1;
}


sub _action_execute
{
	my( $q, $manager, $action, $has_handler, $handler, $exec_ok );
	
	$q = shift();
	$exec_ok = 0;
	
	$manager = $q->env( 'action_manger:name' );
	$action = $q->env( 'action:name' );
	
# Verify action exists in map.
	unless ( $q->action_map( $action ) )
	{
		warn( 'Action to execute missing from map!' ) unless $q->action_map( $action );
		return 0;
	}
	
# Get handler.
	$handler = ( $q->action_map( "$action:handler" ) || $action ) if $action;
	
# Change handler value to code ref if it is a string.
	if ( $manager && $handler && ref( $handler ) ne 'CODE' )
	{
		no strict 'refs';
		$handler = \&{ $manager . '::' . $handler };
	}
	
	if ( ref( $handler ) ne 'CODE' )
	{
# If no handler but the request is a GET, skip execution with success.
		if ( ! $q->is_write_request )
		{
			$q->report( 'Not a write request; skipping stage with success.' );
			return 1;
		}
		
# If no handler and the request is a POST, Fail execution.
		if ( $q->is_write_request )
		{
			$q->report( 'Failed execution due to missing handler on POST.' );
			$q->env( 'render_view' => $q->action_map( "$action:view_on_fail" ) );
			return 0;
		}
	}
	
# Execute if a code ref.
	if ( ref( $handler ) eq 'CODE' )
	{
		$exec_ok = 1 if $handler->();
	}
	
	$q->report( "Action result: $exec_ok" );
	
# Set view to be rendered.
	$q->env( 'render_view' => $q->action_map( "$action:view" ) ) if $exec_ok;
	$q->env( 'render_view' => $q->action_map( "$action:view_on_fail" ) ) if ! $exec_ok;
	
	return 1 if $exec_ok;
	return 0;
}


# method _ACTION_IDENTIFY
# purpose:
#	.
# usage:
#	.
sub _action_identify ($)
{
	my( $q, %map, @order, $i, $req_uri );
	my( $action, $route, @routes, @compared, $identified );
	my( @symbols );
	
	$q = shift();
	$i = 0;
	
	if ( %map = $q->action_map )
	{
# Check URI against action map routes.
# Note that if there is no "order" member in the checks, a meaningless order is substituted
# (prevents warning).  Not sure at this time (Feb 2012) if that's the right solution.
		@order = sort { ( $map{ $a }{ 'order' } || ++$i ) <=> ( $map{ $b }{ 'order' } || ++$i ) }
			grep { ref( $map{ $_ } ) eq 'HASH' } keys %map;
		$req_uri = $q->env( 'uri:complete' );
		
		for $action ( @order )
		{
# NEXT THING HERE: @ROUTES ??
			$route = $map{ $action }{ 'route' };  # just to make next line readable
			#@routes = ref( $route ) eq 'ARRAY' ? @{ $route } : $route;
			$q->report( "Comparing URI to route for action:  $action.." );
			
			#for ( @routes )
			for ( ref( $route ) eq 'ARRAY' ? @{ $route } : $route )
			{
				$q->report( " route: $_" );
				
				if ( @compared = $q->_route_compare( $_, $req_uri ) )
				{
					$identified = $action;
					$route = $_;
				}
			}
			
			last if $identified;
		}
		
# If no route matched, check for default map action.
		if ( ! $identified && exists $map{ 'default_action' } )
		{
			$identified = $map{ 'default_action' };
		}
	}
	
# Try grabbing action from URI if none found with action map.
	if ( ! $identified && ( $route = $q->env( 'default_route' ) ) )
	{
		$identified = $compared[ -1 ] if @compared = $q->_route_compare( $route, $req_uri );
	}
	
# If URI contains symbols, parse and store in env.
# Note that an ":action" symbol in a route can override an identified action name.
	if ( $identified && $route =~ m|/?:\w+/?| )
	{
		@symbols = ( $route =~ m|:(\w+)|g );
		
		for ( 0 .. $#compared )
		{
			$q->env( "uri:$symbols[ $_ ]" => $compared[ $_ ] );
			$identified = $compared[ $_ ] if $symbols[ $_ ] eq 'action';
		}
	}
	
	$q->env( 'action:name' => $identified );
	$q->env( 'action:route' => $route );
	$q->report( "action identified: @{[ $identified || 'none' ]}" );
	$q->report( "action route: @{[ $route || '' ]}" ) if $identified;
	
	return 1 if $identified;
	return 0;
}


# method ACTION_MAP

sub action_map
{
	my( $q, %map, $can_edit, $flatten, $caller );
	
	$q = shift();
	$can_edit = 0;
	$flatten = 0;
	
# Reading a value.
	return $q->( $_[ 0 ] ) if @_ == 1;
	
	#$caller = caller( 1 ) ? ( caller( 1 ) )[ 3 ] : ( caller( 0 ) )[ 0 ];
	$caller = ( caller( 1 ) )[ 3 ] || ( caller( 0 ) )[ 0 ];
	
# Action map can be changed:
#	by the request processing routine;
#	by the application package before processing starts.
	$can_edit = 1 if $caller eq 'Qoan::Controller::process_request';
	$can_edit = 1 if ! $q->request_stage &&
		$q->_allowed_caller( 'eq' => [ $q->app_package ], 'suppress_alerts' => 1 );
	%map = @_ if $can_edit;
	
# Call to Main Closure.
	$q->( %map );
	%map = $q->( );
	
# Flatten map if we've exited the prestart stage (processing has started)
# and caller is unprotected.
	#$flatten = 1 if $q->env( 'request_stage' ) != _prestart() &&
	$flatten = 1 if ! $q->request_stage &&
		$q->_allowed_caller( '!~' => [ $q->env( 'protected' ) ], 'suppress_alerts' => 1 );
	
	%map = $q->_flatten( %map ) if $flatten;
	
	return %map;
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


sub app_config
{
	return $app_config;
}


sub app_dir
{
	return $app_dir;
}


sub app_script
{
	return $app_script;
}


sub app_package
{
	return $app_pkg;
}


# method COMPONENT (public, object)
# purpose:
#	Custom ENV accessor, for component settings only.
# usage:
#	Self.
#	Optional hash key(s) (for component value from %env) or submitted component
#	object (to be added to %component).

# loading object: called by accessor, & parameter is non-hash/array REF.
# fetching object: called by accessor, no params.
# unloading object: called by accessor with 'REMOVE' parameter
# data from object: called by accessor with 'DATA' parameter
# settings for component: called by accessor with 'SETTINGS' parameter
# called by non-object-accessor: returns env component settings - requires IDing the object e.g. "request" parameter
# NO - not useful because it requires id'ing the object. called by non-object_accessor with 'DATA' parameter: returns object values from env

sub component ($;@)
{
	my( $q, @params );
	my( $writing, $reading, $caller );
	my( %component_list, $name, $settings );
	my( $load_obj, $unload_obj, $get_obj, $data_call, $settings_call );
	
	$q = shift();
	$q = $handler_base if ! ref( $q ) && $q eq __PACKAGE__;
	
# Note, $writing and $reading are used with settings and data only.
	@params = @_;
	$writing = ( @params > 1 );
	$reading = ( @params == 1 );
	
	$params[ 0 ] ||= '';
		
	$caller = ( caller( 1 ) )[ 3 ];
	
	#if ( ref( $param ) eq 'HASH' || ref( $param ) eq 'ARRAY' )
	#{
	#	$q->warn( "$caller called component routine with disallowed parameter @{[ ref $param ]}" );
	#	return;
	#}
	
	if ( $caller =~ m|::accessor$| )
	{
		%component_list = $q->env( 'component' );
		
		while ( ( $name, $settings ) = each %component_list )
		#while ( ( $name, $settings ) = each %{ $q->env( 'component' ) } )
		{
			last if $caller =~ m|^${ $settings }{ 'interface' }|;
		}
		
# Component can interact with the component objects, the stored component settings,
# or data loaded from the component to the functional env.
# For the latter two, component changes the parameter to refer to the appropriate
# section of %env, which allows access to specific values in those sections.
		
		$load_obj = $unload_obj = $get_obj = $data_call = $settings_call = 0;
		
# Note that unloading can only happen during the unload stage; but loading
# is not restricted to a stage, because we might need to create a component
# during the request.
		$load_obj = 1 if ref( $params[ 0 ] ) eq $settings->{ 'module' } &&
			! defined( $q->( $name ) );
# Note, following is for when main closure returns '' (instead of nothing)
# on request for non-existent member.
			#! $q->( $name );
		$unload_obj = 1 if $params[ 0 ] eq 'remove' &&
			$q->request_stage( 'current' => 'unload' );
		$get_obj = 1 if ! $params[ 0 ];
		
# Component object related.
		if ( $load_obj || $unload_obj || $get_obj )
		{
			return $get_obj
				? $q->( $name )
				: $q->( $name => $params[ 0 ] );
		}
		
		$data_call = 1 if $params[ 0 ] =~ m|^data\b|i;
		$settings_call = 1 if $params[ 0 ] =~ m|^settings\b|i;
		
		if ( $reading )
		{
			$data_call = ( $params[ 0 ] =~ s|^data|$name|i );
			$settings_call = ( $params[ 0 ] =~ s|^settings|component:$name|i );
			
			if ( $data_call || $settings_call )
			{
				return $q->env( $params[ 0 ] );
			}
			else
			{
				return $q->env( "component:$name:$params[ 0 ]" ) ||
					$q->env( "$name:$params[ 0 ]" );
			}
		}
		elsif ( $writing )
		{
			my( $i );
			
			for ( $i = 0; $i < @params; $i += 2 )
			{
				$data_call = ( $params[ $i ] =~ s|^data|$name|i );
				$settings_call = ( $params[ $i ] =~ s|^settings|component:$name|i );
				$params[ $i ] = "$name:$params[ $i ]" unless $data_call || $settings_call;
			}
			
			return $q->env( @params );
		}
		
		warn "Component routine unable to fulfill request from $caller";
	}
	else
	{
		return $q->env( "component:$params[ 0 ]" );
	}
}


# method ENV  (public, object)
# purpose:
#	Access to object's functional environment.
#	The functional env is read-write before request processing begins; then
#	stored values become read-only.  New values may be added (and are read-only).
# usage:
#	Self.
#	Optionally: a value key;
#	  or list of hash refs of env settings and config file names to load.

sub env
{
	my( $q, $editable, $reading, $cfg_load, $caller, %writing );
	
	$q = shift();
# Class method call style means use handler base object.
	$q = $handler_base if ! ref( $q ) && $q eq __PACKAGE__;
	
	$editable = 0;
	$reading = '';
	$cfg_load = '';
		
	$caller = ( caller( 1 ) )[ 3 ] || '';
	
# If no parameters, return the entire functional env, flattened.
	return $q->_flatten( $q->( ) ) unless @_;
	
	$cfg_load = shift() if ref( $_[ 0 ] ) eq 'ARRAY';
	$reading = shift() if @_ == 1;
	%writing = @_;
	
# Values in env can be changed before processing starts, or by the processing routine.
# NOTE  can't call request_stage() here, because that relies on env().
	$editable = 1 if ! defined $q->( 'request_stage' );
	$editable = 1 if $caller eq 'Qoan::Controller::process_request';
	
# Caller can pass a list of config file names and hash refs containing env key-value
# pairs in an array ref.  It must be the first parameter.
# This kind of mass-update is only allowed if env is "editable" (even if all the values are new).
	if ( $cfg_load )
	{
		return unless $editable;
		
		for ( @{ $cfg_load } )
		{
			$q->( __PACKAGE__->retrieve_config( $_ ) ) if ! ref $_;
			$q->( %{ $_ } ) if ref( $_ ) eq 'HASH';
		}
		
		return 1;  # ??? return value after config load??
	}
	
# Only a single key parameter submitted, return the value.
	return $q->( $reading ) if $reading;
	
# Remove keys with defined values if env is not editable.
	if ( ! $editable )
	{
		for ( keys %writing )
		{
			delete $writing{ $_ } if defined $q->( $_ );
# Note, following is used when main closure returns '' (instead of nothing)
# on request for non-existent member.
			#delete $writing{ $_ } if $q->( $_ );
		}
	}
	
	return $q->( %writing );
}


# method _FLATTEN

sub _flatten
{
# WARN  HACK SOLUTION to the problem of returning "flattened" action map to action stage handlers.
# Someday come up with a better solution?
#	return %action_map if $caller1 eq 'Qoan::RequestManager::action_map';
#	
	my( $self, %flat, $hash_found, $compound, $startup, $fk );
	
	$self = shift();
	
	%flat = @_;
	$hash_found = 1;
	$compound = '';
	
# Do not stringify array refs if we're starting up.
# Yes, hacky, but also easy and convenient.
#	$startup = ( caller( 1 ) )[ 3 ] eq 'Qoan::Controller::import';
	
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
				$flat{ $fk } = '[ARRAY]' . join( " \e ", @{ $flat{ $fk } } );
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
	my( $class, %start_config, $ok, %load_cfg, $server );
	my( $k, $v );
	
# $used flag is set at the end of this sub.  Qoan::Controller uses import to
# initialize the pre-request environment, and after that nothing should call it.
	return if $used;
	
	$class = shift() if $_[ 0 ] eq __PACKAGE__;
	
# USE statement parameters.
	%env_startup = @_;
#	%env_startup = __PACKAGE__->_flatten( %env_startup );
	#print STDERR " :start: $_ => $env_startup{ $_ }\n" for sort keys %env_startup;
	
#	%env_default = __PACKAGE__->_flatten( %env_default );
	#print STDERR " :deflt: $_ => $env_default{ $_ }\n" for sort keys %env_default;
	
# UNTAINT %env_startup !!
# Main Config - file name only ???
# Caller Config - full path allowed.
# Server - string or hash ref..
	
#	$start_config{ $_ } = $env_default{ $_ } for grep { /^component:config/ } keys %env_default;
#	$start_config{ $_ } = $env_startup{ $_ } for grep { /^component:config/ } keys %env_startup;
	#print STDERR " :cfg__: $_ => $start_config{ $_ }\n" for sort keys %start_config;
	$start_config{ $k } = $v while ( $k, $v ) = each %{ $env_default{ 'component' }->{ 'config' } };
	$start_config{ $k } = $v while ( $k, $v ) = each %{ $env_startup{ 'component' }->{ 'config' } };
	
#	for ( keys %start_config )
#	{
#		#$shorten = ( $_ =~ m|(\w+)$| )[ 0 ];
#		$start_config{ ( $_ =~ m|(\w+)$| )[ 0 ] } = delete( $start_config{ $_ } );
#	}
	#print STDERR " :cfg__: $_ => $start_config{ $_ }\n" for sort keys %start_config;
	
# Load Config tool.
	if ( $start_config{ 'module' } eq 'Qoan::Config' )
	{
		$ok = __PACKAGE__->_require( $start_config{ 'module' } );
		push @ISA, 'Qoan::Config';
	}
	else
	{
		$ok = $handler_base->_load_component( 'config', %start_config );
	}
	
# Config tool MUST load successfully.
	die "Failed to load config tool $start_config{ 'component:config:module' }" unless $ok;
	#$ok = 0;
	
# USE statement params can include 'component:config:use_file', which indicates that the
# Controller must load "env_startup" from a file.
# Values in this file OVERWRITE ALL values passed in %env_startup.
# Values in this file have the same priority as values passed in %env_startup (they override everything).
# Note that retrieve_config is called here as a class method.
# Note that config component settings are copied back into %env_startup; this
# means that any config component settings in the use_file are not used.
	if ( $start_config{ 'use_file' } )
	{
		%env_startup = __PACKAGE__->retrieve_config( $start_config{ 'use_file' } );
		#%env_startup = __PACKAGE__->_flatten( %env_startup );
		#$env_startup{ "component:config:$_" } = $start_config{ $_ } for keys %start_config;
		$env_startup{ 'component' }->{ 'config' }{ $k } = $v while ( $k, $v ) = each %start_config;
	}
	
# Change defaults if appropriate parameters received.
# Note that the "exists" check means the caller can pass empty values for the two
# config file variables, which means the controller will load nothing from these files.
	$qoan_base_config = $env_startup{ 'qoan_base_config' } if exists $env_startup{ 'qoan_base_config' };
	$app_config = $env_startup{ 'app_config' } if exists $env_startup{ 'app_config' };
	
# Store startup parameters.
	__PACKAGE__->load_config( 'controller_start' => \%env_startup );
	
# Add config value sets to base env.
	for ( \%env_default, $qoan_base_config, $app_config, \%env_startup )
	{
		next unless $_;  # Skip config file names if empty.
		#%load_cfg = ref( $_ ) eq 'HASH' ? %{ $_ } : Qoan::Controller->retrieve_config( $_ );
		%load_cfg = ref( $_ ) eq 'HASH' ? %{ $_ } : __PACKAGE__->retrieve_config( $_ );
		%load_cfg = __PACKAGE__->_flatten( %load_cfg );
		__PACKAGE__->env( %load_cfg );
	}
	#print STDERR " :base_: $_ => $env_base{ $_ }\n" for sort keys %env_base;
	
	
	
# Default always includes config handler, logger, view renderer..
	#$env_startup{ 'server_load_order' } ||= [ ];
	
	if ( ref( $env_base{ 'server_load_order' } ) eq 'ARRAY' )
	{
		for ( reverse @{ $env_default{ 'server_load_order' } } )
		{
			next if join( ' ', @{ $env_base{ 'server_load_order' } } ) =~ m|\b$_\b|;
			unshift( @{ $env_base{ 'server_load_order' } }, $_ );
		}
	}
	
# Load Server components.
	for ( @{ $env_base{ 'server_load_order' } } )
	{
# Do not reload the config component (would only happen if 'config' has been
# inserted into server_load_order.
		next if $_ eq 'config';
		
		$ok = 0;
		$server = $env_base{ 'component' }->{ $_ };
		
# This block is for default Qoan packages, with no specified interface.
		if ( ( $server->{ 'module' } || '' ) =~ m|^Qoan::| && ! $server->{ 'interface' } )
		{
			$ok = __PACKAGE__->_require( $server->{ 'module' } );
			push @ISA, $server->{ 'module' };

		}
# This block is for any package with an interface, which is required for non-Qoan packages.
		elsif ( $server->{ 'interface' } )
		{
			$ok = $handler_base->_load_component( $_, $server );
		}
		
		die qq|Controller "$_" component failed to load: $@| unless $ok;
	}
	
	$used = 1;  # Can't call import again.
	
	return 1;
}


# method IS_WRITE_REQUEST  (public, object)
# purpose:
#	Returns whether request will include writing data store.
#	Defaults to checking REQUEST_METHOD environment variable.
#	Overwrite for alternate criteria (e.g. to allow writing on GETs).
# usage:
#	Self.

sub is_write_request ($)
{
	return unless ref $_[ 0 ];
	return $_[ 0 ]->env( 'sys_env:request_method' ) eq 'POST';
}


sub _load_component ($$)
{
	my( $self, $component, %component, $new, $before_new, $after_new, $object, $accessor, $stored_ref );
	
# For Controller-level components, $self will be the controller package name.
# For Request-Manager-level components, $self will be the Qoan controller object.
	$self = shift();
	
# This is the component NAME.
	$component = lc( shift() );
	%component = %{ shift() } if $_[ 0 ];  # SERVER COMPONENT ?
	
	return unless $self->_allowed_caller(
		'eq' => [ 'Qoan::Controller::import', 'Qoan::Controller::process_request' ],
		#'=~' => [ 'Qoan::Interface::\w+::create' ]
		'=~' => [ '^Qoan::Interface::\w+::\w+' ]  # Basically, allows interfaces to instantiate
	    );
	
# Get component settings.
	%component = $self->env( "component:$component" ) unless %component;
	
# Require interface module.  Import interface routines.
	$self->report( "Requiring component interface: $component{ 'interface' }.." );
	return 0 unless $self->_require( $component{ 'interface' } );
	return 0 unless $component{ 'interface' }->import( $self, $component );
	
## Pass request handler's environment name for component, if component
## allows aliases.
#	if ( $component{ 'interface' }->can( 'set_name' ) )
#	{
#		$self->report( qq|Setting component's environment name to "$component"..| );
#		$component{ 'interface' }->set_name( $component );
#	}
	
	return 1 if $self->request_stage( 'current' => 'load' ) &&
		( $component{ 'on_load' } || '' ) eq 'interface_only';
	
# Routines imported from interface.
	$before_new = "_${component}_before_new";
	$after_new = "_${component}_after_new";
	
# Before_New handler must return a true value (indication that component
# must be loaded) or we skip component.
# Skipping non-necessary component counts as a load SUCCESS.
# It can also return contructor arguments as an ARRAY REF.
	$self->report( "Running before-new handler.." );
	return 1 unless $component{ 'init' } = $self->$before_new;
	
# Store init args if array ref was received.
# WARN?  remove? have before_new handler insert directly via component call?
	$self->env( "component:$component:init" => $component{ 'init' } )
		if ref( $component{ 'init' } ) eq 'ARRAY';
	
# Require component module.
	$self->report( "Requiring component module: $component{ 'module' }.." );
	return 0 unless $self->_require( $component{ 'module' } );
	
# Instantiate.  Uses returned argument array ref, or arguments saved to functional env.
	$self->report( 'Instantiating component object..' );
	$component{ 'init' } = [ $self->env( "component:$component:init" ) ]
		unless ref( $component{ 'init' } ) eq 'ARRAY';
	$new = $component{ 'constructor' } || 'new';
	return 0 unless $object = $component{ 'module' }->$new( @{ $component{ 'init' } } );
	
# After_New handler must return a true value to proceed.
	$self->report( "Running after-new handler for $object.." );
	return 0 unless $self->$after_new( $object );
	
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
		#$ok &&= $@ ? 0 : 1;
		$ok = 0 if $@;
		
		$msg = "Loading helper $helper.. " . ( $ok ? 'succeeded.' : "failed. $@" );
		$can_report ? $self->report( $msg ) : print STDERR "$msg\n";
		
		last unless $ok;
	}
	
	return $ok;
}


# method MAP_ACTION
# usage:
#	Self.
#	List of actions in name => ref or action name format.

sub map_action ($;@)
{
	my( $q, %action );
	
	$q = shift();
	%action = @_;
	
	$action{ "$_:action" } = delete $action{ $_ } for keys %action;
	
	$q->action_map( %action );
	
	return 1;
}


# method VALIDATION

sub map_check
{
	my( $q, %validation );
	
	$q = shift();
	%validation = @_;
	
	$validation{ "$_:validation" } = delete $validation{ $_ } for keys %validation;
	
	$q->action_map( %validation );
	
	return 1;
}


# method ROUTE

sub map_route ($;@)
{
	my( $q, %route );
	
	$q = shift();
	%route = @_;
	
	$route{ "$_:route" } = delete $route{ $_ } for keys %route;
	
	$q->action_map( %route );
	
	return 1;
}


# method MAP_VIEW

sub map_view
{
	my( $q, %view );
	
	$q = shift();
	%view = @_;
	
	$view{ "$_:view" } = delete $view{ $_ } for keys %view;
	
	$q->action_map( %view );
	
	return 1;
}


sub _method
{
	my( $q, $method, @params, $calling_pkg, %components, $component, %allowed, $env_allowed );
	
	$q = shift();
	@params = @_;
	#$q->report( "component _method called: @params" );
	
	$method = '';
	$calling_pkg = '';
	$component = '';
	$env_allowed = 0;
	
# Determine caller's component.
# Note that calling package is the one calling the *previous* routine, not caller of _method.
	$calling_pkg = ( caller( 1 ) )[ 0 ];
	%components = $q->component;
	
	for ( keys %components )
	{
		$component = $_ if $calling_pkg eq $components{ $_ }->{ 'module' };
		last if $component;
	}
	
	$component = 'action_manager' if $calling_pkg eq $q->env( 'action_manager:name' ) ||
		$calling_pkg eq $q->app_package;
	
	unless ( $component )
	{
		warn "Caller @{[ ( caller( 2 ) )[ 3 ] ]} in package $calling_pkg " .
			"attempted controller access with parameters: @params";
		return;
	}
	
# Get method name from list of those published to this component.
	#$method = $q->publish( "$component:$method" );
	
# Find requested method in published list for component.
	%allowed = $q->publish( $component );
	#$q->report( " _meth: $_ => $allowed{ $_ }" ) for sort keys %allowed;
	
	for ( keys %allowed )
	{
		$method = shift( @params ) if @params && $params[ 0 ] eq $_;
		#$env_allowed = 1 if $allowed{ $_ } eq 'env';
	}
	
# If no method found, but env is allowed, default to env.
	#$method = 'env' if ! $method && $env_allowed;
	#$q->report( "_method method: $method" );
	
	return $q->$method( @params ) if $method;
	return;
}


# method NEW  (public, class)
# purpose:
#	New request constructor.
# usage:
#	Class name, which can be subclass name.
#	Optional config file paths, config settings hash refs.


sub new_request
{
	my( $class, %load_cfg, %env, %ro, %component, %action_map, %response, %publish, $q, $k, $v );
	
	$class = shift();
	
	return unless $class->_allowed_caller(
		'eq' => [ 'Qoan::Controller::process_request', $class->app_package ], '!~' => [ 'Qoan::' ] );
	
# Bootstrap accessor setting.
# WARN  what if Controller.pm is subclassed?  how do we know which package has env in it?
	$env{ 'closure_accessors' } = [ $class . '::env' ];
	
# BEGIN REQUEST CONTEXT CLOSURE.
	$q = sub {
		local *__ANON__ = 'request_closure_' . time();
		my( $caller, $store, $k, $v, @keypath, $index, $loc, $i );
		
		return unless $q->_allowed_caller( 'eq' => $env{ 'closure_accessors' } );
		
		$caller = ( caller( 1 ) )[ 3 ];
		
		#if ( $caller =~ m/(?:env|ok)$/ ) # 'Qoan::Controller::env' )
		#{
		#	$store = \%env;
		#}
		#else
		#{
		#	my $subname = ( $caller =~ m|(\w+)$| )[ 0 ];
		#	$ro{ $subname } = { } unless defined $ro{ $subname };
		#	$store = \$ro{ $subname };
		#}
		
		$store =
			$caller eq 'Qoan::Controller::env' ? \%env :
			$caller eq 'Qoan::Controller::ok' ? \%env :
			$caller eq 'Qoan::Controller::component' ? \%component :
			$caller eq 'Qoan::Controller::publish' ? \%publish :
			$caller eq 'Qoan::Controller::response' ? \%response :
			$caller eq 'Qoan::Controller::action_map' ? \%action_map : undef;
		
		return unless defined $store;
		return %{ $store } unless @_;
		
# This block is only for removal of components.
		if ( $caller eq 'Qoan::Controller::component' && $_[ 1 ] && $_[ 1 ] eq 'remove' )
		{
			( $k, $v ) = @_;
			$store->{ $k } = undef;
			return $store->{ $k };
		}
		
# Main closure receives either a set of key-value pairs, to update a hash,
# or a single hash key, to read; hence the unusual stepping used here.
		for ( $i = 0; $i < @_; $i += 2 )
		{
			( $k, $v ) = @_[ $i, $i + 1 ];
			
# Compound index processing.
			@keypath = split( ':', $k );
			$index = pop( @keypath );
			$loc = $store;
			for ( @keypath )
			{
				#$loc->{ $_ } = { } if $v && ! defined $loc->{ $_ };
				$loc->{ $_ } = { } unless defined $loc->{ $_ };
				$loc = $loc->{ $_ };
			}
			
# Update if value submitted along with key.
			if ( $v )
			{
				if ( $index eq 'ok' && $caller eq 'Qoan::Controller::ok' )
				{
					$loc->{ $index } &&= $v;
				}
				elsif ( $v =~ m|^\[ARRAY\]| )
				{
					$v =~ s|^\[ARRAY\]||;
					$v = [ split( " \e ", $v ) ];
					$loc->{ $index } = $v;
				}
				elsif ( ref( $loc->{ $index } ) eq 'ARRAY' && ! ref $v )
				{
					push( @{ $loc->{ $index } }, $v );
				}
				else
				{
					#if ( $v =~ m|\e| )
					#{
					#	$v =~ s|^\[ARRAY\]||;
					#	$v = [ split( "\e", $v ) ];
					#}
					
					$loc->{ $index } = $v;
				}
			}
		}
		
# Return last index's value.
		return %{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'HASH';
		return @{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'ARRAY';
		return $loc->{ $index } if exists ${ $loc }{ $index };
# Return zero-len string if non-existent value requested (stops "uninitialized" warnings).
# NOTE, not using this currently.
		#return '' if $index;
# Probably not useful, so, for sanity's sake.
		return;
		
		};
# END REQUEST CONTEXT CLOSURE
	
# Blesses handler as Qoan::Controller or subclass.
	bless( $q, $class );
	
	
# Set base environment.
# Call to env returns entire environment flattened.
	$q->env( $class->env );
	
# Load config values passed with call to new_request.
# UNTAINT
	for ( @_ )
	{
		%load_cfg = ref( $_ ) eq 'HASH' ? %{ $_ } : $class->retrieve_config( $_ );
		$q->env( $class->_flatten( %load_cfg ) );
	}
	
	
# LAST REQUEST CONTEXT ENV SETTINGS:
# Add system environment.
	$env{ 'sys_env' }{ lc( $_ ) } = $ENV{ $_ } for keys %ENV;
	
# Accessors from this package.
	#push( @{ $env{ 'closure_accessors' } }, map { __PACKAGE__ . "::$_" } qw| action_map  ok  response | );
	
# WARN  what if Controller is subclassed?  What effect would that have here?
	$env{ 'protected' } ||= [ __PACKAGE__ , $class ne __PACKAGE__ ? $class : ( ) ];
	$env{ 'action_manager' }->{ 'type' } = 'static_config' if $env{ 'action_manager' }->{ 'name' };
	#$q->env( 'action_manager:type' => 'static_config' ) if $q->env( 'action_manager:name' );
	

# Session-store set here because it is dependent on the tmp directory, which
# must be set in a config file.
#  SET THIS AFTER LOADING OF CONFIG FILES, not here!
	$env{ 'component' }->{ 'session' }{ 'store' } = $env{ 'directory' }->{ 'tmp' } . 'sessions/';
	
# "Internal" env values, for the handler.
# Explicitly set here to prevent being set by config importation.
#	$env{ 'request_stage' }    = 'prestart';
	$env{ 'ok' }               = 1;
	$env{ 'started' }          = time();
	
	return $q;
}


# method OK  (public, object)
# purpose:
#	Accessor for overall request handling status.
#	The status can be set from true to false, but not from false to true.
#	Once processing begins, only process_request routine can set status.
#	All this is enforced in the main closure.
# usage:
#	Self.
#	Optional new status value.

sub ok
{
	return $_[ 0 ]->( 'ok' => $_[ 1 ] );
}


sub process_request ($;@)
{
	my( $q );
	
# LOAD/UNLOAD
	my( @load_order, $component );
# LOAD only
	my( $loaded );
# UNLOAD only
	my( $unloaded );
# ACTION, determine action manager/map
	my( $am_package, $am_origin, $am_route, $am_loaded, $using_internal_get_action );
# ACTION, execution
	my( $action_stage, $stage_ok );
	# also am_package, am_loaded, render_view, view_source
# RENDERING
	my( $render_view, $view_source, $view_exists, %renderer_params );
# RESPONSE
	my( $return_debug );
	
	$q = shift();
	
# If $q is not an object, instantiate.
# If it is, verify using request_stage that the handler hasn't been called yet.
	if ( ! ref $q )
	{
		$q = $q->new_request( @_ ) or die 'Could not instantiate controller!';
	}
	else
	{
		if ( $q->request_stage )
		{
			warn "Attempt to call a running process handler by @{[ ( caller( 1 ) )[ 3 ] ]}";
			return;
		}
		
		return unless $q->_allowed_caller( 'eq' => [ $q->app_package ] );
	}
	
# Set up reporting.
	unless ( $q->capturing )
	{
		$q->capture_output;
		$q->env( 'stderr_redirected_in_request_handler' => 1 );
	}
	
# Get request header.
	my $uri_temp = $q->env( 'sys_env:' . $q->env( 'uri_source_header' ) );
	$uri_temp = "/$uri_temp" unless $uri_temp =~ m|^/|;
	$q->env( 'uri:complete' => $uri_temp );
	
# REQUEST PROCESSING, start report.
	$q->report( "\n****  ***  **  *\nREQUEST PROCESSING FOR $q" );
	$q->report( "Calling package:         @{[ $q->app_package ]}" );
	$q->report( "Calling file:            @{[ $q->app_script ]}" );
	$q->report( "Request:                 @{[ $q->env( 'uri:complete' ) ]}" );
	$q->report( "Current status:          @{[ $q->ok ? 'ok' : 'FAIL' ]}\n" );
	
# Set request stage.
	$q->env( 'request_stage' => 'map' );
	
# II.a  Determine action manager
	$q->report( ":: getting action manager ::\n" );
	
	$using_internal_get_action = 0;
	
# A.
# The calling package submitted an action map or has an action map fetch routine.
	if ( $q->action_map || $q->app_package->can( 'get_action_map' ) )
	{
		#$q->report( 'Action map extant/caller provides loader, setting AM to main caller' );
		$am_package = $q->app_package;
		$am_origin = 'main caller';
		$am_route = '';
		$am_loaded = 1;
	}
# B.
# Caller does not provide action map, so it must come from an Action Manager.
	else
	{
# B.1
# Caller or config file supplied an Action Manager name.
		if ( $q->env( 'action_manager:name' ) )
		{
			#$q->report( 'Action manager name set directly by main caller or config file' );
			$am_package = $q->env( 'action_manager:name' );
			$am_origin = $q->env( 'action_manager:type' ) || 'set by main caller/config file';
			$am_loaded = $am_package eq $q->app_package ? 1 : 0;
		}
# B.2
# Caller did not provide an Action Manager name.
		else
		{
# B.2.i
# Self might BE an Action Manager if using a modified/overridden Controller.
			if ( $q->isa( 'Qoan::ActionManager' ) )
			{
# WARN  :: in regex, works correctly?
				#$q->report( 'Controller is also Action Manager, setting AM to inherited package' );
				no strict 'refs';
				my @ctlr_isa = @{ ref( $q ) . '::ISA' };
				#use strict 'refs';
				$am_package = ( grep { /^Qoan::ActionManager::/ } @ctlr_isa )[ 0 ];
				$am_origin = 'superclass/inherited';
				$am_loaded = 1;
			}
# B.2.ii
# Determine Action Manager based on request URI.
			else
			{
				my( %routes );
				
				%routes = $q->env( 'action_manager_routes' );
				
				$q->report( 'Checking action manager routes in config' );
				$q->report( 'count of available routes: ' . keys( %routes ) );
				
				for $am_route ( sort keys %routes )
				{
					$q->report( "comparing path: $am_route" );
					next unless $q->env( 'uri:complete' ) =~ m|$am_route|;
					$am_package = $routes{ $am_route };
					$am_origin = 'route selection';
					$am_loaded = 0;
					last;
				}
			}
			
# B.2.iii
# If action manager still not found, use default route.
# WARN  SHOULD WE EVEN ALLOW A DEFAULT ACTION MANAGER ROUTE?
			if ( ! $am_package && $q->env( 'default_route' ) )
			{
				$q->report( 'No matching action manager routes, using config default route' );
				$am_package = ( $q->_route_compare( $q->env( 'default_route' ), $q->env( 'uri:complete' ) ) )[ 0 ];
				$am_package = ucfirst( $am_package );
				$am_package =~ s|_(\w)|\U$1|g;
				$am_origin = 'default route in config' if $am_package;
				$am_loaded = 0;
			}
			
# B.2.iv
# If there is no action manager for a WRITE request, raise an error.
# If there is no action manager for a GET request, and auto get is available.
			if ( ! $am_package )
			{
				( $q->is_write_request || ! $q->env( 'allow_default_get_action' ) )
					? warn( "No action manager found for WRITE request or for GET with auto get unavailable\n" )
					: $q->report( "No action manager found for GET request, auto get available.\n" );
			}
		}
		
# B.2.v
# Load action manager package if necessary.
		if ( $am_package && $am_package ne 'main' && ! $am_loaded )
		{
			$am_package = 'Qoan::ActionManager::' . $am_package if $am_origin ne 'caller';
			$am_loaded = $q->_require( $am_package );
		}
	}
		
# B.2.vi
# At this point, any Action Manager should be loaded.
	if ( $am_loaded )
	{
		$q->env( 'action_manager:name' => $am_package );
		$q->env( 'action_manager:type' => $am_origin );
		$q->env( 'action_manager:route' => $am_route ) if $am_route;
		
		my( $get_map_sub, $sub_defined );
		{
			 no strict 'refs';
			 $get_map_sub = \&{ $am_package . '::get_action_map' };
			 $sub_defined = defined( &{ $am_package . '::get_action_map' } );
		}
		
		$q->action_map( $get_map_sub->() ) if $sub_defined;
	}
# B.2.vii
# If no Action Manager, and it's a GET request and default gets are allowed, set action
# map to default get.
	elsif ( ! $q->is_write_request && $q->env( 'allow_default_get_action' ) )
	{
		$q->action_map( 'default_action' => 'get',
				'default_view' => 'index',
				'get' => { 'route' => '/?\w+/:view' } );
		$using_internal_get_action = 1;
	}
	 
# Starting request status depends on whether an action manager was found.
	unless ( $q->action_map )
	{
	 	$q->ok( 0 );
		warn 'Failed to locate action map.';
	}
	
# Application alias.
	$q->env( 'application_alias' => ( $q->env( 'uri:complete' ) =~ m|^/?(\w+)| )[ 0 ] ) unless $q->env( 'application_alias' );
	
	$q->report( "application alias:       @{[ $q->env( 'application_alias' ) ]}" );
	$q->report( "action manager loaded?   @{[ $am_loaded ? 'yes' : 'NO' ]}" );
	$q->report( "action manager:          @{[ $am_loaded ? $am_package : 'none' ]}" );
	$q->report( "action manager alias:    @{[ $q->env( 'action_manager:alias' ) ]}" );
	$q->report( "action manager origin:   @{[ $am_loaded ? $am_origin : '' ]}" );
	$q->report( "action manager route:    @{[ $am_loaded ? $am_route : '' ]}" );
	$q->report( "action map exists?       @{[ $q->action_map ? 'yes' : 'no' ]}" );
	$q->report( "using default get map?   @{[ $using_internal_get_action ? 'yes' : 'no' ]}\n" );
	
	
# I. Load components
	#$q->env( 'request_stage' => _load_stage() );
	$q->env( 'request_stage' => 'load' );
	
	$q->report( ":: LOAD STAGE ::\n" );
	@load_order = $q->env( 'component_load_order' );
	$q->report( "Components to load: @load_order\n" );
	
	for $component ( @load_order )
	{
		next unless $q->ok;
		$q->report( "Loading component: $component" );
		$q->ok( $loaded = $q->_load_component( $component ) );
		$q->report( "Load $component returned: @{[ $loaded ? 'ok' : 'FAIL' ]} ($loaded)\n" );
	}
	
# Return if something goes wrong during context component load.
	unless ( $q->ok )
	{
		warn "Load failed; aborting request handling";
		return;
	}
	
	$q->report( ":: end load stage ::\n" );
	
	
# II. Execute action
	#$q->env( 'request_stage' => _action_stage() );
	$q->env( 'request_stage' => 'action' );
	
	$q->report( ":: ACTION STAGE ::\n" );
	
# II.b  Execute action
	#$q->report( ":: executing action ::\n" );
	
# Set component-accessible controller routines from env.
	$q->publish( $q->_flatten( $q->env( 'publish' ) ) );
	
# START Action Manager component access block
	{
# Setup of component data in Action Manager.
# Note, lexically scoped to block just started.
# Note, this is done if the Action Manager is loaded, which means NOT for the internal
# default get action map.
# WARN  The following use $q, and might have problems in a mod_perl environment,
#	but the idea is that the wrapping "local" will cause the lexical reference to 
#	evaporate once the block is exited.
	 no strict 'refs';
	 no warnings 'redefine';
# Controller access alias for Action Manager.
	 local *{ $am_package . '::qoan' } = sub {
		local *__ANON__ = 'controller_access_closure_actionmanager';
		shift() if ref( $_[ 0 ] );
		return $q->_method( @_ ); } if $am_loaded;
# Controller access alias for components.
#	 my(  );
#	 local *{ $_ . '::qoan' } = sub {
#		local *__ANON__ = "controller_access_closure_$_";
#		shift() if ref( $_[ 0 ] );
#		return $q->_method( @_ ); } for @controller_access;
	 
	 use warnings 'redefine';
	 use strict 'refs';
	 
# Test of exported $am_package variables, must return values.
# NOTE  these tests are no good now, rewrite if using again.
	# if ( $am_loaded )
	# {
	#	&::controller_report( 'This is calling the controller functional ENV via MAIN.' );
	#	&::controller_report( " [from main] :: $_: $::request{ $_ }" ) for sort keys %::request;
	# }
	 
	 $stage_ok = $q->ok;
	 
# The action at last!
	 for $action_stage ( $q->env( 'action_stages' ) )
	 {
		$q->report( "Opening action stage: \U$action_stage\E  with status: $stage_ok @{[ $stage_ok ? '' : '(skipping)' ]}" );
		next unless $stage_ok;
		
		$action_stage = "_action_$action_stage";
		
# Runs Action Manager stage handler if extant.
# (There might be no Action Manager if it is a GET request and default get action maps are allowed.)
		if ( $am_loaded && $am_package->can( $action_stage ) )
		{
			my $sub_ref;
			{
			 no strict 'refs';
			 $sub_ref = \&{ $am_package . '::' . $action_stage };
			}
			
			$stage_ok = $sub_ref->();
		}
		else
		{
			$stage_ok = $q->$action_stage;
		}
		
		$q->env( "action:$action_stage:ok" => $stage_ok );
		$q->ok( $stage_ok );
		$q->report( qq|stage returned: @{[ $stage_ok ? 'ok' : 'FAIL' ]} ($stage_ok)\n| );
	 }
	 
# Action handling CHECK or EXECUTE might have set the view to render.
	 if ( $render_view = $q->env( 'render_view' ) )
	 {
	 	$view_source = 'action handling';
	 }
	 
# If the action handling check and execute stages did not supply a view to render,
# run an Action Manager selection routine, if available.
	 if ( ! $render_view && $am_loaded && $am_package->can( 'select_view_to_render' ) )
	 {
		$render_view = $am_package->select_view_to_render;
		$view_source = 'action manager select routine' if $render_view;
	 }
	 
	 $q->report( "\n:: end action stage ::\n" );
	}
# END Action Manager component access block
	
# Test of exported $am_package variables after scope-end (must return NO VALUES).
	#$q->report( 'Request in am?' );
	#$q->report( " :: $_: $main::request{ $_ }" ) for sort keys %main::request;
	
	
# III. Render View
	#$q->env( 'request_stage' => _render_stage() );
	$q->env( 'request_stage' => 'render' );
	
	$q->report( ":: RENDER RESPONSE STAGE ::\n" );
	
	$q->report( ":: selecting view ::\n" );
	
# Special case for internal get??
# Ideally, the following if-block (as is) should handle this.
	#if ( ! $render_view && $using_internal_get_action )
	#{
	#	;
	#}
	
# Action name or last segment of URI if using internal get action.
	if ( ! $render_view && $q->env( 'action:route' ) )
	{
		my( @segments );
		@segments = map { $q->env( "uri$_" ) } ( $q->env( 'action:route' ) =~ m|/(:\w+)|g );
		
		$render_view = join( ':', @segments );
		$view_source = 'URI extraction' if $render_view;
	}
	
# Action Map/Manager default.
# Note the source says "action manager" but this is because an AM can only have
# on action map.
	unless ( $render_view )
	{
		$render_view = $q->action_map( 'default_view' );
		$view_source = 'action manager default' if $render_view;
	}
	
# Application default.
	unless ( $render_view )
	{
		$render_view = $q->env( 'default_view' );
		$view_source = 'application default' if $render_view;
	}
	
	$q->env( 'render_view' => $render_view ) unless $q->env( 'render_view' );
	$q->env( 'view_source' => $view_source );
	
# View sources.
	unless ( $q->env( 'view_sources' ) )
	{
		my( @view_store, $i );
		
# Note that the following line works regardless of whether view:store
# is a scalar or an array.
		@view_store = $q->env( 'server:view:store' ) || $q->env( 'component:view:store' );
		
		for ( $i = $#view_store; $i >= 0; $i-- )
		{
			$view_store[ $i ] = $q->app_dir . $view_store[ $i ] unless $view_store[ $i ] =~ m|^/|;
			
			unless ( -d $view_store[ $i ] && -r $view_store[ $i ] )
			{
				warn( "View source is not a directory or not readable: $view_store[ $i ]" );
				splice( @view_store, $i, 1 );  # removes path
			}
		}
		
		push( @view_store, $q->qoan_base_dir . $q->env( 'qoan_view_store' ) ) unless $q->env( 'local_views_only' );
		
		$q->env( 'view_store' => [ @view_store ] );
	}
	
# Check that starting view exists.  This is to retain control over HTTP requests
# for resources that don't exist.
	for ( $q->env( 'view_store' ) )
	{
		my $exists;
		( $exists = $render_view ) =~ s|:|/|g;
		$view_exists = 1 if glob( "$_$exists.*" );
		last if $view_exists;
	}
	
	
# Report on view found to be rendered.
	$q->report( "starting view:           @{[ $render_view || 'none' ]}" );
	$q->report( "view source:             @{[ $view_source || '' ]}" );
	$q->report( "starting view exists?    @{[ $view_exists ? 'yes' : 'no' ]}" );
	$q->report( "action map default view: @{[ $q->action_map( 'default_view' ) ]}\n" );
	$q->report( qq|view repositories:\n@{[ join( "\n", $q->env( 'view_store' ) ) ]}\n| );
	
	
# View rendering.
	$q->report( ":: rendering view ::\n" );
	
	unless ( $view_exists )
	{
		$q->report( q|Rendering action map's default view in place of non-existent starting view.| );
		$render_view = $q->action_map( 'default_view' );
	}
	
	%renderer_params = $q->env( 'renderer_parameters' );
	$renderer_params{ 'view_start' } = $render_view;
	$renderer_params{ 'sources' } = [ $q->env( 'view_store' ) ];
	
# Block to localize controller access alias for view component.
# WARM  commented out because otherwise it disallows controller access during debug
#	report rendering (see c. line 527).
	#{
	 no strict 'refs';
	 local *{ 'Qoan::View' . '::qoan' } = sub {
		local *__ANON__ = 'controller_access_closure_view';
		shift() if ref( $_[ 0 ] );
		return $q->_method( @_ ); };
	 use strict 'refs';
	 
	#my $rendered = $q->view_render( %renderer_params );
	#$rendered = Encode::encode( 'utf8', $rendered );
	#Encode::_utf8_on( $rendered );
	#$q->response( 'body' => $rendered );
	 $q->response( 'body' => $q->view_render( %renderer_params ) );
	#}
	
	warn( 'Response is empty' ) unless $q->response( 'body' );
	
	$q->report( "\n:: end render stage ::\n" );
	
	
# IV. Unload
	#$q->env( 'request_stage'=> _unload_stage() );
	$q->env( 'request_stage' => 'unload' );
	
	$q->report( ":: UNLOAD STAGE ::\n" );
	
	@load_order = $q->env( 'component_unload_order' ) || reverse @load_order;
	
	for $component ( @load_order )
	{
		#next unless $q->ok;  # ??? should always unload ?
		$q->report( "Unloading component: $component" );
		#$q->ok( $unloaded = $q->_unload_component( $component ) );
		$unloaded = $q->_unload_component( $component );
		$q->report( "Unload $component returned: @{[ $unloaded ? 'ok' : 'FAIL' ]} ($unloaded)\n" );
	}
	
	$q->report( ":: end unload stage ::\n" );
	
	
# V. SENDING RESPONSE
	#$q->env( 'request_stage'=> _respond_stage() );
	$q->env( 'request_stage' => 'response' );

# Set response to debug report if:
#  - config is set to allow it, AND
#  - session is set to allow it OR permissive setting in config is ON, AND
#  - there is NO rendered response OR a debug request parameter is set.
# NOTE that this is (Dec 2011) the ONLY place where the controller refers to context
# component values AT ALL, when deciding to send the debug report to the client.
#  values: session:admin_debug_http, request:debug = http
# Note, as components are unloaded, calls are made to env component member stores.
	if ( $q->env( 'http_debug:allow' ) )
	{
		my( $debug_param, $debug_value );
		
		$debug_param = 'request:' . $q->env( 'http_debug:request_param' );
		$debug_value = $q->env( 'http_debug:request_value' );
		
		$q->report( 'Checking whether to send debug report to client..' );
		$return_debug = 0;
		$return_debug = 1 if $q->env( 'session:permission:http_debug' );
		$return_debug = 1 if $q->env( 'http_debug:allow_public' );
		#$return_debug &&= ( $q->env( $debug_param ) eq $debug_value ) if $q->env( $debug_param );
		$return_debug &&= ( ! $q->response( 'body' ) || ( ( $q->env( $debug_param ) || "\0" ) eq $debug_value ) );
		
		if ( $return_debug )
		{
			$q->report( 'Returning debug report to client.' );
			
			%renderer_params = $q->env( 'renderer_parameters' );
			$renderer_params{ 'view_start' } = $q->env( 'http_debug:view' );
			$renderer_params{ 'sources' } = [ $q->env( 'view_store' ) ];
			$renderer_params{ 'run_report' } = $q->captured_output;
			$renderer_params{ 'errors' } = [ $q->captured_errors ];
			
			$q->response( 'body' => $q->view_render( %renderer_params ) );
		}
	}
	
# Send response, unless caller has indicated it will do it.
	unless ( $q->env( 'delay_response' ) )
	{
		$q->env( 'response_sent' => $q->send_response );
	}
	
# VI. COMPLETED  Flag request as handled.
	#$q->env( 'request_stage' => _finished() );
	$q->env( 'request_stage' => 'finished' );
	
# Reset logging environment to normal if logging was redirected in this subroutine.
	$q->capture_output if $q->env( 'stderr_redirected_in_request_handler' );
	
# Admin alerts for requests handled with errors.
# Does not send alert if debug report was returned to client.
	if ( $q->captured_errors && $q->env( 'alert_on_error' ) && ! $return_debug )
	{
		if ( $q->env( 'alert_on_error:errorlog' ) )
		{
			$q->flush_captured;
		}
		
		if ( $q->env( 'alert_on_error:email' ) )
		{
			my( $sent, %email_parts );
			
			$email_parts{ 'body' } = $q->captured_output;
			$email_parts{ 'from' } = $q->env( 'alert_on_error:email:from' );
			$email_parts{ 'to' } = $q->env( 'alert_on_error:email:to' );
			$email_parts{ 'subject' } = $q->env( 'alert_on_error:email:subject' );
			
			$q->load_helper( 'Qoan::Helper::' . $q->env( 'alert_on_error:email:helper' ) );
			$sent = $q->_send_email( %email_parts );
			
			warn( "Error alert email failed to send." ) unless $sent;
		}
	}
	
	return $q->ok;
}


# method PUBLISH
#	modeled on ENV

sub publish
{
	my( $q, $editable, $reading, %writing, $caller, %components, $component, %to_env );
	
	$q = shift();
	
	$editable = 0;
	$reading = '';
	
# If no parameters, return the entire publish list, flattened.
	return $q->_flatten( $q->( ) ) unless @_;
	
# Return the requested value if only a single parameter (key value).
	$reading = shift() if @_ == 1;
	return $q->( $reading ) if $reading;
	
# Writing to publish list.
# Only the app package, the request processing routine, or a Qoan interface module
# can write to the publish list.
	return unless $q->_allowed_caller(
		'eq' => [ 'Qoan::Controller::process_request', $q->app_package ],
		'=~' => [ '^Qoan::Interface::' ] );
	
	%writing = @_;
	$caller = ( caller( 1 ) )[ 3 ];
	
# Once set, publish list values can be changed:
#	by the request processing routine;
#	by the application package before processing starts.
	$editable = 1 if $caller eq 'Qoan::Controller::process_request';
	$editable = 1 if ! $q->request_stage &&
		$q->_allowed_caller( 'eq' => [ $q->app_package ], 'suppress_alerts' => 1 );
	
# Use actual name of published routine if no alias provided for component.
# e.g. component => controller_method becomes: component:controller_method => controller_method;
# caller otherwise should pass component:method_alias => controller_method, if needed.
	for ( keys %writing )
	{
		unless ( $_ =~ m|:| )
		{
			$writing{ "$_:$writing{ $_ }" } = $writing{ $_ };
			delete $writing{ $_ };
		}
	}
	#$q->report( 'publish writing: ', %writing );
	
# Remove keys with defined values if publish list is not editable.
	if ( ! $editable )
	{
		for ( keys %writing )
		{
			delete $writing{ $_ } if defined $q->( $_ );
# Note, following is used when main closure returns '' (instead of nothing)
# on request for non-existent member.
			#delete $writing{ $_ } if $q->( $_ );
		}
	}
	
# Qoan Interfaces can only publish their own aliases, remove any invalid.
	if ( $caller =~ m|^Qoan::Interface::| )
	{
		%components = $q->component;
		$component = '';
		
# Get component name.
		for ( keys %components )
		{
			$component = $_ if $caller =~ m|^$components{ $_ }{ 'interface' }|;
			last if $component;
		}
		
# Remove any alias without the component name in it.
# If by some chance the calling interface is not being used by any component,
# every member of %writing should raise an error.
		for ( keys %writing )
		{
			next if $_ =~ m|$component|;
			warn qq|Attempt to publish non-interface alias "$writing{ $_ }" as "$_" by $caller|;
			delete $writing{ $_ };
		}
	}
	
# Remove any keys to non-existant controller routines.
	for ( keys %writing )
	{
		next if $q->can( $writing{ $_ } );
		warn qq|Attempt to publish non-existant controller routine "$writing{ $_ }" as "$_" by $caller|;
		delete $writing{ $_ };
	}
	
# Store values in functional env, for reference.
# NOTE  should this be stored with component settings ??
	$to_env{ "publish:$_" } = $writing{ $_ } for keys %writing;
	$q->env( %to_env );
	
	return $q->( %writing );
}


sub qoan_base_config
{
	return $qoan_base_config;
}


sub qoan_base_dir
{
	return $qoan_base_dir;
}


sub qoan_base_file
{
	return $qoan_base_file;
}


# RESPONSE only allows the response body and status to be set by the process request
# handler.  Any caller can set headers.
sub response ($;@)
{
	my( $q, $writing, $reading, $called_by_req_handler, %to_write, %headers, $header );
	
	$q = shift();
	$writing = ( @_ > 1 );
	$reading = ( @_ == 1 );
	
	if ( $writing )
	{
		%to_write = @_;
		
		$called_by_req_handler = $q->_allowed_caller(
			'eq' => [ 'Qoan::Controller::process_request' ], 'suppress_alerts' => 1 );
		
# Only main request handler may set the response body and status.
		unless ( $called_by_req_handler  )
		{
			delete $to_write{ 'body' };
			delete $to_write{ 'status' };
		}
		
# Correct "header:" key to "headers:" if necessary.
		for ( grep { /^header:/ } keys %to_write )
		{
			( $header = $_ ) =~ s|^header|headers|;
			$to_write{ $header } = delete $to_write{ $_ };
		}
		
# Also insert headers into functional env (for convenient reference w/ other env values).
		$headers{ $_ } = $to_write{ $_ } for grep { /^headers/ } keys %to_write;
		$q->env( %headers ) if %headers;
		
		return $q->( %to_write );
	}
	
# Return requested member or entire response if caller submitted no parameter.
	return $q->( $_[ 0 ] ) if $reading;
	return $q->( );
}


sub request_stage
{
	my( $q, $check, $stage, @stages, $current );
	
	$q = shift();
	$check = shift();
	$stage = shift();
	
	$current = $q->env( 'request_stage' ) || '';
	return $current unless defined $check;
	
	if ( $check eq 'current' )
	{
		return 1 if $current eq $stage;
		return 0;
	}
	
	@stages = $q->env( 'request_stages' );
	
	if ( $check eq 'before' )
	{
		for ( @stages )
		{
			return 1 if $current eq $_;
			return 0 if $stage eq $_;
		}
	}
	
	if ( $check eq 'after' )
	{
		for ( reverse @stages )
		{
			return 1 if $current eq $_;
			return 0 if $stage eq $_;
		}
	}
	
	return 0;
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
	
	unless ( $module && $self )
	{
		$msg = 'Module to load missing or package self-identification missing.';
		#$self->can( 'warn' ) ? $self->warn( $msg ) : warn( $msg );
		warn $msg;
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
		#$self->can( 'warn' ) ? $self->warn( $msg ) : warn( $msg );
		warn $msg;
		return 0;
	}
	
	local $@;
	$ok = eval "require $module; 1;";
	
	if ( ! $ok )
	{
		$msg = "Error on @{[ ref $self ]} module $module require: $@";
		#$self->can( 'warn' ) ? $self->warn( $msg ) : warn( $msg );
		warn $msg;
		return 0;
	}
	
	return 1 if $ok;
}


sub _route_compare ($$)
{
	my( $q, $route, $path, @route, $route_converted, @compared );
	
	$q = shift();
	$route = shift();
	$path = shift();
	
	#$q->report( "Comparing path $path to route $route .." );
	
	$route =~ s|^/||;
	@route = split( '/', $route );
	
	for ( @route )
	{
		$_ =~ s|^(?::\w+){1,}(\??)$|/$1(\\w+)$1|;
		$_ = "/$_" unless $_ =~ m|^/|;
	}
	
	$route_converted = join( '', @route );
	
	#$q->report( "Route converted to $route_converted .." ) if $route ne $route_converted;
	
	@compared = ( $path =~ m|^$route_converted$| );
	
	return @compared;
}


sub send_response
{
	my( $q, %response, %headers, @headers, $header_name );
	
	$q = shift();
	
	return unless $q->_allowed_caller(
		'eq' => [ 'Qoan::Controller::process_request', $q->app_package ] );
	
	unless ( $q->env( 'response_sent' ) )
	{
		%response = $q->response;
		%headers = $response{ 'headers' } if $response{ 'headers' };
		
		$response{ 'status' } ||= "HTTP/1.0 200 OK";
		$response{ 'status' } = '' unless $q->env( 'send_response_status' );
		
# Get content-type header first or use default if not set.
		push( @headers, 'Content-type: ' .
			( delete $response{ 'headers' }->{ 'content-type' } || 'text/html' ) ); 
		
# Assemble any other submitted headers.
		for ( keys %{ $response{ 'headers' } } )
		{
			( $header_name = $_ ) =~ s|^headers:||;
			push( @headers, "@{[ ucfirst $header_name ]}: @{[ $response{ 'headers' }->{ $_ } ]}" );
		}
		#$q->report( 'headers;', @headers );
		
# Send response.
		#return 1 if print STDOUT "Content-type: text/html\n\n", $q->response( 'body' );
		return 1 if print STDOUT $response{ 'status' },
			join( "\n", @headers ), "\n\n",
			$response{ 'body' };
	}
	
	return 0;
}


sub _unload_component ($$)
{
	my( $self, $component, %component, $cleanup, $accessor, $object );
	
	$self = shift();
	$component = lc( shift() );
	
	return unless $self->_allowed_caller( 'eq' => [ 'Qoan::Controller::process_request' ] );
	
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
