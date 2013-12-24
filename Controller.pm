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
	
# A Qoan application script will be at caller( 2 ).
# If the app script is using a subclass of Qoan::Controller, that file name
# will be at caller( 2 ), and the app script will be at caller( 3 ).
	( $app_pkg, $app_script ) = ( caller( 2 ) )[ 0, 1 ];
	( $app_pkg, $app_script ) = ( caller( 3 ) )[ 0, 1 ] if $app_script =~ m|\.pm$|;
	$app_config = $app_dir = $app_script;
	$app_dir =~ s|[^/]+$||;
	#print STDERR "callerstuff: $app_pkg, $app_script, $app_dir, $app_config\n";
	
# Adds calling app's home directory and Qoan Local dirs for both main Qoan install
# and calling app's sibling Qoan respository.
	unshift( @INC, $app_dir, $app_dir . 'Qoan/Local', $qoan_base_dir . 'Local' );
	
# Default names for these two files.  These might be altered in import().
	#$qoan_base_config = 'qoan.default.config';
	$qoan_base_config = 'qoan.default.yml';
	$app_config =~ s|\.\w+$|.yml|;
	
	
# BASE HANDLER SET-UP
# The base handler is not intended for use during request handling, but rather only for
# access to the base environment prior to request handling.  Basically, it provides an
# interface to the base env that is consistent with that provided during request handling.
# This allows the same routines to call env inside and outside a request context.
	$handler_base = sub {
		local *__ANON__ = 'base_closure';
		my( $store, $k, $v, @keypath, $index, $loc, $i );
		
# Only env may access the base closure.
		return unless __PACKAGE__->_allowed_caller( 'eq' => [ 'Qoan::Controller::env', 'Qoan::Controller::publish' ] );
		
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
		'action_stages'        => [ qw| check  execute  cleanup | ],
		'request_stages'       => [ qw| route  load  action  render  unload  response  cleanup | ],
		'component_load_order' => [ qw| request  session  user | ],
# NOTE  that the config tool ALWAYS loads first, so does not appear in server_load_order.
		'server_load_order'    => [ qw| logger  view | ],
		'qoan_view_store'      => 'views/shared/',
		'uri_source_header'    => 'request_uri',
		'sessionid_variable'   => 'qoan_session',
		'userid_variable'      => 'qoan_user',
		'default_get_action_map' => {
		    'default_action' => 'get',
		    'default_view'   => 'index',
		    'get'            => { 'route' => '/:view' }
		},
		'qoan_started'         => time(),
		'closure_accessors'    => [ map { __PACKAGE__ . "::$_" } qw| action_map  clipboard  component  env  ok  publish  response | ],
		'publish'              => { 
			'action_manager' => {
				'clipboard' => 'clipboard',
				'env' => 'env',
				'response' => 'response',
				'set_view' => 'set_view',
			},
			'view'           => {
				'clipboard' => 'clipboard',
				'env' => 'env'
			},
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
				'module' => 'Qoan::View',
				'interface' => 'Qoan::Interface::IView_QoanView',
				'store' => 'views/'
			},
			'config'  => {  #'module' => 'Qoan::Config'
				'module' => 'YAML::Tiny',
				'interface' => 'Qoan::Interface::IConfig_YAMLTiny',
			},
			'logger'  => { 'module' => 'Qoan::Logger' },
			#'request_manager' => { 'module' => 'Qoan::RequestManager' },
		},
	);
}


# Purpose: Just being present and accounted for.
#
sub DESTROY
{
	;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
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


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub _action_cleanup
{
	my( $q );
	$q = shift();
	
	
	return 1;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub _action_execute
{
	my( $q, $manager, $action, $has_handler, $handler, $exec_ok );
	
	$q = shift();
	$exec_ok = 0;
	
	$manager = $q->env( 'action_manager:name' ) || '';
	$action = $q->env( 'action:name' ) || '';
	
# Check for action but do not raise an error if none.
	unless ( $action )
	{
		$q->report( 'No action specified.' );
		return 1;
	}
	
# Verify action exists in map.
	unless ( $q->action_map( $action ) )
	{
		warn( 'Action to execute missing from map!' ) unless $q->action_map( $action );
		return 0;
	}
	
# Get handler.
	$handler = ( $q->action_map( "$action:handler" ) || $action ) if $action;
	
# Change handler value to code ref if it is a string.
	#$q->report( 'setting code ref: ' .$manager . '::' . $handler );
	if ( $manager && $handler && ref( $handler ) ne 'CODE' )
	{
		no strict 'refs';
		$handler = \&{ "$manager\::$handler" } if defined( &{ "$manager\::$handler" } );
	}
	
	if ( ref( $handler ) ne 'CODE' )
	{
# If no handler but the request is a GET, skip execution with success.
		if ( ! $q->is_post_request )
		{
			$q->report( 'Not a write request; skipping stage with success.' );
			return 1;
		}
		
# If no handler and the request is a POST, Fail execution.
		if ( $q->is_post_request )
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
# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub _action_identify
{
	my( $q, %map, @order, $i, $req_uri );
	my( $action, $route, @routes, @compared, $identified );
	my( @symbols );
	
	$q = shift();
	$i = 0;
	$identified = '';
	
	if ( %map = $q->action_map )
	{
# Check URI against action map routes.
# Note that if there is no "order" member in the checks, a meaningless order is substituted
# (prevents warning).  Not sure at this time (Feb 2012) if that's the right solution.
		@order = sort { ( $map{ $a }{ 'order' } || ++$i ) <=> ( $map{ $b }{ 'order' } || ++$i ) }
			grep { ref( $map{ $_ } ) eq 'HASH' } keys %map;
		$req_uri = $q->env( 'uri:virtual' );
		$q->report( "Identifying action, request URI: $req_uri" );
		
		for $action ( @order )
		{
# NEXT THING HERE: @ROUTES ??
			$route = $map{ $action }{ 'route' };  # just to make next line readable
			$q->report( qq|Action:  \U$action| );
			
			for ( ref( $route ) eq 'ARRAY' ? @{ $route } : $route )
			{
				$q->report( " route:  $_" );
				
				if ( @compared = $q->_route_compare( $_, $req_uri ) )
				{
					$identified = $action;
					$route = $_;
				}
				
				last if $identified;
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
	$q->report( ' ' );  # line break
	$q->report( "action route match: @{[ $route || '' ]}" ) if $identified;
	$q->report( "action identified:  @{[ $identified || 'none' ]}" );
	
	return 1 if $identified;
	return 0;
}


# method ACTION_MAP

# Name:     x
# Purpose:  x
# Usage:    x
# Security: x
# Context:  For Request context only (does not use $handler_base).
#
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
#	by the request route stage handler;
#	by the application package before processing starts.
	if ( $q->request_stage )
	{
		#$can_edit = 1 if $caller eq 'Qoan::Controller::process_request';
		#$can_edit = 1 if $q->_allowed_caller( 'eq' => [ map { $_ . '::_process_request_stage_route' } $q->env( 'protected' ) ] );
		for ( 'Qoan::Controller::process_request', map { $_ . '::_process_request_stage_route' } $q->env( 'protected' ) )
		{
			#$can_edit = 1 if $caller eq $_;
			if ( $caller eq $_ ) { $can_edit = 1; last; }
		}
	}
	else
	{
		$can_edit = 1 if $q->_allowed_caller( 'eq' => [ $q->app_package ], 'suppress_alerts' => 1 );
	}
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

# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
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


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub app_config
{
	return $app_config;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub app_dir
{
	return $app_dir;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub app_script
{
	return $app_script;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub app_package
{
	return $app_pkg;
}


#sub client_resource
#{
#	my( $q, $store, $type, $name, $view );
#	
#	$q = shift();
#	
#	$store = $q->env( 'client_resource_action:store' );
#	$type  = $q->env( 'uri:resource_type' );
#	$name  = $q->env( 'uri:resource_name' ) || $q->env( 'uri:alias:private' );
#	
#	$view = "$store/$name.$type";
#	$q->env( 'render_view' => $view );
#	
#	return 1 if $q->env( 'render_view' ) eq $view;
#	return 0;
#}


# Purpose:  For storage/retrieval of globs of data which do not belong anywhere else
# Context:  Public.  Published to AM/view by default.
# Receives: x
# Returns:  x
# External: x
#
sub clipboard
{
	my( $q );
	
	$q = shift();
# Clipboard not allowed for class method call style (no use of base object).
	#return if $q eq __PACKAGE__;
	return unless ref( $q );
	return unless @_;
	
	$q->report( qq|Writing data to clipboard under name "$_[ 0 ]".| ) if @_ > 1;
	$q->report( qq|Reading data from clipboard under name "$_[ 0 ]".| ) if @_ == 1;
	
# External a)
	return $q->( @_ );
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

# NOTE on sub component:
#  only writes to *specific* sections of env; changes received key.

# Purpose:  provides access to component objects (calls closure directly),
#           or stored component settings or data (calls sub env).
# Context:  Should only be called by Interfaces accessors.
#           Non-accessor callers highly restricted.  Disallow completely?
# Receives: 1) controller ref or class name
#           .) 
# Returns:  x
# External: x
#
sub component
{
	my( $q, @params, $i );
	my( $writing, $reading, $caller );
	#my( %component_list, $name, $settings );
	my( %component_list, $component_name, $component_pkg );
	my( $load_obj, $unload_obj, $get_obj, $data_call, $settings_call );
	
	$q = shift();
	#$q = $handler_base if $q eq __PACKAGE__;
	$q = $handler_base unless ref( $q );
	
# Note, $writing and $reading are used with settings and data only.
	@params = @_;
	$writing = ( @params > 1 );
	$reading = ( @params == 1 );
	
	$params[ 0 ] ||= '';
		
	$caller = ( caller( 1 ) )[ 3 ];
	
# External a)
	return $q->env( "component:$params[ 0 ]" ) unless $caller =~ m|::accessor$|;
	
# External b)
	%component_list = $q->env( 'component' );
	
#	while ( ( $name, $settings ) = each %component_list )
#	#while ( ( $name, $settings ) = each %{ $q->env( 'component' ) } )
#	{
#		last if $caller =~ m|^${ $settings }{ 'interface' }|;
#	}
	for ( keys %component_list )
	{
		next unless $caller =~ m|^${ $component_list{ $_ } }{ 'interface' }|;
		#$name = $_;
		#$settings = $component_list{ $_ };
		$component_name = $_;
		$component_pkg = $component_list{ $_ }->{ 'module' };
		last;
	}
	
	return unless $component_name && $component_pkg;
	
# Component can interact with the component objects, the stored component settings,
# or data loaded from the component to the functional env.
# For the latter two, component changes the parameter to refer to the appropriate
# section of %env, which allows access to specific values in those sections.
	
	$load_obj = $unload_obj = $get_obj = $data_call = $settings_call = 0;
	
# Note that unloading can only happen during the unload stage; but loading
# is not restricted to a stage, because we might need to create a component
# during the request.
# External c)
	#$load_obj = 1 if ref( $params[ 0 ] ) eq $settings->{ 'module' } &&
	$load_obj = 1 if ref( $params[ 0 ] ) eq $component_pkg &&
		! defined( $q->( $component_name ) );
# Note, following is for when main closure returns '' (instead of nothing)
# on request for non-existent member.
		#! $q->( $component_name );
# External d)
	$unload_obj = 1 if $params[ 0 ] eq 'remove' &&
		$q->request_stage( 'current' => 'unload' );
	$get_obj = 1 if ! $params[ 0 ];
	
# Component object related.
	if ( $load_obj || $unload_obj || $get_obj )
	{
# External e), f)
		return $get_obj
			? $q->( $component_name )
			: $q->( $component_name => $params[ 0 ] );
	}
	
# Step through key parameters and evaluate whether they are for
# Data or Settings.
	for ( $i = 0; $i < @params; $i += 2 )
	{
		$data_call = 1 if $params[ $i ] =~ m|^data\b|i;
		$settings_call = 1 if $params[ $i ] =~ m|^settings\b|i;
	}
	
# It can't be both!
	if ( $data_call && $settings_call )
	{
		warn 'Component accessor received mixed data and settings call: ' .
			join( ', ', @params );
		return 0;
	}
	
# If caller has not specified Data or Settings, apply instantiation rule.
	unless ( $data_call || $settings_call )
	{
# External g)
		$data_call = 1 if defined( $q->( $component_name ) );
		$settings_call = 1 if ! defined( $q->( $component_name ) );
		
		for ( $i = 0; $i < @params; $i += 2 )
		{
			$params[ $i ] = "data:$params[ $i ]" if $data_call;
			$params[ $i ] = "settings:$params[ $i ]" if $settings_call;
		}
	}
	
	if ( $reading )
	{
		$params[ 0 ] =~ s|^data|$component_name|i if $data_call;
		$params[ 0 ] =~ s|^settings|component:$component_name|i if $settings_call;
		
# External h)
		return $q->env( $params[ 0 ] );
	}
	elsif ( $writing )
	{
		for ( $i = 0; $i < @params; $i += 2 )
		{
			$params[ $i ] =~ s|^data|$component_name|i if $data_call;
			$params[ $i ] =~ s|^settings|component:$component_name|i if $settings_call;
		}
		
# External h)
		return $q->env( @params );
	}
	
# External i)
	warn "Component routine unable to fulfill request from $caller";
}


# Purpose:  read and write the env for base/request-context closures
# Context:  Public.  Published to AM/view by default.
#           Restricts writing based on caller.
# Receives: 1) controller ref or class name
#           .) 0+ params; reading if 0 or 1; writing if >1
#              if 1st param is an array, it's a list of config files to load.
# Returns:  1) entire env if no params received
#           2) implicit undef if writing (2+ params) but env is "not editable"
#           3) literal 1 if loading from a config value set
#           4) requested value if reading
#           5) result of main closure call if writing (last value written)
# External: a) calls main closure with no params (gets entire env)
#           b) flattens env (no nested structure, no refs)
#           c) calls main closure with single param (reading)
#           ?) 
#           d) calls config_retrieve routine
#           e) calls to main closure to check for existing values
#           f) calls main closure with multiple params (writing)
#
sub env
{
	my( $q, $editable, $reading, $cfg_load, $caller, %writing );
	
	$q = shift();
# Class method call style means use handler base object.
	#$q = $handler_base if $q eq __PACKAGE__;
	$q = $handler_base unless ref( $q );
	
	$editable = 0;
	$reading = '';
	$cfg_load = '';
		
	$caller = ( caller( 1 ) )[ 3 ] || '';
	
# If no parameters, return the entire functional env, flattened.
# External a), b)
	return $q->_flatten( $q->( ) ) unless @_;
	
	$cfg_load = shift() if ref( $_[ 0 ] ) eq 'ARRAY';
	$reading = shift() if @_ == 1;
	%writing = @_;
	
# Only a single key parameter submitted, return the value.
# External c)
	return $q->( $reading ) if $reading;
	
# Values in env can be changed:
#  - before request processing starts
#  - by the processing routine, at any time
#  - for component data areas in env if the caller is sub component and the
#    component in question is flagged as rewritable.
# NOTE  can't call request_stage() here, because that relies on env().
	$editable = 1 if ! defined $q->( 'request_stage' );
	$editable = 1 if $caller eq 'Qoan::Controller::process_request';
#	if ( $caller eq 'Qoan::Controller::component' )
#	{
#		my( $component ) = ( ( keys %writing )[ 0 ] =~ m|^(\w+):| )[ 0 ];
# External ?)
#		$editable = 1 if $q->( "component:$component:rewritable" ) eq '1';
#	}
	
# Caller can pass a list of config file names and hash refs containing env key-value
# pairs in an array ref.  It must be the first parameter.
# This kind of mass-update is only allowed if env is "editable" (even if all the values are new).
	if ( $cfg_load )
	{
		return unless $editable;
		
		for ( @{ $cfg_load } )
		{
# External d)
			#$q->( __PACKAGE__->config_retrieve( $_ ) ) if ! ref $_;
			$q->( $q->config_retrieve( $_ ) ) if ! ref $_;
			$q->( %{ $_ } ) if ref( $_ ) eq 'HASH';
		}
		
		return 1;  # ??? return value after config load??
	}
	
# Remove keys with defined values if env is not editable.
	if ( ! $editable )
	{
		for ( keys %writing )
		{
# External e)
			delete $writing{ $_ } if defined $q->( $_ );
# Note, following is used when main closure returns '' (instead of nothing)
# on request for non-existent member.
			#delete $writing{ $_ } if $q->( $_ );
		}
	}
	
# External f)
	return $q->( %writing );
}


# Purpose:  send error message
# Context:  Private but not enforced
# Receives: 1) controller ref
# Returns:  implicit undef (void routine)
# External: a) fetches 'alert_on_error:errorlog' from env
#           b) flushes captured output to error log
#           c) fetches 'alert_on_error:email' from env
#           d) fetches captured output
#           e) sends email
#           f) calls warn
#
sub _error_alert
{
	my( $q, %aoe_email );
	
	$q = shift();
	#$q = $handler_base if $q eq __PACKAGE__;
	$q = $handler_base unless ref( $q );
	
# External a)
	if ( $q->env( 'alert_on_error:errorlog' ) )
	{
# External b)
		$q->flush_captured;
	}
	
# External c)
	return unless %aoe_email = $q->env( 'alert_on_error:email' );
	
	my( $sent, %email_parts );
	
# External d)
	$email_parts{ 'body' } = $q->captured_output;
	
	#$email_parts{ 'from' } = $q->env( 'alert_on_error:email:from' );
	#$email_parts{ 'to' } = $q->env( 'alert_on_error:email:to' );
	#$email_parts{ 'subject' } = $q->env( 'alert_on_error:email:subject' );
	$email_parts{ 'from' } = $aoe_email{ 'from' };
	$email_parts{ 'to' } = $aoe_email{ 'to' };
	$email_parts{ 'subject' } = $aoe_email{ 'subject' };
	
	$q->load_helper( 'Qoan::Helper::' . $aoe_email{ 'helper' } );
# External e)
  # Can we change "_send_email" to a settings-defined string?
  # Thus we could change the default mail sub for the Controller.
	$sent = $q->_send_email( %email_parts );
	
# External f)
	warn "Error alert email failed to send." unless $sent;
}


# Purpose:  Flatten nested hashes into hash with compound keys
# Context:  Private but not enforced
# Receives: 1) controller ref or controller class name
#           2) key-value list
# Returns:  flattened hash
# External: None.
#
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

# Purpose:  NOT TESTED
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
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


# Purpose:  Loads "server" components at startup
#           (Does NOT export symbols to caller.)
# Context:  executed in BEGIN stage after caller's USE statement.
#           Flag set after execution which prevents subsequent execution.
# Receives: 1) class name (string)
#           2) startup environment values (list -> hash) passed with USE
# Returns:  1, literal
# External: a) requires Qoan::Config component module
#           b) calls sub _load_component for alternate config component
#           c) retrieves overriding start config from external file if directed
#           d) stores startup config
#           e) retrieves config value set (once per server)
#           f) flattens config value set (once per server)
#           g) stores config value set in env (once per server)
#           h) calls warn
#           i) requires interfaceless Qoan component, as needed
#           j) requires other components, as neeeded
#           k) calls sub _error_alert
#           l) checks if errors occured during "server" load
#           m) fetches 'error_alert' values from env
#
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
	#print STDERR "env startup: " . join( ' ', %env_startup ) . "\n";
	
# UNTAINT %env_startup !!
# Main Config - file name only ???
# Caller Config - full path allowed.
# Server - string or hash ref..
	
	$start_config{ $k } = $v while ( $k, $v ) = each %{ $env_default{ 'component' }->{ 'config' } };
	#print STDERR "start cfg 1: " . join( ' ', %start_config ) . "\n";
	$start_config{ $k } = $v while ( $k, $v ) = each %{ $env_startup{ 'component' }->{ 'config' } };
	#print STDERR "start cfg 2: " . join( ' ', %start_config ) . "\n";
	
# Load Config tool.
	if ( $start_config{ 'module' } eq 'Qoan::Config' )
	{
# External a)
		$ok = __PACKAGE__->_require( $start_config{ 'module' } );
		push @ISA, 'Qoan::Config';
	}
	else
	{
# External b)
		$ok = $handler_base->_load_component( 'config' => \%start_config );
	}
	
# Config tool MUST load successfully.
	die "Failed to load config tool $start_config{ 'component:config:module' }" unless $ok;
	
# USE statement params can include 'component:config:use_file', which indicates that the
# Controller must load "env_startup" from a file.
# Values in this file OVERWRITE ALL values passed in %env_startup.
# Values in this file have the same priority as values passed in %env_startup (they override everything).
# Note that config_retrieve is called here as a class method.
# Note that config component settings are copied back into %env_startup; this
# means that any config component settings in the use_file are not used.
	if ( $start_config{ 'use_file' } )
	{
# External c)
		%env_startup = __PACKAGE__->config_retrieve( $start_config{ 'use_file' } );
		$env_startup{ 'component' }->{ 'config' }{ $k } = $v while ( $k, $v ) = each %start_config;
	}
	
# Change defaults if appropriate parameters received.
# Note that the "exists" check means the caller can pass empty values for the two
# config file variables, which means the controller will load nothing from these files.
	$qoan_base_config = $env_startup{ 'qoan_base_config' } if exists $env_startup{ 'qoan_base_config' };
	$app_config = $env_startup{ 'app_config' } if exists $env_startup{ 'app_config' };
	
# Store startup parameters.
# External d)
	__PACKAGE__->config_load( 'controller_start' => \%env_startup );
	
# Add config value sets to base env.
	for ( \%env_default, $qoan_base_config, $app_config, \%env_startup )
	{
		next unless $_;  # Skip config file names if empty.
		print STDERR "Loading cfg: $_\n";
# External e)
		%load_cfg = ref( $_ ) eq 'HASH' ? %{ $_ } : __PACKAGE__->config_retrieve( $_ );
# External f)
		%load_cfg = __PACKAGE__->_flatten( %load_cfg );
# External g)
		__PACKAGE__->env( %load_cfg );
	}
	
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
# External h)
		warn "Component settings for $_ non-existant" unless ref( $server ) eq 'HASH';
		
# This block is for default Qoan packages, with no specified interface.
		if ( ( $server->{ 'module' } || '' ) =~ m|^Qoan::| && ! $server->{ 'interface' } )
		{
# External i)
			$ok = __PACKAGE__->_require( $server->{ 'module' } );
			push @ISA, $server->{ 'module' };
		}
# This block is for any package with an interface, which is required for non-Qoan packages.
		elsif ( $server->{ 'interface' } )
		{
# External j)
			$ok = $handler_base->_load_component( $_, $server );
		}
		
		die qq|Controller "$_" component failed to load: $@| unless $ok;
	}
	
	$used = 1;  # Can't call import again.
	
# Alert for startup errors.
# External k), l), m)
	__PACKAGE__->_error_alert if __PACKAGE__->captured_errors && __PACKAGE__->env( 'alert_on_error' );
	
	return 1;
}


# Purpose:  checks whether request is for writing, or "POST"
# Context:  Public.
# Receives: 1) controller ref
# Returns:  1) implicit undef if request processing has not started
#           2) 1 or 0 literals for request type check against "POST"
# External: a) checks request processing has started
#           b) fetches 'sys_env:request_method' from env
#
sub is_post_request
{
	my( $q ) = shift();
	
# External a)
	return unless $q->request_stage;
# External b)
	return $q->env( 'sys_env:request_method' ) eq 'POST' ? 1 : 0;
}


# Purpose:  load a component for Qoan
# Context:  callable only by sub import, sub process_request, or a Qoan interface
# Receives: 1) controller ref
#           2) component name (string)
#           3) component property hash (used by sub import)
# Returns:  1) implicit undef if disallowed caller
#           2) 1 or 0 literals for a series of checks
# External: a) checks allowed caller
#           b) fetches component properties if not supplied w/ parameter
#           c) calls controller report
#           d) requires component interface package via sub _require
#           e) imports from component interface package
#           f) checks that current request stage is 'load'
#           g) runs component before-new handler
#           h) sets component init values in env, if needed (SHOULD THIS CALL COMPONENT?)
#           i) requires component module (package behind interface)
#           j) fetches init values from env
#           k) creates new component object
#           l) runs component after-new handler
#           m) verifies accessor call returns component with expected reference
#
sub _load_component
{
	my( $q, $component, %component, $new, $before_new, $after_new, $object, $accessor, $stored_ref );
	
# For Controller-level components, $q will be the controller package name.
# For Request-Manager-level components, $q will be the Qoan controller object.
	$q = shift();
	
# This is the component NAME.
	$component = lc( shift() );
	%component = %{ shift() } if $_[ 0 ];  # SERVER COMPONENT ?
	
# External a)
	return unless $q->_allowed_caller(
		#'eq' => [ 'Qoan::Controller::import', 'Qoan::Controller::process_request' ],
		'eq' => [ 'Qoan::Controller::import', 'Qoan::Controller::process_request', map { $_ . '::_process_request_stage_load' } $q->env( 'protected' ) ],
		'=~' => [ '^Qoan::Interface::\w+' ]  # Basically, allows interfaces to instantiate
	    );
	
# Get component settings.
# External b)
	%component = $q->env( "component:$component" ) unless %component;
	
# Require interface module.  Import interface routines.
# External c)
	#$q->report( "Requiring component interface: $component{ 'interface' }.." );
	print STDERR "Requiring component interface: $component{ 'interface' }..";
# External d)
	return 0 unless $q->_require( $component{ 'interface' } );
# External e)
	return 0 unless $component{ 'interface' }->import( $q, $component );
	
# External f)
	return 1 if $q->request_stage( 'current' => 'load' ) &&
		( $component{ 'on_load' } || '' ) eq 'interface_only';
	
# Routines imported from interface.
	$before_new = "_${component}_before_new";
	$after_new = "_${component}_after_new";
	
# Before_New handler must return a true value (indication that component
# must be loaded) or we skip component.
# Skipping non-necessary component counts as a load SUCCESS.
# It can also return contructor arguments as an ARRAY REF.
# External c)
	#$q->report( "Running before-new handler.." );
	print STDERR "Running before-new handler..";
# External g)
	return 1 unless $component{ 'init' } = $q->$before_new;
	
# Store init args if array ref was received.
# WARN?  remove? have before_new handler insert directly via component call?
# WARN   should this be a call to sub COMPONENT ??
# External h)
	$q->env( "component:$component:init" => $component{ 'init' } )
		if ref( $component{ 'init' } ) eq 'ARRAY';
	
# Require component module.
# External c)
	#$q->report( "Requiring component module: $component{ 'module' }.." );
	print STDERR "Requiring component module: $component{ 'module' }..";
# External i)
	return 0 unless $q->_require( $component{ 'module' } );
	
# Instantiate.  Uses returned argument array ref, or arguments saved to functional env.
# External c)
	#$q->report( 'Instantiating component object..' );
	print STDERR 'Instantiating component object..';
# External j)
	$component{ 'init' } = [ $q->env( "component:$component:init" ) ]
		unless ref( $component{ 'init' } ) eq 'ARRAY';
	$new = $component{ 'constructor' } || 'new';
# External k)
	return 0 unless $object = $component{ 'module' }->$new( @{ $component{ 'init' } } );
	
# After_New handler must return a true value to proceed.
# External c)
	#$q->report( "Running after-new handler for $object.." );
	print STDERR "Running after-new handler for $object..";
# External l)
	return 0 unless $q->$after_new( $object );
	
# Supply object to accessor.
# External c)
	#$q->report( 'Submitting object to accessor..' );
	print STDERR 'Submitting object to accessor..';
	$accessor = $component{ 'accessor_alias' } || $component;
# External m)
	$stored_ref = ref( $q->$accessor( $object ) );
# External c)
	#$q->report( "Ref from stored object: $stored_ref" );
	print STDERR "Ref from stored object: $stored_ref";
	
	return 1 if $stored_ref eq $component{ 'module' };
	return 0;
}


# Purpose:  load Qoan helper packages.
# Context:  Public.
# Receives: 1) controller ref
#           .) 1+ Qoan Helper package names
# Returns:  1 or 0 literals.
# External: a) requires helper package
#           b) imports from helper package
#           c) calls controller report/prints to STDERR
#
sub load_helper
{
	my( $q, $helper, @helpers, $can_report, $msg, $ok );
	
	$q = shift();
	@helpers = @_;
	
	$can_report = $q->can( 'report' );
	$ok = 1;
	
	for $helper ( @helpers )
	{
# External a)
		$ok &&= $q->_require( $helper );
		
# WARN  For some reason, running the following line as:
#         $ok &&= $helper->import;
#       causes the program to Die Without Passing Go.  In other words,
#       completely fails to generate error message.
# External b)
		eval { $helper->import; };
		#$ok &&= $@ ? 0 : 1;
		$ok = 0 if $@;
		
		$msg = "Loading helper $helper.. " . ( $ok ? 'succeeded.' : "failed. $@" );
# External c)
		$can_report ? $q->report( $msg ) : print STDERR "$msg\n";
		
		last unless $ok;
	}
	
	return $ok ? 1 : 0;
}


# Purpose:  add actions to action map.  NOT TESTED.
# Context:  Should be callable by app package, before request processing starts.
# Receives: 1) controller ref
#           2) ?
# Returns:  x
# External: a) calls sub action_map accessor
#
sub map_action
{
	my( $q, %action );
	
	$q = shift();
	%action = @_;
	
	$action{ "$_:action" } = delete $action{ $_ } for keys %action;
	
# External a)
	$q->action_map( %action );
	
	return 1;
}


# Purpose:  add checks to action map.  NOT TESTED.
# Context:  Should be callable by app package, before request processing starts.
# Receives: 1) controller ref
#           2) ?
# Returns:  x
# External: a) calls sub action_map accessor
#
sub map_check
{
	my( $q, %validation );
	
	$q = shift();
	%validation = @_;
	
	$validation{ "$_:validation" } = delete $validation{ $_ } for keys %validation;
	
# External a)
	$q->action_map( %validation );
	
	return 1;
}


# Purpose:  add routes to action map.  NOT TESTED.
# Context:  Should be callable by app package, before request processing starts.
# Receives: 1) controller ref
#           2) ?
# Returns:  x
# External: a) calls sub action_map accessor
#
sub map_route
{
	my( $q, %route );
	
	$q = shift();
	%route = @_;
	
	$route{ "$_:route" } = delete $route{ $_ } for keys %route;
	
# External a)
	$q->action_map( %route );
	
	return 1;
}


# Purpose:  add views to action map.  NOT TESTED.
# Context:  Should be callable by app package, before request processing starts.
# Receives: 1) controller ref
#           2) ?
# Returns:  x
# External: a) calls sub action_map accessor
#
sub map_view
{
	my( $q, %view );
	
	$q = shift();
	%view = @_;
	
	$view{ "$_:view" } = delete $view{ $_ } for keys %view;
	
# External a)
	$q->action_map( %view );
	
	return 1;
}


# Purpose:  provides components with access to controller methods
# Context:  Private but not enforced
# Receives: 1) controller ref
#           2) name of method to execute (string)
#           .) 1+ parameters for method
# Returns:  1) implicit undef if no parameters received
#           2) implicit undef if calling component not established
#           3) implicit undef if method requested not allowed
#           4) external: result of requested method
# External: a) fetches complete component list
#           b) fetches 'action_manager:name' from env
#           c) fetches app package name
#           d) calls warn
#           e) fetches published list for component
#           f) submits _method status to controller report
#           g) calls requested method
#
sub _method
{
	my( $q, $method, @params, $calling_pkg, %components, $component, %allowed, $env_allowed );
	
	$q = shift();
	return unless @params = @_;
	
	$method = '';
	$calling_pkg = '';
	$component = '';
	$env_allowed = 0;
	
# Determine caller's component.
# Note that calling package is the one calling the *previous* routine, not caller of _method.
	$calling_pkg = ( caller( 1 ) )[ 0 ];
# External a)
	%components = $q->component;
	
	for ( keys %components )
	{
		$component = $_ if $calling_pkg eq $components{ $_ }->{ 'module' };
		last if $component;
	}
	
# External b), c)
	$component = 'action_manager' if $calling_pkg eq ( $q->env( 'action_manager:name' ) || '' ) ||
		$calling_pkg eq $q->app_package;
	
	unless ( $component )
	{
# External d)
		warn "Caller @{[ ( caller( 2 ) )[ 3 ] ]} in package $calling_pkg " .
			"attempted controller access with parameters: @params";
		return;
	}
	
# Find requested method in published list for component.
# External e)
	%allowed = $q->publish( $component );
	
# External f)
	$q->report( "Method request for: $params[ 0 ], by: $component ($calling_pkg)" );
	
	for ( keys %allowed )
	{
		#$q->report( "checking published: $_ => $allowed{ $_ }" );
		$method = shift( @params ) if @params && $params[ 0 ] eq $_;
		#$env_allowed = 1 if $allowed{ $_ } eq 'env';
	}
	
# External f)
	#$q->report( " => @{[ $method ? '' : 'not ' ]}allowed" );
	$q->report( ' => NOT ALLOWED' ) unless $method;
	
# External g)
	return $q->$method( @params ) if $method;
	return;
}


# Purpose:  controller constructor
# Context:  callable by sub process_request & app package (e.g. "main").
#           Explicitly *not* callable by any other Qoan module.
# Receives: 1) class name (package name of controller or subclasser)
# Returns:  1) implicit undef for disallowed caller
#           2) Qoan controller object
# External: a) checks allowed caller
#           b) submit env values to request-specific env (2)
#           c) fetch env values via config component
#
sub new_request
{
	my( $class, %load_cfg, %env, %ro, %component, %action_map, %response, %publish, %clip, $q, $k, $v );
	my( %set_env );
	
	$class = shift();
	
# External a)
	return unless $class->_allowed_caller(
		'eq' => [ 'Qoan::Controller::process_request', $class->app_package ], '!~' => [ 'Qoan::' ] );
	
# Bootstrap accessor setting.
# The bootstrap event is internal to Qoan::Controller; hence its accessors
# are set with __PACKAGE__ and not $class.
	$env{ 'closure_accessors' } = [ __PACKAGE__ . '::env', __PACKAGE__ . '::publish' ];
	
# BEGIN REQUEST CONTEXT CLOSURE.
# Purpose:  access to request-specific env/other value stores
# Context:  called only by designated accessors
# Receives: name of value to get/key-value list of values to set (all strings)
# Returns:  1) implicit undef for disallowed caller/certain other failures
#           2) requested value
# External: a) checks allowed caller
# Note:
#     Determines which value store to manipulate based on accessor.
#
	$q = sub {
		local *__ANON__ = 'request_closure_' . time();
		my( $caller, $store, $k, $v, @keypath, $index, $loc, $i );
		
# External a) (main closure, not sub new_request)
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
			$caller eq 'Qoan::Controller::clipboard' ? \%clip :
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
# Recognized compound index segment separators are . and :, e.g.:
#   action_manager:name
#   action_manager.name
			@keypath = split( /[:\.]/, $k );
			$index = pop( @keypath );
			$loc = $store;
			for ( @keypath )
			{
				#$loc->{ $_ } = { } if $v && ! defined $loc->{ $_ };
				$loc->{ $_ } = { } unless defined $loc->{ $_ };
				$loc = $loc->{ $_ };
			}
			
# Update if value submitted along with key.
			if ( defined $v )
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
					$loc->{ $index } = $v;
				}
			}
		}
		
# Return last index's value.
		if ( $index )
		{
			return %{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'HASH';
			return @{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'ARRAY';
			return $loc->{ $index } if exists ${ $loc }{ $index };
		}
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
# Note that this defaults to current package's base env if $class is a subclass
# and it provides none.
# NOTE SEP 2012: $class->env falls back on __PACKAGE__->env if it supplies none.
# Commenting out second call.
	%set_env = $class->env;
	#%set_env = __PACKAGE__->env unless %set_env;
# External b)
	#$q->env( $class->env );  #|| __PACKAGE__->env );
	$q->env( %set_env );
	
# Load config values passed with call to new_request.
# UNTAINT
	for ( @_ )
	{
# External c)
		%load_cfg = ref( $_ ) eq 'HASH' ? %{ $_ } : $class->config_retrieve( $_ );
# External b)
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
#  SET THIS AFTER LOADING OF CONFIG FILES, not here! - ?? Sep '12
	$env{ 'component' }->{ 'session' }{ 'store' } = $env{ 'directory' }->{ 'tmp' } . 'sessions/';
	
# "Internal" env values, for the handler.
# Explicitly set here to prevent being set by config importation.
#	$env{ 'request_stage' }    = 'prestart';
	$env{ 'ok' }               = 1;
	$env{ 'started' }          = time();
	
	return $q;
}


# Purpose:  get/set main closure's OK (overall success) value
#           Set is restricted to sub process_request after processing starts.
# Context:  Public.
# Receives: 1) controller ref
#           2) optional new OK setting, must be 1 or 0.
# Returns:  1) implicit undef if $new_ok received in incorrect format
#           2) OK setting.
# External: a) checks if there's a processing stage
#           b) calls main closure
# Note:
#	The status can be set from true to false, but not from false to true
#       (managed by main closure).
#
sub ok
{
	my( $q, $new_ok, $before_processing, $caller );
	
	$q = shift();
	
	$caller = ( caller( 1 ) )[ 3 ];
# External a)
	$before_processing = $q->request_stage ? 0 : 1;
	
	$new_ok = shift() if
		$before_processing ||
		$caller eq 'Qoan::Controller::process_request';
	
	if ( $new_ok && $new_ok ne '0' && $new_ok ne '1' )
	{
		warn qq|New OK value received in incorrect format: "$new_ok" (must be 1 or 0)|;
		return;
	}
	
# External b)
	return $q->( 'ok' => $new_ok ) if $new_ok;
	return $q->( 'ok' );
}


# Purpose:  Handle request.
# Context:  App package (e.g. main) only.
# Receives: 1) controller ref
#           .) 1+ hashrefs or file names (strings) for config.
#              Ignored if controller already instantiated.
# Returns:  1) implicit undef in certain cases of failure
#           2) controller OK value, which should be 1 or 0
# External: LOADS of external!
#
sub process_request
{
	#my( $q );
	my( $q, $action_name, $stage, $handler, $stage_result, $stderr_redirected );
	
	$stderr_redirected = 0;
	
	$q = shift();
	$action_name = $q->env( 'action:name' ) || '';
	
# PREP STUFF FOR STAGE LOOP HERE (from current version of process_request)
	# ??
	
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
		$stderr_redirected = 1;
	}
	
	
	$q->report( "\n****  ***  **  *\nREQUEST PROCESSING FOR $q\n" );
	
	for $stage ( $q->env( 'request_stages' ) )
	{
		$q->env( 'request_stage' => $stage );
		$q->report( ":: \U$stage\E STAGE ::\n" );
		
		$handler = "_process_request_stage_$stage";
		$q->ok( $stage_result = $q->$handler );
		
		$q->report( "\nstage status: @{[ $stage_result ? 'OK' : 'FAIL' ]}\n" );
		
# Abort entire request if ROUTE stage failed.
		if ( $stage eq 'route' && ! $q->ok )
		{
			$q->report( 'Route stage failed, aborting.' );
			return 0;
		}
		
# For "client resource" requests (css, js, etc), load only the request component.
		$q->env( 'component_load_order' => [ 'request' ] ) if $action_name eq 'client_resource';
		
		$q->report( ":: end $stage stage ::\n\n" );
	}
	
# Flag request as handled.
	$q->env( 'request_stage' => 'finished' );
	
# Reset logging environment to normal if logging was redirected in this subroutine.
	$q->capture_output if $stderr_redirected;
	
# Admin alerts for requests handled with errors.
# Does not send alert if debug report was returned to client.
	$q->_error_alert if $q->captured_errors && $q->env( 'alert_on_error' ) && ! $q->env( 'returned_http_debug_report' );
	
	return $q->ok;
}

#sub process_request_old
#{
#	my( $q );
#	
## LOAD/UNLOAD
#	my( @load_order, $component );
## LOAD only
#	my( $loaded );
## UNLOAD only
#	my( $unloaded );
## ROUTE
#	my( $am_package, $am_origin, $am_route, $am_loaded, $using_internal_get_action );
## ACTION
#	my( $action_stage, $stage_ok );
#	# also am_package, am_loaded, render_view, view_source
## RENDERING
#	my( $render_view, $view_source, $view_exists, %renderer_params );
## RESPONSE
#	my( $return_debug );
#	
#	$q = shift();
#	
## If $q is not an object, instantiate.
## If it is, verify using request_stage that the handler hasn't been called yet.
#	if ( ! ref $q )
#	{
#		$q = $q->new_request( @_ ) or die 'Could not instantiate controller!';
#	}
#	else
#	{
#		if ( $q->request_stage )
#		{
#			warn "Attempt to call a running process handler by @{[ ( caller( 1 ) )[ 3 ] ]}";
#			return;
#		}
#		
#		return unless $q->_allowed_caller( 'eq' => [ $q->app_package ] );
#	}
#	
## Set up reporting.
#	unless ( $q->capturing )
#	{
#		$q->capture_output;
#		$q->env( 'stderr_redirected_in_request_handler' => 1 );
#	}
#	
#	
#	$q->report( "\n****  ***  **  *\nREQUEST PROCESSING FOR $q\n" );
#	
## ROUTE STAGE
## Set request stage.
#	$q->env( 'request_stage' => 'route' );
#	
#	$q->report( ":: ROUTE STAGE ::\n" );
#	
## URI SHIT.  Kind of Argh.  Clean this up somehow.
## Get request header.
## Prepend with slash and remove query string if any.
#	my( $uri_virtual, $uri_app_root, $docroot, $alias, $virt_alias, $recd_private );
#	$alias = $ARGV[ 0 ];
#	$docroot = $q->env( 'sys_env:document_root' );
#	$uri_virtual = $q->env( 'sys_env:' . $q->env( 'uri_source_header' ) );
## If the received alias is *not* in the request URI, then the redirect_cfg file uses
## different public and private aliases.
#	$recd_private = ( $uri_virtual !~ m|$alias| ? 1 : 0 );
#	$uri_virtual = "/$uri_virtual" unless $uri_virtual =~ m|^/|;
#	$uri_virtual =~ s|\?.*$|| if $q->env( 'uri_source_header' ) eq 'request_uri';
#	$uri_app_root = '';
#	for ( split( '/', $uri_virtual ) )
#	{
#		next unless $_;
#		last unless -e "$docroot$uri_app_root/$_";
#		$uri_app_root .= "/$_";
#		#print "uri: lead: $uri_app_root";
#	}
#	$uri_virtual =~ s|^$uri_app_root||;
## "uri:alias:virtual" means that the app alias is in the URI's virtual part ONLY.
## The default is to use a directory as the resource "mask" for the app, and
## the dir name serves as the public app alias, hence not virtual.
#	if ( ! $recd_private )
#	{
#		$virt_alias = ( $uri_app_root =~ m|$alias$| ? 0 : 1 );
#		$uri_virtual = "/$alias" . $uri_virtual unless $q->env( 'uri:alias:virtual' );
#	}
#	else
#	{
#		$virt_alias = 0;
#		$uri_virtual = '/' . ( $uri_app_root =~ m|(\w+)$| )[ 0 ] . $uri_virtual;
#	}
#	$q->env( 'uri:alias:received_private' => $recd_private );
#	$q->env( 'uri:alias:virtual' => $virt_alias );
#	$q->env( 'uri:alias:public' => ( $uri_virtual =~ m|^/?(\w+)| )[ 0 ] );  #unless $q->env( 'uri:alias:public' );
#	$q->env( 'uri:alias:private' => $recd_private ? $alias : ( $uri_virtual =~ m|^/?(\w+)| )[ 0 ] );
#	$q->env( 'uri:virtual' => $uri_virtual );
#	$q->env( 'uri:app_root' => $uri_app_root );
#	$q->env( 'uri:alias:argv' => $alias );
#	
#	
## REQUEST PROCESSING, start report.
#	$q->report( "Calling package:         @{[ $q->app_package ]}" );
#	$q->report( "Calling file:            @{[ $q->app_script ]}" );
#	$q->report( "Request:                 @{[ $q->env( 'uri:virtual' ) ]}" );
#	$q->report( "Current status:          @{[ $q->ok ? 'ok' : 'FAIL' ]}\n" );
#	
## II.a  Determine action manager
#	$q->report( ":: getting action manager ::\n" );
#	
#	$using_internal_get_action = 0;
#	
## A.
## A.1
## The calling package submitted an action map or has an action map fetch routine.
#	if ( $q->action_map || $q->app_package->can( 'get_action_map' ) )
#	{
#		#$q->report( 'Action map extant/caller provides loader, setting AM to main caller' );
#		$am_package = $q->app_package;
#		$am_origin = 'main caller';
#		$am_route = '';
#		$am_loaded = 1;
#	}
## A.2
## The action map is in the app's config file.
#	elsif ( $q->env( 'action_map' ) )
#	{
#		$am_package = $q->app_package;
#		$am_origin = 'config file';
#		$am_route = '';
#		$am_loaded = 1;
#	}
## B.
## Caller does not provide action map, so it must come from an Action Manager.
#	else
#	{
## B.1
## Caller or config file supplied an Action Manager name.
#		if ( $q->env( 'action_manager:name' ) )
#		{
#			#$q->report( 'Action manager name set directly by main caller or config file' );
#			$am_package = $q->env( 'action_manager:name' );
#			$am_origin = $q->env( 'action_manager:type' ) || 'set by main caller/config file';
#			$am_loaded = $am_package eq $q->app_package ? 1 : 0;
#		}
## B.2
## Caller did not provide an Action Manager name.
#		else
#		{
## B.2.i
## Self might BE an Action Manager if using a modified/overridden Controller.
#			if ( $q->isa( 'Qoan::ActionManager' ) )
#			{
## WARN  :: in regex, works correctly?
#				#$q->report( 'Controller is also Action Manager, setting AM to inherited package' );
#				no strict 'refs';
#				my @ctlr_isa = @{ ref( $q ) . '::ISA' };
#				#use strict 'refs';
#				$am_package = ( grep { /^Qoan::ActionManager::/ } @ctlr_isa )[ 0 ];
#				$am_origin = 'superclass/inherited';
#				$am_loaded = 1;
#			}
## B.2.ii
## Determine Action Manager based on request URI.
#			else
#			{
#				my( %routes );
#				
#				%routes = $q->env( 'action_manager_routes' );
#				
#				$q->report( 'Checking action manager routes in config' );
#				$q->report( 'count of available routes: ' . keys( %routes ) );
#				
#				for $am_route ( sort keys %routes )
#				{
#					$q->report( "comparing path: $am_route" );
#					next unless $q->env( 'uri:virtual' ) =~ m|$am_route|;
#					$am_package = $routes{ $am_route };
#					$am_origin = 'route selection';
#					$am_loaded = 0;
#					last;
#				}
#			}
#			
## B.2.iii
## If action manager still not found, use default route.
## WARN  SHOULD WE EVEN ALLOW A DEFAULT ACTION MANAGER ROUTE?
#			if ( ! $am_package && $q->env( 'default_route' ) )
#			{
#				$q->report( 'No matching action manager routes, using config default route' );
#				$am_package = ( $q->_route_compare( $q->env( 'default_route' ), $q->env( 'uri:virtual' ) ) )[ 0 ];
#				$am_package = ucfirst( $am_package );
#				$am_package =~ s|_(\w)|\U$1|g;
#				$am_origin = 'default route in config' if $am_package;
#				$am_loaded = 0;
#			}
#			
## B.2.iv
## If there is no action manager for a WRITE request, raise an error.
## If there is no action manager for a GET request, and auto get is available.
#			if ( ! $am_package )
#			{
#				( $q->is_post_request || ! $q->env( 'allow_default_get_action' ) )
#					? warn( "No action manager found for WRITE request or for GET with auto get unavailable\n" )
#					: $q->report( "No action manager found for GET request, auto get available.\n" );
#			}
#		}
#		
## B.2.v
## Load action manager package if necessary.
#		if ( $am_package && $am_package ne 'main' && ! $am_loaded )
#		{
#			$am_package = 'Qoan::ActionManager::' . $am_package if $am_origin ne 'caller';
#			$am_loaded = $q->_require( $am_package );
#		}
#	}
#	
## B.2.vi
## At this point, any Action Manager should be loaded.
#	if ( $am_loaded )
#	{
#		$q->env( 'action_manager:name' => $am_package );
#		$q->env( 'action_manager:type' => $am_origin );
#		$q->env( 'action_manager:route' => $am_route ) if $am_route;
#		
#		if ( $q->env( 'action_map' ) )
#		{
#			$q->action_map( $q->env( 'action_map' ) );
#		}
#		else
#		{
#			my( $get_map_sub, $sub_defined );
#			{
#			 no strict 'refs';
#			 $get_map_sub = \&{ $am_package . '::get_action_map' };
#			 $sub_defined = defined( &{ $am_package . '::get_action_map' } );
#			}
#			
#			$q->action_map( $get_map_sub->() ) if $sub_defined;
#		}
#	}
## B.2.vii
## If no Action Manager, and it's a GET request and default gets are allowed, set action
## map to default get.
#	elsif ( ! $q->is_post_request && $q->env( 'allow_default_get_action' ) )
#	{
#		#$q->action_map( 'default_action' => 'get',
#		#		'default_view' => 'index',
#		#		'get' => { 'route' => '/:view' } );
#		$q->action_map( $q->env( 'default_get_action_map' ) );
#		$using_internal_get_action = 1;
#	}
#	
## Client resource request support.
#	if ( $q->env( 'client_resource_action:enabled' ) )
#	{
#		$q->action_map( 'client_resource:route' => $q->env( 'client_resource_action:route' ) );
#		
#		#$am_package = 'client_resource';
#		#$q->env( 'action_manager:name' => $am_package );
#		#$q->env( 'action_manager:type' => $am_origin );
#		$am_route = $q->action_map( 'client_resource:route' );
#		$q->env( 'action_manager:route' => $am_route );
#		
## THIS NEEDS TO HAPPEN ONLY IF THE ACTION IS CLIENT RESOURCE FETCH.
#		#my @stages = $q->env( 'request_stages' );
#		#my @removed;
#		#for ( @stages )
#		#{
#		#	push( @removed, $_ ) if $_ ne 'load' && $_ ne 'unload' && $_ ne 'cleanup';
#		#}
#		#$q->env( 'request_stages' => \@removed );
#	}
#	 
## Starting request status depends on whether an action manager was found.
#	unless ( $q->action_map )
#	{
#	 	$q->ok( 0 );
#		warn 'Failed to locate action map.';
#	}
#	
## Stage end report.
#	$q->report( "public app alias:        @{[ $q->env( 'uri:alias:public' ) ]}" );
#	$q->report( "private app alias:       @{[ $q->env( 'uri:alias:private' ) ]}" );
#	$q->report( "action manager loaded?   @{[ $am_loaded ? 'yes' : 'NO' ]}" );
#	$q->report( "action manager:          @{[ $am_loaded ? $am_package : 'none' ]}" );
#	$q->report( "action manager alias:    @{[ $q->env( 'action_manager:alias' ) ]}" );
#	$q->report( "action manager origin:   @{[ $am_loaded ? $am_origin : '' ]}" );
#	$q->report( "action manager route:    @{[ $am_loaded ? $am_route : '' ]}" );
#	$q->report( "action map exists?       @{[ $q->action_map ? 'yes' : 'no' ]}" );
#	$q->report( "using default get map?   @{[ $using_internal_get_action ? 'yes' : 'no' ]}\n" );
#	
## Identify requested action.
## NOTE THIS SHOULD RETURN TRUE/FALSE break on false?
#	$q->_action_identify;
#	$q->report( '' );  # line break
## END of ROUTE STAGE.
#	
#	
## I. Load components
#	#$q->env( 'request_stage' => _load_stage() );
#	$q->env( 'request_stage' => 'load' );
#	
#	$q->report( ":: LOAD STAGE ::\n" );
#	@load_order = $q->env( 'component_load_order' );
#	$q->report( "Components to load: @{[ join( ', ', @load_order ) ]}\n" );
#	
#	for $component ( @load_order )
#	{
#		next unless $q->ok;
#		$q->report( "Loading component: $component" );
#		$q->ok( $loaded = $q->_load_component( $component ) );
#		$q->report( "Load $component returned: @{[ $loaded ? 'ok' : 'FAIL' ]} ($loaded)\n" );
#	}
#	
## Return if something goes wrong during context component load.
#	unless ( $q->ok )
#	{
#		warn "Load failed; aborting request handling";
#		return;
#	}
#	
#	$q->report( ":: end load stage ::\n" );
#	
#	
## II. Execute action
#	#$q->env( 'request_stage' => _action_stage() );
#	$q->env( 'request_stage' => 'action' );
#	
#	$q->report( ":: ACTION STAGE ::\n" );
#	
## II.b  Execute action
#	#$q->report( ":: executing action ::\n" );
#	
## Set component-accessible controller routines from env.
#	$q->publish( $q->_flatten( $q->env( 'publish' ) ) );
#	
## START Action Manager component access block
#	{
## Setup of component data in Action Manager.
## Note, lexically scoped to block just started.
## Note, this is done if the Action Manager is loaded, which means NOT for the internal
## default get action map.
## WARN  The following use $q, and might have problems in a mod_perl environment,
##	but the idea is that the wrapping "local" will cause the lexical reference to 
##	evaporate once the block is exited.
#	 no strict 'refs';
#	 no warnings 'redefine';
## Controller access alias for Action Manager.
#	 local *{ $am_package . '::qoan' } = sub {
#		local *__ANON__ = 'controller_access_closure_actionmanager';
#		shift() if ref( $_[ 0 ] );
#		return $q->_method( @_ ); } if $am_loaded;
## Controller access alias for components.
##	 my(  );
##	 local *{ $_ . '::qoan' } = sub {
##		local *__ANON__ = "controller_access_closure_$_";
##		shift() if ref( $_[ 0 ] );
##		return $q->_method( @_ ); } for @controller_access;
#	 
#	 use warnings 'redefine';
#	 use strict 'refs';
#	 
## Test of exported $am_package variables, must return values.
## NOTE  these tests are no good now, rewrite if using again.
#	# if ( $am_loaded )
#	# {
#	#	&::controller_report( 'This is calling the controller functional ENV via MAIN.' );
#	#	&::controller_report( " [from main] :: $_: $::request{ $_ }" ) for sort keys %::request;
#	# }
#	 
#	 $stage_ok = $q->ok;
#	 
## The action at last!
#	 for $action_stage ( $q->env( 'action_stages' ) )
#	 {
#		$q->report( "Opening action stage: \U$action_stage\E  with status: $stage_ok @{[ $stage_ok ? '' : '(skipping)' ]}" );
#		next unless $stage_ok;
#		
#		$action_stage = "_action_$action_stage";
#		
## Runs Action Manager stage handler if extant.
## (There might be no Action Manager if it is a GET request and default get action maps are allowed.)
#		if ( $am_loaded && $am_package->can( $action_stage ) )
#		{
#			my $sub_ref;
#			{
#			 no strict 'refs';
#			 $sub_ref = \&{ $am_package . '::' . $action_stage };
#			}
#			
#			$stage_ok = $sub_ref->();
#		}
#		else
#		{
#			$stage_ok = $q->$action_stage;
#		}
#		
#		$q->env( "action:$action_stage:ok" => $stage_ok );
#		$q->ok( $stage_ok );
#		$q->report( qq|stage returned: @{[ $stage_ok ? 'ok' : 'FAIL' ]} ($stage_ok)\n| );
#	 }
#	 
## Action handling CHECK or EXECUTE might have set the view to render.
#	 if ( $render_view = $q->env( 'render_view' ) )
#	 {
#	 	$view_source = 'action handling';
#	 }
#	 
## If the action handling check and execute stages did not supply a view to render,
## run an Action Manager selection routine, if available.
#	 if ( ! $render_view && $am_loaded && $am_package->can( 'select_view_to_render' ) )
#	 {
#		$render_view = $am_package->select_view_to_render;
#		$view_source = 'action manager select routine' if $render_view;
#	 }
#	 
#	 $q->report( "\n:: end action stage ::\n" );
#	}
## END Action Manager component access block
#	
## Test of exported $am_package variables after scope-end (must return NO VALUES).
#	#$q->report( 'Request in am?' );
#	#$q->report( " :: $_: $main::request{ $_ }" ) for sort keys %main::request;
#	
#	
## III. Render View
#	#$q->env( 'request_stage' => _render_stage() );
#	$q->env( 'request_stage' => 'render' );
#	
#	$q->report( ":: RENDER RESPONSE STAGE ::\n" );
#	
#	$q->report( ":: selecting view ::\n" );
#	
## Special case for internal get??
## Ideally, the following if-block (as is) should handle this.
#	#if ( ! $render_view && $using_internal_get_action )
#	#{
#	#	;
#	#}
#	
## Client Resource (internal).
#	if ( $q->env( 'action:name' ) eq 'client_resource' )
#	{
#		
#		$render_view  = $q->env( 'client_resource_action:store' ) . ':';
#		$render_view .= $q->env( 'uri:resource_name' ) || $q->env( 'uri:alias:private' ); # . '.';
#		$render_view .= '_' . $q->env( 'uri:resource_type' );
#		$view_source = 'client resource request';
#	}
#	
## From action section of action map (action name).
#	if ( ! $render_view && $q->env( 'action:name' ) )
#	{
#		$render_view = $q->action_map( $q->env( 'action:name' ) . ':view' );
#		$view_source = 'supplied by action' if $render_view;
#	}
#	
## Action name or last segment of URI if using internal get action.
#	if ( ! $render_view && $q->env( 'action:route' ) )
#	{
#		my( @segments );
#		@segments = map { $q->env( "uri$_" ) } ( $q->env( 'action:route' ) =~ m|/(:\w+)|g );
#		
#		$render_view = join( ':', @segments );
#		$view_source = 'URI extraction' if $render_view;
#	}
#	
## Action Map/Manager default.
## Note the source says "action manager" but this is because an AM can only have
## one action map.
#	unless ( $render_view )
#	{
#		$render_view = $q->action_map( 'default_view' );
#		$view_source = 'action manager default' if $render_view;
#	}
#	
## Application default.
#	unless ( $render_view )
#	{
#		$render_view = $q->env( 'default_view' );
#		$view_source = 'application default' if $render_view;
#	}
#	
#	$q->env( 'render_view' => $render_view ) unless $q->env( 'render_view' );
#	$q->env( 'view_source' => $view_source );
#	
## View sources.
#	unless ( $q->env( 'view_sources' ) )
#	{
#		my( @view_store, $i );
#		
## Note that the following line works regardless of whether view:store
## is a scalar or an array.
#		@view_store = $q->env( 'component:view:store' );
#		
#		for ( $i = $#view_store; $i >= 0; $i-- )
#		{
#			$view_store[ $i ] = $q->app_dir . $view_store[ $i ] unless $view_store[ $i ] =~ m|^/|;
#			
#			unless ( -d $view_store[ $i ] && -r $view_store[ $i ] )
#			{
#				warn( "View source is not a directory or not readable: $view_store[ $i ]" );
#				splice( @view_store, $i, 1 );  # removes path
#			}
#		}
#		
#		push( @view_store, $q->qoan_base_dir . $q->env( 'qoan_view_store' ) ) unless $q->env( 'local_views_only' );
#		
#		$q->env( 'view_store' => [ @view_store ] );
#	}
#	
## Check that starting view exists.  This is to retain control over HTTP requests
## for resources that don't exist.
#	for ( $q->env( 'view_store' ) )
#	{
#		my $exists;
#		( $exists = $render_view ) =~ s|:|/|g;
#		$q->report( "testing existence: $_$exists\.\*" );
#		$view_exists = 1 if glob( "$_$exists.*" );
#		last if $view_exists;
#	}
#	
#	
## Report on view found to be rendered.
#	$q->report( "starting view:           @{[ $render_view || 'none' ]}" );
#	$q->report( "view source:             @{[ $view_source || '' ]}" );
#	$q->report( "starting view exists?    @{[ $view_exists ? 'yes' : 'no' ]}" );
#	$q->report( "action map default view: @{[ $q->action_map( 'default_view' ) ]}\n" );
#	$q->report( qq|view repositories:\n@{[ join( "\n", $q->env( 'view_store' ) ) ]}\n| );
#	
#	
## View rendering.
#	$q->report( ":: rendering view ::\n" );
#	
## Block to localize controller access alias for view component.
## WARN  commented out because otherwise it disallows controller access during debug
##	report rendering (see SENDING RESPONSE, below).
#	#{
#	no strict 'refs';
#	local *{ 'Qoan::View' . '::qoan' } = sub {
#		local *__ANON__ = 'controller_access_closure_view';
#		shift() if ref( $_[ 0 ] );
#		return $q->_method( @_ ); };
#	use strict 'refs';
#	
#	if ( $render_view eq '[[DATA]]' )
#	{
#		$q->response( 'body' => $q->response( 'data' ) );
#	}
#	else  # rendering view from text
#	{
#		unless ( $view_exists )
#		{
#			$q->report( q|Rendering action map's default view in place of non-existent starting view.| );
#			$render_view = $q->action_map( 'default_view' );
#		}
#		
#		%renderer_params = $q->env( 'renderer_parameters' );
#		$renderer_params{ 'view_start' } = $render_view;
#		$renderer_params{ 'sources' } = [ $q->env( 'view_store' ) ];
#		
#		#my $rendered = $q->view_render( %renderer_params );
#		#$rendered = Encode::encode( 'utf8', $rendered );
#		#Encode::_utf8_on( $rendered );
#		#$q->response( 'body' => $rendered );
#		$q->response( 'body' => $q->view_render( %renderer_params ) );
#		#}
#		
#		warn( 'Response is empty' ) unless $q->response( 'body' );
#	}
#	
#	$q->report( "\n:: end render stage ::\n" );
#	
#	
## IV. Unload
#	#$q->env( 'request_stage'=> _unload_stage() );
#	$q->env( 'request_stage' => 'unload' );
#	
#	$q->report( ":: UNLOAD STAGE ::\n" );
#	
#	@load_order = $q->env( 'component_unload_order' ) || reverse @load_order;
#	
#	for $component ( @load_order )
#	{
#		#next unless $q->ok;  # ??? should always unload ?
#		$q->report( "Unloading component: $component" );
#		#$q->ok( $unloaded = $q->_unload_component( $component ) );
#		$unloaded = $q->_unload_component( $component );
#		$q->report( "Unload $component returned: @{[ $unloaded ? 'ok' : 'FAIL' ]} ($unloaded)\n" );
#	}
#	
#	$q->report( ":: end unload stage ::\n" );
#	
#	
## V. SENDING RESPONSE
#	#$q->env( 'request_stage'=> _respond_stage() );
#	$q->env( 'request_stage' => 'response' );
#
## Set response to debug report if:
##  - config is set to allow it, AND
##  - session is set to allow it OR permissive setting in config is ON, AND
##  - there is NO rendered response OR a debug request parameter is set.
## NOTE that this is (Dec 2011) the ONLY place where the controller refers to context
## component values AT ALL, when deciding to send the debug report to the client.
##  values: session:admin_debug_http, request:debug = http
## Note, as components are unloaded, calls are made to env component member stores.
#	if ( $q->env( 'http_debug:allow' ) )
#	{
#		my( $debug_param, $debug_value );
#		
#		$debug_param = 'request:' . $q->env( 'http_debug:request_param' );
#		$debug_value = $q->env( 'http_debug:request_value' );
#		
#		$q->report( 'Checking whether to send debug report to client..' );
#		$return_debug = 0;
#		$return_debug = 1 if $q->env( 'session:permission:http_debug' );
#		$return_debug = 1 if $q->env( 'http_debug:allow_public' );
#		#$return_debug &&= ( $q->env( $debug_param ) eq $debug_value ) if $q->env( $debug_param );
#		$q->report( $return_debug );
#		
#		if ( $return_debug )
#		{
#			$q->report( 'Returning debug report to client.' );
#			
#			%renderer_params = $q->env( 'renderer_parameters' );
#			$renderer_params{ 'view_start' } = $q->env( 'http_debug:view' );
#			$renderer_params{ 'sources' } = [ $q->env( 'view_store' ) ];
#			$renderer_params{ 'run_report' } = $q->captured_output;
#			$renderer_params{ 'errors' } = [ $q->captured_errors ];
#			
#			$q->response( 'body' => $q->view_render( %renderer_params ) );
#			$q->response( 'header:content-type' => 'text/html' );
#		}
#	}
#	
## Send response, unless caller has indicated it will do it.
#	unless ( $q->env( 'delay_response' ) )
#	{
#		$q->env( 'response_sent' => $q->send_response );
#	}
#	
## VI. COMPLETED  Flag request as handled.
#	#$q->env( 'request_stage' => _finished() );
#	$q->env( 'request_stage' => 'finished' );
#	
## Reset logging environment to normal if logging was redirected in this subroutine.
#	$q->capture_output if $q->env( 'stderr_redirected_in_request_handler' );
#	
## Admin alerts for requests handled with errors.
## Does not send alert if debug report was returned to client.
#	$q->_error_alert if $q->captured_errors && $q->env( 'alert_on_error' ) && ! $return_debug;
#	#if ( $q->captured_errors && $q->env( 'alert_on_error' ) && ! $return_debug )
#	#{
#	#	if ( $q->env( 'alert_on_error:errorlog' ) )
#	#	{
#	#		$q->flush_captured;
#	#	}
#	#	
#	#	if ( $q->env( 'alert_on_error:email' ) )
#	#	{
#	#		my( $sent, %email_parts );
#	#		
#	#		$email_parts{ 'body' } = $q->captured_output;
#	#		$email_parts{ 'from' } = $q->env( 'alert_on_error:email:from' );
#	#		$email_parts{ 'to' } = $q->env( 'alert_on_error:email:to' );
#	#		$email_parts{ 'subject' } = $q->env( 'alert_on_error:email:subject' );
#	#		
#	#		$q->load_helper( 'Qoan::Helper::' . $q->env( 'alert_on_error:email:helper' ) );
#	#		$sent = $q->_send_email( %email_parts );
#	#		
#	#		warn( "Error alert email failed to send." ) unless $sent;
#	#	}
#	#}
#	
#	return $q->ok;
#}


sub _process_request_stage_route
{
	my( $q );
# Request URI operations.
	my( $alias, $docroot, $uri_virtual, $recd_private, $uri_app_root, $virt_alias );
# Determining Action Manager/Map.
	my( $am_package, $am_origin, $am_route, $am_loaded, $using_internal_get_action );
# Identifying action.
	my( %map, @order, $i ); #, $req_uri );
	my( $action, $route, @routes, @compared, $identified );
	my( @symbols );
	
	$q = shift();
	
# REQUEST PROCESSING, start report.
	$q->report( "Calling package:         @{[ $q->app_package ]}" );
	$q->report( "Calling file:            @{[ $q->app_script ]}" );
	$q->report( "Current status:          @{[ $q->ok ? 'ok' : 'FAIL' ]}\n" );
 	
# App alias.
	$alias = $ARGV[ 0 ];
	$docroot = $q->env( 'sys_env:document_root' );
	
# Request header.
# Prepend with slash and remove query string if any.
	$uri_virtual = $q->env( 'sys_env:' . $q->env( 'uri_source_header' ) );
	
# If the received app alias is *not* in the request URI, then the app's redirect_cfg
# file uses different public and private aliases.
	$recd_private = ( $uri_virtual !~ m|$alias| ? 1 : 0 );
	
	$uri_virtual = "/$uri_virtual" unless $uri_virtual =~ m|^/|;
	$uri_virtual =~ s|\?.*$|| if $q->env( 'uri_source_header' ) eq 'request_uri';
	
	$uri_app_root = '';
	
	for ( split( '/', $uri_virtual ) )
	{
		next unless $_;
		last unless -e "$docroot$uri_app_root/$_";
		$uri_app_root .= "/$_";
	}
	
	$uri_virtual =~ s|^$uri_app_root||;
	
# "uri:alias:virtual" means that the app alias is in the URI's virtual part ONLY.
# The default is to use a directory as the resource "mask" for the app, and the
# dir name serves as the public app alias, hence is not virtual.
	if ( ! $recd_private )
	{
		$virt_alias = ( $uri_app_root =~ m|$alias$| ? 0 : 1 );
		$uri_virtual = "/$alias" . $uri_virtual unless $q->env( 'uri:alias:virtual' );
	}
	else
	{
		$virt_alias = 0;
		$uri_virtual = '/' . ( $uri_app_root =~ m|(\w+)$| )[ 0 ] . $uri_virtual;
	}
	
# Set the path values to env.
	$q->env( 'uri:virtual' => $uri_virtual );
	$q->env( 'uri:alias:argv' => $alias );
	$q->env( 'uri:alias:received_private' => $recd_private );
	$q->env( 'uri:alias:public' => ( $uri_virtual =~ m|^/?(\w+)| )[ 0 ] );
	$q->env( 'uri:alias:private' => $recd_private ? $alias : ( $uri_virtual =~ m|^/?(\w+)| )[ 0 ] );
	$q->env( 'uri:alias:virtual' => $virt_alias );
	$q->env( 'uri:app_root' => $uri_app_root );
	
# Reporting URI OPERATIONS.
	$q->report( ":: uri operations ::\n" );
	$q->report( "request URI:             @{[ $q->env( 'uri:virtual' ) ]}" );
	$q->report( "received app alias:      $alias" );
	$q->report( "public app alias:        @{[ $q->env( 'uri:alias:public' ) ]}" );
	$q->report( "recd alias is private:   @{[ $recd_private ? 'yes' : 'no' ]}" );
	$q->report( "alias is virtual:        @{[ $virt_alias ? 'yes' : 'no' ]}" );
	$q->report( "application root:        $uri_app_root\n" );
	
	
# Determine action manager.
	#$q->report( ":: getting action manager ::\n" );
	$using_internal_get_action = 0;
	
# A.
# A.1
# The calling package submitted an action map or has an action map fetch routine.
	if ( $q->action_map || $q->app_package->can( 'get_action_map' ) )
	{
		#$q->report( 'Action map extant/caller provides loader, setting AM to main caller' );
		$am_package = $q->app_package;
		$am_origin = 'main caller';
		$am_route = '';
		$am_loaded = 1;
	}
# A.2
# The action map is in the app's config file.
	elsif ( $q->env( 'action_map' ) )
	{
		$am_package = $q->app_package;
		$am_origin = 'config file';
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
					next unless $q->env( 'uri:virtual' ) =~ m|$am_route|;
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
				$am_package = ( $q->_route_compare( $q->env( 'default_route' ), $q->env( 'uri:virtual' ) ) )[ 0 ];
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
				( $q->is_post_request || ! $q->env( 'allow_default_get_action' ) )
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
		
		if ( $q->env( 'action_map' ) )
		{
			$q->action_map( $q->env( 'action_map' ) );
		}
		else
		{
			my( $get_map_sub, $sub_defined );
			{
			 no strict 'refs';
			 $get_map_sub = \&{ $am_package . '::get_action_map' };
			 $sub_defined = defined( &{ $am_package . '::get_action_map' } );
			}
			
			$q->action_map( $get_map_sub->() ) if $sub_defined;
		}
	}
# B.2.vii
# If no Action Manager, and it's a GET request and default gets are allowed, set action
# map to default get.
	elsif ( ! $q->is_post_request && $q->env( 'allow_default_get_action' ) )
	{
		#$q->action_map( 'default_action' => 'get',
		#		'default_view' => 'index',
		#		'get' => { 'route' => '/:view' } );
		$q->action_map( $q->env( 'default_get_action_map' ) );
		$using_internal_get_action = 1;
	}
	
# Client resource request support.  The route setting is the only one needed.
# Set here, before following action map check.
	if ( $q->env( 'client_resource_action:enabled' ) )
	{
		$q->action_map( 'client_resource:route' => $q->env( 'client_resource_action:route' ) );
	}
	 
# Return fail value if action map is not found.
	unless ( %map = $q->action_map )
	{
		warn 'Failed to locate action map.';
		return 0;
	}
	
# Reporting AM/Map load.
	$q->report( ":: action manager/map load ::\n" );
	$q->report( "action manager loaded?   @{[ $am_loaded ? 'yes' : 'NO' ]}" );
	$q->report( "action manager:          @{[ $am_loaded ? $am_package : 'none' ]}" );
	$q->report( "action manager alias:    @{[ $q->env( 'action_manager:alias' ) || 'none' ]}" );
	$q->report( "action manager origin:   @{[ $am_origin || 'none' ]}" );
	$q->report( "action manager route:    @{[ $am_route || 'none' ]}" );
	$q->report( "action map exists?       @{[ $q->action_map ? 'yes' : 'no' ]}" );
	$q->report( "using default get map?   @{[ $using_internal_get_action ? 'yes' : 'no' ]}\n" );
	
	
# Identify Action.
	$i = 0;
	
	$q->report( ":: action identification ::\n" );
	$q->report( "request URI: $uri_virtual" );
	
# Note that if there is no "order" member in the checks, a meaningless order is substituted
# (prevents warning).  Not sure at this time (Feb 2012) if that's the right solution.
	@order = sort { ( $map{ $a }{ 'order' } || ++$i ) <=> ( $map{ $b }{ 'order' } || ++$i ) }
		grep { ref( $map{ $_ } ) eq 'HASH' } keys %map;
	
# Check URI against action map routes.	
	for $action ( @order )
	{
# NEXT THING HERE: @ROUTES ??
		$route = $map{ $action }{ 'route' };  # just to make next line readable
		$q->report( qq|Action:  \U$action| );
		
		for ( ref( $route ) eq 'ARRAY' ? @{ $route } : $route )
		{
			$q->report( " route:  $_" );
			
			if ( @compared = $q->_route_compare( $_, $uri_virtual ) )
			{
				$identified = $action;
				$route = $_;
			}
			
			last if $identified;
		}
		
		last if $identified;
	}
	
# If no route matched, check for default map action.
	if ( ! $identified && exists $map{ 'default_action' } )
	{
		$identified = $map{ 'default_action' };
	}
	
# Try grabbing action from URI if none found with action map.
	if ( ! $identified && ( $route = $q->env( 'default_route' ) ) )
	{
		$identified = $compared[ -1 ] if @compared = $q->_route_compare( $route, $uri_virtual );
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
	
	$q->report( ' ' );  # line break
	$q->report( "action route match:      @{[ $route || '' ]}" ) if $identified;
	$q->report( "action identified:       @{[ $identified || 'none' ]}" );
	
	return 1 if $identified;
	return 0;
	
}


sub _process_request_stage_load
{
	my( $q, @load_order, $component, $loaded );
	
	$q = shift();
	$loaded = 1;
	
	@load_order = $q->env( 'component_load_order' );
	$q->report( "Components to load: @load_order\n" );
	
	for $component ( @load_order )
	{
		next unless $loaded;
		$q->report( "Loading component: $component" );
		$loaded = $q->_load_component( $component );
		$q->report( "Load $component returned: @{[ $loaded ? 'ok' : 'FAIL' ]} ($loaded)\n" );
	}
	
	return 1 if $loaded;
	return 0;
}


sub _process_request_stage_action
{
	my( $q );
	my( $am_package, $am_loaded, $action_name );
	my( $stage_ok, $action_stage, $action_ok );
	my( $render_view, $view_source );
	
	$q = shift();
	
	$am_package = $q->env( 'action_manager:name' ) || '';
	$am_loaded = defined( $am_package ) ? 1 : 0;
	$action_name = $q->env( 'action:name' ) || '';
	
# Set component-accessible controller routines from env.
	$q->publish( $q->_flatten( $q->env( 'publish' ) ) ) unless $action_name eq 'client_resource';
	
# Set up controller accessor for Action Manager code.
# Note, this is done if the Action Manager is loaded, which means NOT for
# the internal default get action map.
# WARN  The following use $q, and might have problems in a mod_perl environment,
#	but the idea is that the wrapping "local" will cause the lexical reference to 
#	evaporate once the block is exited.
	no strict 'refs';
	no warnings 'redefine';
	
	local *{ $am_package . '::qoan' } = sub {
		local *__ANON__ = 'controller_access_closure_actionmanager';
		shift() if ref( $_[ 0 ] );
		return $q->_method( @_ ); } if $am_loaded;
	
	use warnings 'redefine';
	use strict 'refs';
	
# TEST of exported $am_package variables, must return values.
# NOTE  these tests are no good now, rewrite if using again.
	# if ( $am_loaded )
	# {
	#	&::controller_report( 'This is calling the controller functional ENV via MAIN.' );
	#	&::controller_report( " [from main] :: $_: $::request{ $_ }" ) for sort keys %::request;
	# }
	
	$action_ok = 1; #$q->ok;
	
# The action at last!
	for $action_stage ( $q->env( 'action_stages' ) )
	{
		$q->report( "Opening action stage: \U$action_stage\E  with status: $action_ok @{[ $action_ok ? '' : '(skipping)' ]}" );
		next unless $action_ok;
		
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
		$action_ok &&= $stage_ok;
		#$q->ok( $stage_ok );
		$q->report( qq|stage returned: @{[ $stage_ok ? 'ok' : 'FAIL' ]} ($stage_ok)\n| );
	}
	
# Action handling CHECK or EXECUTE might have set the view to render.
	if ( $render_view = $q->env( 'render_view' ) )
	{
		$q->env( 'view_source' => 'action_handling' );
	}
	
# If the action handling check and execute stages did not supply a view to render,
# run an Action Manager selection routine, if available.
# (Runs here because the handler code might need access to the Controller, which is
# set up above.)
	if ( ! $render_view && $am_loaded &&
		$am_package->can( 'select_view_to_render' ) &&
		( $render_view = $am_package->select_view_to_render ) )
	{
		$q->env( 'view_source' => 'action manager select routine' );
		$q->env( 'render_view' => $render_view );
	}
	
# TEST of exported $am_package variables after scope-end (must return NO VALUES).
	#$q->report( 'Request in am?' );
	#$q->report( " :: $_: $main::request{ $_ }" ) for sort keys %main::request;
	
	return 1 if $action_ok;
	return 0;
}


sub _process_request_stage_render
{
	my( $q );
	my( $render_view, $action_name, $view_source, $view_exists, %renderer_params );
	
	$q = shift();
	
	$q->report( ":: selecting view ::\n" );
	
	$render_view = $q->env( 'render_view' );
	$action_name = $q->env( 'action:name' ) || '';
	
# Special case for internal get??
# Ideally, the following if-block (as is) should handle this.
	#if ( ! $render_view && $using_internal_get_action )
	#{
	#	;
	#}
	
# Client Resource (internal).
	if ( $action_name eq 'client_resource' )
	{
		
		$render_view  = $q->env( 'client_resource_action:store' ) . ':';
		$render_view .= $q->env( 'uri:resource_type' ) . ':';
		$render_view .= $q->env( 'uri:resource_name' ) || $q->env( 'uri:alias:private' ); # . '.';
		
		$q->response( 'header:content-type' => 'image/jpeg' ) if $render_view =~ m|jpe?g$|;
		
		$view_source = 'client resource request';
	}
	
# From action section of action map (action name).
	if ( ! $render_view && $action_name )
	{
		$render_view = $q->action_map( $action_name . ':view' );
		$view_source = 'supplied by action' if $render_view;
	}
	
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
# one action map.
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
		@view_store = $q->env( 'component:view:store' );
		
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
	$q->report( "view source:             @{[ $q->env( 'view_source' ) || '' ]}" );
	$q->report( "starting view exists?    @{[ $view_exists ? 'yes' : 'no' ]}" );
	$q->report( "action map default view: @{[ $q->action_map( 'default_view' ) ]}\n" );
	$q->report( qq|view repositories:\n@{[ join( "\n", $q->env( 'view_store' ) ) ]}\n| );
	
	
# View rendering.
	$q->report( ":: rendering view ::\n" );
	
# Localize controller access alias for view component.
	no strict 'refs';
	no warnings 'redefine';
	
	local *{ 'Qoan::View' . '::qoan' } = sub {
		local *__ANON__ = 'controller_access_closure_view';
		shift() if ref( $_[ 0 ] );
		return $q->_method( @_ ); };
	
	use warnings 'redefine';
	use strict 'refs';
	
	
	if ( $render_view eq '[[DATA]]' )
	{
		$q->response( 'body' => $q->response( 'data' ) );
	}
	else  # rendering view from text
	{
		unless ( $view_exists )
		{
			$q->report( q|Rendering action map's default view in place of non-existent starting view.| );
			$render_view = $q->action_map( 'default_view' );
		}
		
		%renderer_params = $q->env( 'renderer_parameters' );
		$renderer_params{ 'view_start' } = $render_view;
		$renderer_params{ 'sources' } = [ $q->env( 'view_store' ) ];
		
		#my $rendered = $q->view_render( %renderer_params );
		#$rendered = Encode::encode( 'utf8', $rendered );
		#Encode::_utf8_on( $rendered );
		#$q->response( 'body' => $rendered );
		$q->response( 'body' => $q->view_render( %renderer_params ) );
		#}
		
		warn( 'Response is empty' ) unless $q->response( 'body' );
	}
	
	return 1 if $q->response( 'body' );
	return 0;
}


sub _process_request_stage_unload
{
	my( $q, @unload_order, $component, $unloaded, $unload_progress );
	
	$q = shift();
	$unload_progress = 1;
	
	@unload_order = $q->env( 'component_unload_order' ) ||
		reverse $q->env( 'component_load_order' );
	
	for $component ( @unload_order )
	{
		$q->report( "Unloading component: $component" );
		$unloaded = $q->_unload_component( $component );
		$q->report( "Unload $component returned: @{[ $unloaded ? 'ok' : 'FAIL' ]} ($unloaded)\n" );
		$unload_progress &&= ( $unloaded ? 1 : 0 );
	}
	
	return 1 if $unload_progress;
	return 0;
}


sub _process_request_stage_response
{
	my( $q );
	my( $return_debug, $debug_param, $debug_value, %renderer_params );
	
	$q = shift();
	
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
		$q->report( 'Checking whether to send debug report to client..' );
		
		$return_debug = 0;
# Preliminary check, for user permission.
		$return_debug = 1 if $q->env( 'session:permission:http_debug' );
		$return_debug = 1 if $q->env( 'http_debug:allow_public' );
		$q->report( "  user permitted:   @{[ $return_debug ? 'yes' : 'no' ]}" );
		
# If user is allowed, check request conditions:
# response body missing, or deliberately requested with correct URI parameter.
		if ( $return_debug )
		{
			$return_debug = 0;
			$return_debug = 1 if ! $q->response( 'body' );
			$q->report( "  no response body: @{[ $return_debug ? 'no body' : 'body rendered' ]}" );
			
			$debug_param = ( $q->env( 'http_debug:request_param' ) || '' );
			$debug_value = ( $q->env( 'http_debug:request_value' ) || '' );
			
			if ( $debug_param && $debug_value )
			{
				$return_debug = 1 if ( $q->env( "request:$debug_param" ) || "\0" ) eq $debug_value;
				$q->report( "  user requested:   @{[ $return_debug ? 'yes' : 'no' ]}" );
			}
		}
		
# Return debug report.
		if ( $return_debug )
		{
			$q->report( 'Rendering debug report for client.' );
			$q->env( 'returned_http_debug_report' => 1 );
			
			%renderer_params = $q->env( 'renderer_parameters' );
			$renderer_params{ 'view_start' } = $q->env( 'http_debug:view' );
			$renderer_params{ 'sources' }    = [ $q->env( 'view_store' ) ];
			$renderer_params{ 'run_report' } = $q->captured_output;
			$renderer_params{ 'errors' }     = [ $q->captured_errors ];
			$renderer_params{ 'env' }        = { $q->env };
			
#			no strict 'refs';
#			local *{ 'Qoan::View' . '::qoan' } = sub {
#				local *__ANON__ = 'controller_access_closure_view';
#				shift() if ref( $_[ 0 ] );
#				print "from debug: @_";
#				return $q->_method( @_ );
#			};
#			use strict 'refs';
			
			$q->response( 'body' => $q->view_render( %renderer_params ) );
			$q->response( 'header:content-type' => 'text/html' );
		}
	}
	
# Send response, unless caller has indicated it will do it.
# Note that following calls to report will not appear in HTTP debug response.
	if ( ! $q->env( 'delay_response' ) )
	{
		$q->report( 'Returning response.' );
		$q->env( 'response_sent' => $q->send_response );
	}
	else
	{
		$q->report( 'Response set to delay (application is expected to handle).' );
	}
	
	return 1 if $q->env( 'delay_response' );
	return 1 if $q->env( 'response_sent' );
	return 0;
}


sub _process_request_stage_cleanup
{
	return 1;
}


# Purpose:  Publish the name of a controller sub as accessible by 1+ components,
#           or fetch published list values.
# Context:  sub process_request or Qoan interface package only
# Receives: 1) controller ref
# Returns:  1) implicit undef for disallowed caller
#           2) external: result of call to main closure for publish list values
# External: a) calls main closure (3, executes once only)
#           b) checks allowed caller (2, once wo alerts)
#           c) calls sub component (fetches complete list)
#           d) calls warn (2)
#           e) writes published list to env
#
sub publish
{
	my( $q, $editable, $reading, %writing, $caller, %components, $component, %to_env );
	
	$q = shift();
	
	$editable = 0;
	$reading = '';
	
# If no parameters, return the entire publish list, flattened.
# External a)
	return $q->_flatten( $q->( ) ) unless @_;
	
# Return the requested value if only a single parameter (key value).
	$reading = shift() if @_ == 1;
# External a)
	return $q->( $reading ) if $reading;
	
# Writing to publish list.
# Only the app package, the request processing routine, or a Qoan interface module
# can write to the publish list.
# External b)
	return unless $q->_allowed_caller(
		#'eq' => [ 'Qoan::Controller::process_request' ],
		'eq' => [ 'Qoan::Controller::process_request', map { $_ . '::_process_request_stage_action' } $q->env( 'protected' ) ],
		'=~' => [ '^Qoan::Interface::\w+' ] );
	
	%writing = @_;
	$caller = ( caller( 1 ) )[ 3 ];
	
# Once set, publish list values can be changed:
#	by the request processing routine;
#	by the application package before processing starts.
	$editable = 1 if $caller eq 'Qoan::Controller::process_request';
# External b)
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
# External c)
		%components = $q->component;
		$component = '';
		
# Get component name.
		for ( keys %components )
		{
			next unless $components{ $_ }{ 'interface' };
			$component = $_ if $caller =~ m|^$components{ $_ }{ 'interface' }|;
			last if $component;
		}
		
# Remove any alias without the component name in it.
# If by some chance the calling interface is not being used by any component,
# every member of %writing should raise an error.
		for ( keys %writing )
		{
			next if $_ =~ m|$component|;
# External d)
			warn qq|Attempt to publish non-interface alias "$writing{ $_ }" as "$_" by $caller|;
			delete $writing{ $_ };
		}
	}
	
# Remove any keys to non-existant controller routines.
	for ( keys %writing )
	{
		next if $q->can( $writing{ $_ } );
# External d)
		warn qq|Attempt to publish non-existant controller routine "$writing{ $_ }" as "$_" by $caller|;
		delete $writing{ $_ };
	}
	
# Store values in functional env, for reference.
# NOTE  should this be stored with component settings ??
	$to_env{ "publish:$_" } = $writing{ $_ } for keys %writing;
# External e)
	$q->env( %to_env );
	
# External a)
	return $q->( %writing );
}


# Purpose:  return name of Qoan base configuration file.
#           Note, not a path, assumed to be in sibling dir.
# Context:  Public
#
sub qoan_base_config
{
	return $qoan_base_config;
}


# Purpose:  return name of controller package file's home directory.
# Context:  Public.
#
sub qoan_base_dir
{
	return $qoan_base_dir;
}


# Purpose:  return name of controller package file.
# Context:  Public.
#
sub qoan_base_file
{
	return $qoan_base_file;
}


# Purpose:  Fetch current request handling stage name, or
#           compare position of current stage with given stage.
# Context:  Public.
# Receives: 1) controller ref
#           2) check: position type, "current", "before", "after" (string)
#           3) stage name (string)
# Returns:  1) external: current stage name, if called wo params;
#           2) 1 or 0 literals, for check success/fail.
# External: a) fetches 'request_stage' from env
#           b) fetches 'request_stages' (list) from env
#
sub request_stage
{
	my( $q, $check, $stage, @stages, $current );
	
	$q = shift();
	$check = shift();
	$stage = shift();
	
# External a)
	$current = $q->env( 'request_stage' ) || '';
	return $current unless defined $check;
	
	if ( $check eq 'current' )
	{
		return 1 if $current eq $stage;
		return 0;
	}
	
# External b)
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


# Purpose:  Securely requires a module.
# Context:  Private but not enforced.
#           1) ?
# Receives: 1) controller ref
#           2) module name (string)
# Returns:  1 or 0 literals.
# External: Note, this sub runs before the logging component is set up.
#           a) calls warn (3)
#           b) requires named module
#
sub _require
{
	my( $q, $module, $calling_pkg, $msg, $ok );
	
# $q will be either a Qoan::Controller (or subclass) object, or package name.
# As this routine runs prior to the Controller object being fully set up, it does
# not rely on package reporting routines.
	$q = shift();
	$module = shift();
	$calling_pkg = ( caller( 0 ) )[ 0 ];
	
	unless ( $module && $q )
	{
		$msg = 'Module to load missing or package self-identification missing.';
# External a)
		#$q->can( 'warn' ) ? $q->warn( $msg ) : warn( $msg );
		warn $msg;
		return 0;
	}
	
# WARN  commenting out self-load check; shouldn't matter anyway.
	#if ( $module eq __PACKAGE__ )
	#{
	#	$msg = "Call to Require to load its own package from $calling_pkg";
# External a)
	#	#$q->warn( $msg ) if $q->can( 'warn' );
	#	$q->can( 'warn' ) ? $q->warn( $msg ) : warn( $msg );
	#	return 0;
	#}
	
# Regexes allow module barewords only.
	unless ( $module =~ m|^[\w:]+$| &&  # Verifies only allowed bareword chars.
		$module !~ m|^[\d:]| &&     # Verifies allowed starting char.
		$module !~ m|:$| &&         # Verifies allowed ending char.
		$module !~ m|::\d| )        # Verifies allowed starting char on each segment.
	{
		$msg = "Module name $module failed name check";
# External a)
		#$q->can( 'warn' ) ? $q->warn( $msg ) : warn( $msg );
		warn $msg;
		return 0;
	}
	
	local $@;
# External b)
	$ok = eval "require $module; 1;";
	
	if ( ! $ok )
	{
		$msg = "Error on @{[ ref $q ]} module $module require: $@";
		#$q->can( 'warn' ) ? $q->warn( $msg ) : warn( $msg );
# External a)
		warn $msg;
		return 0;
	}
	
	return 1 if $ok;
}


# RESPONSE only allows the response body and status to be set by the process request
# handler.  Any caller can set headers.
# Purpose:  Retrieve response value or write to response store.
# Context:  Public.  Published to AM by default.
#           Only sub process_request may write response body/status.
#           Any caller can set headers.
#           1) sub process_request
#           2) ?
# Receives: 1) controller ref
#           .) one or more values; reading if 1; writing if >1.
# Returns:  external: result of call to main closure for response values.
# External: a) checks allowed caller wo alerts
#           b) submit headers to env
#           c) calls main closure (3, only one executes)
#
sub response
{
	my( $q, $writing, $reading, $called_by_req_handler, %to_write, %headers, $header );
	
	$q = shift();
	$writing = ( @_ > 1 );
	$reading = ( @_ == 1 );
	
	if ( $writing )
	{
		%to_write = @_;
		
# External a)
		$called_by_req_handler = $q->_allowed_caller(
			#'eq' => [ 'Qoan::Controller::process_request' ], 'suppress_alerts' => 1 );
			'eq' => [ 'Qoan::Controller::process_request', ( map { $_ . '::_process_request_stage_render' } $q->env( 'protected' ) ),
				  ( map { $_ . '::_process_request_stage_response' } $q->env( 'protected' ) )
			],
			'suppress_alerts' => 1 );
		
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
		
# External b)
		$q->env( %headers ) if %headers;
		
# External c)
		return $q->( %to_write );
	}
	
# Return requested member or entire response if caller submitted no parameter.
# External c)
	return $q->( $_[ 0 ] ) if $reading;
# External c)
	return $q->( );
}


# Purpose:  compare URI to action route regex
# Context:  Private but not enforced.
#           1) sub process_request
#           2) sub _action_identify
# Receives: 1) controller ref
#           2) action route (string, regex)
#           3) URI path (string)
# Returns:  Array of matched URI path segments.
# External: None.  Calls to report commented out.
#
sub _route_compare
{
	my( $q, $route, $path, @route, $route_converted, @compared );
	
	$q = shift();
	$route = shift();
	$path = shift();
	
# Prefix action route with public app alias, which will be in the path.
	$route = $q->env( 'uri:alias:public' ) . $route;
	
	#$q->report( "Comparing path $path to route $route .." );
	
# Removing starting / is not necessary due to app alias prefix.
	#$route =~ s|^/||;
	@route = split( '/', $route );
	
# Symbol substitution in route.
	for ( @route )
	{
		$_ =~ s|^(?::\w+){1,}(\??)$|/$1(\\w+)$1|;
		$_ = "/$_" unless $_ =~ m|^/|;
	}
	
# Rejoin route segments, postfix with / if in original route.
	$route_converted = join( '', @route );
	$route_converted .= '/' if $route =~ m|/$|;
	
	#$q->report( "Route converted to $route_converted .." ) if $route ne $route_converted;
	
# Comparison and grabs sections named with symbols.
	@compared = ( $path =~ m|^$route_converted$| );
	
	return @compared;
}


# Purpose:  print response to STDOUT.
# Context:  1) sub process_request
#           2) app package (e.g. main)
# Receives: 1) controller ref
# Returns:  1) implicit undef for disallowed caller
#           2) 1 or 0 literals.
# External: a) checks allowed caller
#           b) fetches 'response_sent' from env
#           c) calls sub response
#           d) fetches 'send_response_status' from env
#           e) prints to STDOUT
#
sub send_response
{
	my( $q, %response, @headers, $header_name );
	
	$q = shift();
	
# External a)
	return unless $q->_allowed_caller(
		#'eq' => [ 'Qoan::Controller::process_request', $q->app_package ] );
		'eq' => [ 'Qoan::Controller::process_request', map { $_ . '::_process_request_stage_response' } $q->env( 'protected' ), $q->app_package ] );
	
# External b)
	unless ( $q->env( 'response_sent' ) )
	{
# External c)
# WHY THE FUCK DOES STAGED NEED THIS FLATTENED??
		#%response = $q->_flatten( $q->response );
		%response = $q->response;
# This line raised an error and it seems %headers is not being used.
# To correct code, wrap $response{ 'headers' } in %{ };
		#%headers = $response{ 'headers' } if $response{ 'headers' };
		
		$response{ 'status' } ||= "HTTP/1.0 200 OK";
# External d)
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
		
# Send response.
# External e)
		return 1 if print STDOUT $response{ 'status' },
			join( "\n", @headers ), "\n\n",
			$response{ 'body' };
	}
	
	return 0;
}


sub set_view
{
	my( $q, $view );
	
	$q = shift();
	$view = shift();
	
	$q->env( 'render_view' => $view );
	
	return 1 if $q->env( 'render_view' ) eq $view;
	return 0;
}


# Purpose:  Destroys component object.
# Context:  sub process_request only
# Receives: 1) controller ref
#           2) name of component (string)
# Returns:  1) implicit undef for disallowed caller
#           2) 1 or 0 literals.
# External: a) checks allowed caller
#           b) fetches component properties
#           c) calls component accessor (2), once to REMOVE
#           d) calls controller report (4)
#           e) calls component cleanup method
#
sub _unload_component
{
	my( $q, $component, %component, $cleanup, $accessor, $object );
	
	$q = shift();
	$component = lc( shift() );
	
# External a)
	#return unless $q->_allowed_caller( 'eq' => [ 'Qoan::Controller::process_request' ] );
	return unless $q->_allowed_caller( 'eq' => [ 'Qoan::Controller::process_request', map { $_ . '::_process_request_stage_unload' } $q->env( 'protected' ) ] );
	
# External b)
	%component = $q->env( "component:$component" );
	$accessor = $component{ 'accessor_alias' } || $component;
	
# If there's nothing to unload, then return success.
# External c)
	unless ( $q->can( $accessor ) && defined( $q->$accessor ) )
	{
# External d)
		$q->report( 'No object to unload.' );
		return 1;
	}
	
# Cleanup routine imported from interface.
	$cleanup = "_${component}_cleanup";
	
# External d)
	$q->report( 'Cleaning up for component..' );
# External e)
	return 0 unless $q->$cleanup;
	
# Destroy component.
# External d)
	$q->report( 'Destroying component..' );
# External c)
	$object = $q->$accessor( 'remove' );
# External d)
	$q->report( "@{[ $object ? 'FAILED.' : 'destroyed.' ]}" );
	
	return 1 unless $object;
	return 0;
}


1;
