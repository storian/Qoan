
package Qoan::RequestManager;

use strict;

our $VERSION = '0.01';


sub _prestart () { 0 }
sub _map_stage () { 1 }
sub _load_stage () { 2 }
sub _action_stage () { 3 }
sub _render_stage () { 4 }
sub _unload_stage () { 5 }
sub _respond_stage () { 6 }
sub _cleanup_stage () { 7 }
sub _finished () { 8 }


###
#
#	CONSTRUCTOR AND REQUEST HANDLER
#
###

#sub new ($;@)
#{
#	my( $class, %load_cfg, %env, %component, %action_map, %response, $q, $k, $v );
#	
#	$class = shift();
#	
#	return unless $class->_allowed_caller(
#		'eq' => [ 'Qoan::RequestManager::process_request', $class->app_package ], '!~' => [ 'Qoan::' ] );
#	
## Load default/main config file values, and any submitted config references/values.
## NOTE  that the loading of config-file-source values OVERWRITE previous loads at
##       the lowest hash level.
## UNTAINT
#	for ( $class->qoan_base_config, $class->app_config, 'controller_start', @_ )
#	{
#		%load_cfg = ref( $_ ) eq 'HASH' ? %{ $_ } : Qoan::Controller->retrieve_config( $_ );
#		$env{ lc( $_ ) } = $load_cfg{ $_ } for keys %load_cfg;  # <- OVERWRITING
#	}
#	
#	$env{ 'qoan_base_config' } = $class->qoan_base_config;
#	
## Add system environment.
## UNTAINT
#	$env{ 'sys_env' }{ lc( $_ ) } = $ENV{ $_ } for keys %ENV;
#	
## Defaults for action stages and protected packages.
## UNTAINT ?
#	$env{ 'action_stages' } ||= [ qw| identify  check  execute  cleanup | ];
#	$env{ 'protected' } ||= [ __PACKAGE__ , $class ne __PACKAGE__ ? $class : ( ) ];
#	
## Component set-up.
## NOTE the session store setting uses the TMP_DIR setting.
#	$env{ 'component_load_order' } ||= [ qw| request  session  user | ];
#	
#	#for ( $env{ 'component' } )
#	for ( @{ $env{ 'component_load_order' } } )
#	{
#		$env{ 'component' }->{ 'request' } ||= { 'module' => 'CGI::Minimal',
#							 'interface' => 'Qoan::Interface::IRequest_CGIMinimal' }
#			if $_ eq 'request';
#		$env{ 'component' }->{ 'session' } ||= { 'module' => 'Qoan::Model::Minicache',
#							 'interface' => 'Qoan::Interface::ISession_QoanModelMinicache',
#							 'store' => $env{ 'directory:tmp' } . 'sessions/' }
#			if $_ eq 'session';
#		$env{ 'component' }->{ 'user' }    ||= { 'module' => 'Qoan::Model::Minicache',
#							 'interface' => 'Qoan::Interface::IUser_QoanModelMinicache',
#							 'store' => 'users/' }
#			if $_ eq 'user';
#	}
#	
#	$env{ 'qoan_view_store' } ||= 'views/';
#	
#	$env{ 'uri_source_header' } ||= 'request_uri';
#	
## Routines to publish to external context (e.g. view renderer).
## Note this does not remove anything already put into the variable.
#	for ( $env{ 'publish_context' }->{ 'all' } )
#	{
#		$_->{ 'controller_env' }    = 'env';
#		$_->{ 'controller_report' } = 'report';
#		$_->{ 'controller_warn' }   = 'warn';
#	}
#	
## Accessors and component list are closure/request management tools.
#	push( @{ $env{ 'closure_accessors' } }, map { "Qoan::RequestManager::$_" } qw| action_map  component  env  errors  ok  response | );
#	
## Set action manager type if it is set in config.
#	$env{ 'action_manager' }->{ 'type' } = 'static_config' if $env{ 'action_manager' }->{ 'name' };
#	
## Define default functional environment value, if config file did not provide.
#	$env{ 'sessionid_variable' } = 'qoan_session' unless exists $env{ 'sessionid_variable' };
#	$env{ 'userid_variable' } = 'qoan_user' unless exists $env{ 'userid_variable' };
#	#$env{ 'default_route' } = '^/?:action_manager/:action' unless exists $env{ 'default_route' };
#	
## "Internal" env values, for the handler.
## Explicitly set here to prevent being set by config importation.
#	$env{ 'request_stage' }    = _prestart();
#	$env{ 'ok' }               = 1;
#	#$env{ 'errs' }             = [ ];
#	
#	
## BEGIN MAIN CLOSURE.
## Receives an index to the member array and an optional write parameter.		
## The closure is to be called only by the member accessors.
#	$q = sub {
#		local *__ANON__ = 'main_closure_' . time();
#		my( $caller1, $store, %params, $k, $v, @keypath, $index, $loc, $i );
#		
#		return unless $q->_allowed_caller( 'eq' => $env{ 'closure_accessors' } );
#		
#		$caller1 = ( caller( 1 ) )[ 3 ];
#		
#		$store =
#			$caller1 eq 'Qoan::RequestManager::env' ? \%env :
#			#$caller1 eq 'Qoan::RequestManager::errs' ? \%env :
#			$caller1 eq 'Qoan::RequestManager::ok' ? \%env :
#			#$caller1 =~ m|accessor$| ? \%env :
#			$caller1 eq 'Qoan::RequestManager::response' ? \%response :
#			$caller1 eq 'Qoan::RequestManager::component' ? \%component :
#			$caller1 eq 'Qoan::RequestManager::action_map' ? \%action_map : undef;
#		
#		return unless defined $store;
#		return %{ $store } unless @_;
#		
## This block is only for removal of components.
#		if ( $caller1 eq 'Qoan::RequestManager::component' && $_[ 1 ] && $_[ 1 ] eq 'remove' )
#		{
#			( $k, $v ) = @_;
#			$store->{ $k } = undef;
#			return $store->{ $k };
#		}
#		
## Main closure receives either a set of key-value pairs, to update a hash,
## or a single hash key, to read; hence the unusual stepping used here.
#		for ( $i = 0; $i < @_; $i += 2 )
#		{
#			( $k, $v ) = @_[ $i, $i + 1 ];
#			
## Compound index processing.
#			@keypath = split( ':', $k );
#			$index = pop( @keypath );
#			$loc = $store;
#			for ( @keypath )
#			{
#				#$loc->{ $_ } = { } if $v && ! defined $loc->{ $_ };
#				$loc->{ $_ } = { } unless defined $loc->{ $_ };
#				$loc = $loc->{ $_ };
#			}
#			
## Update if value submitted with key.
#			if ( $v )
#			{
#				if ( $index eq 'ok' && $caller1 eq 'Qoan::RequestManager::ok' )
#				{
#					$loc->{ $index } &&= $v;
#				}
#				elsif ( ref( $loc->{ $index } ) eq 'ARRAY' && ! ref $v )
#				{
#					push( @{ $loc->{ $index } }, $v );
#				}
#				else
#				{
#					$loc->{ $index } = $v;
#				}
#			}
#		}
#		
## Return last index's value.
#		return %{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'HASH';
#		return @{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'ARRAY';
#		return $loc->{ $index } if exists ${ $loc }{ $index };
## Return zero-len string if non-existent value requested (stops "uninitialized" warnings).
## NOTE, not using this currently.
#		#return '' if $index;
## Probably not useful, so, for sanity's sake.
#		return;
#		
#		};
## END MAIN CLOSURE
#	
#	bless( $q, $class );
#	
## Add any parameters submitted on application's Qoan::Controller use statement.
#	#$q->env( $q->controller_params );
#	
#	return $q;
#}

# map  load  action  render  unload  response  cleanup  finished

sub _request_map
{
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

}


sub _request_load
{
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

}


sub _request_action
{
# II. Execute action
	#$q->env( 'request_stage' => _action_stage() );
	$q->env( 'request_stage' => 'action' );
	
	$q->report( ":: ACTION STAGE ::\n" );
	
# II.b  Execute action
	#$q->report( ":: executing action ::\n" );
	
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
	 #local *{ $am_package . '::request' } = \%{ { $q->env( 'request' ) } } if $am_loaded;
	 #local *{ $am_package . '::session' } = \%{ { $q->env( 'session' ) } } if $am_loaded;
	 #local *{ $am_package . '::user' } = \%{ { $q->env( 'user' ) } } if $am_loaded;
	 #local *{ $am_package . '::controller_env' } = sub {  $q->env( @_ );  } if $am_loaded;
	 #local *{ $am_package . '::controller_report' } = sub {  $q->report( @_ );  } if $am_loaded;
	 #local *{ $am_package . '::controller_warn' } = sub {  $q->warn( @_ );  } if $am_loaded;
	 no warnings 'redefine';
	 local *{ $am_package . '::controller' } = sub { shift() if ref( $_[ 0 ] ); return $q->_method( @_ ); } if $am_loaded;
	 use warnings 'redefine';
	 use strict 'refs';
	 
# Test of exported $am_package variables, must return values.
	# if ( $am_loaded )
	# {
	#	&::controller_report( 'This is calling the request manager ENV via MAIN.' );
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


sub _request_render
{
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
	if ( ! $render_view )
	{
		$render_view = $q->action_map( 'default_view' );
		$view_source = 'action manager default' if $render_view;
	}
	
# Request Manager/Application default.
	if ( ! $render_view )
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
	
# WARN  "view_render" will break if we change the component name to not-"view".
#	As of March '12 changing the name of "servers" (of which the renderer is one)
#	is not permitted.  Changing contextual components' names is allowed.
	unless ( $view_exists )
	{
		$q->report( q|Rendering action map's default view in place of non-existent starting view.| );
		$render_view = $q->action_map( 'default_view' );
	}
	
	%renderer_params = $q->env( 'renderer_parameters' );
	$renderer_params{ 'view_start' } = $render_view;
	$renderer_params{ 'sources' } = [ $q->env( 'view_store' ) ];
	
	#{
	 no strict 'refs';
	 local *{ 'Qoan::View' . '::qoan' } = sub { shift() if ref( $_[ 0 ] ); return $q->_method( @_ ); };
	 use strict 'refs';
	 
	 $q->response( 'body' => $q->view_render( %renderer_params ) );
	#}
	
	warn( 'Response is empty' ) unless $q->response( 'body' );
	
	$q->report( "\n:: end render stage ::\n" );

}


sub _request_unload
{
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

}


sub _request_response
{
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
# WARN  "request:", this won't work if request component's name is changed.
		$debug_param = 'request:' . $q->env( 'http_debug:request_param' );
		$debug_value = $q->env( 'http_debug:request_value' );
		
		$q->report( 'Checking whether to send debug report to client..' );
		$return_debug = 0;
# WARN  "session:permission", this won't work if the session component's name is changed.
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

}


sub _request_cleanup
{

}


#sub _request_finished
#{
#
#}


# method PROCESS_REQUEST  (public, object/class)
# purpose:
#	Handles request.
# usage:
#	Self or package name, optional configuration values.

sub process_request_new
{
	my( $q, $stage, $handler, $stage_result );
#	return undef unless &_allowed_caller( &_MAIN );
	
#	my( $c, $warn_h, $die_h, @stages, $name, $stage, $out_saved, $err_saved );
	
	$q = shift;
	
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
	
# ***
	
# For each stage:
#  = push an anonymous array onto the stages ref for the new stage;
#  = set the current stage;
#  = set the output variable to refer to the stage's _REPT element;
#  = check the previous stage's OK value, and if true:
#  = execute the stage handler;
#  = store the code execution's return value in the stage _RTND element;
#  = pass the stage's return value to the controller OK value.
#
# If a stage fails, OK is set to false, and the following stages will not be executed. 
#	$q->report(
#		"\n\nHANDLING REQUEST\n" );
	
	for $stage ( $q->env( 'request_stages' ) )
	{
		$q->report( "Starting stage: \U$stage\E  with status: @{[ $q->ok ]}" );
		
		$handler = "_request_$stage";
		next unless $q->ok;
		$q->ok( $stage_result = $q->$handler );
		
		$q->report( "stage returned: $stage_result\n[end of stage]\n" );
	}
	
# Store stages to stages member.
#	$c->stages( bless( \@stages, 'Qafe::Stages' ) );
	
# END STUFF FOR REQ HANDLIGN HERE
# Flag object as handled.  This makes object completely read-only.
#	$c->env( { 'request_handled' => 1 } );
#	$q->env( 'request_stage' => 'finished' );
	
#	return $q->ok;
# ***
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
	 #local *{ $am_package . '::request' } = \%{ { $q->env( 'request' ) } } if $am_loaded;
	 #local *{ $am_package . '::session' } = \%{ { $q->env( 'session' ) } } if $am_loaded;
	 #local *{ $am_package . '::user' } = \%{ { $q->env( 'user' ) } } if $am_loaded;
	 #local *{ $am_package . '::controller_env' } = sub {  $q->env( @_ );  } if $am_loaded;
	 #local *{ $am_package . '::controller_report' } = sub {  $q->report( @_ );  } if $am_loaded;
	 #local *{ $am_package . '::controller_warn' } = sub {  $q->warn( @_ );  } if $am_loaded;
	 no warnings 'redefine';
	 local *{ $am_package . '::controller' } = sub { shift() if ref( $_[ 0 ] ); return $q->_method( @_ ); } if $am_loaded;
	 use warnings 'redefine';
	 use strict 'refs';
	 
# Test of exported $am_package variables, must return values.
	# if ( $am_loaded )
	# {
	#	&::controller_report( 'This is calling the request manager ENV via MAIN.' );
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
	if ( ! $render_view )
	{
		$render_view = $q->action_map( 'default_view' );
		$view_source = 'action manager default' if $render_view;
	}
	
# Request Manager/Application default.
	if ( ! $render_view )
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
	
# WARN  "view_render" will break if we change the component name to not-"view".
#	As of March '12 changing the name of "servers" (of which the renderer is one)
#	is not permitted.  Changing contextual components' names is allowed.
	unless ( $view_exists )
	{
		$q->report( q|Rendering action map's default view in place of non-existent starting view.| );
		$render_view = $q->action_map( 'default_view' );
	}
	
	%renderer_params = $q->env( 'renderer_parameters' );
	$renderer_params{ 'view_start' } = $render_view;
	$renderer_params{ 'sources' } = [ $q->env( 'view_store' ) ];
	
	#{
	 no strict 'refs';
	 local *{ 'Qoan::View' . '::qoan' } = sub { shift() if ref( $_[ 0 ] ); return $q->_method( @_ ); };
	 use strict 'refs';
	 
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
# WARN  "request:", this won't work if request component's name is changed.
		$debug_param = 'request:' . $q->env( 'http_debug:request_param' );
		$debug_value = $q->env( 'http_debug:request_value' );
		
		$q->report( 'Checking whether to send debug report to client..' );
		$return_debug = 0;
# WARN  "session:permission", this won't work if the session component's name is changed.
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


###
#
#	OTHER ROUTINES
#
###


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
			
			#for ( @routes )
			for ( ref( $route ) eq 'ARRAY' ? @{ $route } : $route )
			{
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


## method ACTION_MAP
#
#sub action_map ($;@)
#{
#	my( $q, %map, $map_mutable, $flatten, $caller );
#	
#	$q = shift();
#	$map_mutable = 0;
#	$flatten = 0;
#	
## Reading a value.
#	return $q->( $_[ 0 ] ) if @_ == 1;
#	
#	#$caller = caller( 1 ) ? ( caller( 1 ) )[ 3 ] : ( caller( 0 ) )[ 0 ];
#	$caller = ( caller( 1 ) )[ 3 ] || ( caller( 0 ) )[ 0 ];
#	
## Map can be changed before processing start by the package evoker, or by the
## processing routine proper.
#	$map_mutable = 1 if $caller eq 'Qoan::RequestManager::process_request' ||
#		( $q->env( 'request_stage' ) == _prestart() &&
#		$q->_allowed_caller( 'eq' => [ $q->app_package ], 'suppress_alerts' => 1 ) );
#	%map = @_ if $map_mutable;
#	
## Call to Main Closure.
#	$q->( %map );
#	%map = $q->( );
#	
## Flatten map if we've exited the prestart stage (processing has started)
## and caller is unprotected.
#	$flatten = 1 if $q->env( 'request_stage' ) != _prestart() &&
#		$q->_allowed_caller( '!~' => [ $q->env( 'protected' ) ], 'suppress_alerts' => 1 );
#	
#	%map = $q->_flatten( %map ) if $flatten;
#	
#	return %map;
#}


## method COMPONENT (public, object)
## purpose:
##	Custom ENV accessor, for component settings only.
## usage:
##	Self.
##	Optional hash key(s) (for component value from %env) or submitted component
##	object (to be added to %component).
#
## loading object: called by accessor, & parameter is non-hash/array REF.
## fetching object: called by accessor, no params.
## unloading object: called by accessor with 'REMOVE' parameter
## data from object: called by accessor with 'DATA' parameter
## settings for component: called by accessor with 'SETTINGS' parameter
## called by non-object-accessor: returns env component settings - requires IDing the object e.g. "request" parameter
## NO - not useful because it requires id'ing the object. called by non-object_accessor with 'DATA' parameter: returns object values from env
#
#sub component ($;@)
#{
#	my( $q, @params );
#	my( $writing, $reading, $caller );
#	my( %component_list, $name, $settings );
#	my( $load_obj, $unload_obj, $get_obj, $data_call, $settings_call );
#	
#	$q = shift();
#	
## Note, $writing and $reading are used with settings and data only.
#	@params = @_;
#	$writing = ( @params > 1 );
#	$reading = ( @params == 1 );
#	
#	$params[ 0 ] ||= '';
#		
#	$caller = ( caller( 1 ) )[ 3 ];
#	
#	#if ( ref( $param ) eq 'HASH' || ref( $param ) eq 'ARRAY' )
#	#{
#	#	$q->warn( "$caller called component routine with disallowed parameter @{[ ref $param ]}" );
#	#	return;
#	#}
#	
#	if ( $caller =~ m|::accessor$| )
#	{
#		%component_list = $q->env( 'component' );
#		
#		while ( ( $name, $settings ) = each %component_list )
#		#while ( ( $name, $settings ) = each %{ $q->env( 'component' ) } )
#		{
#			last if $caller =~ m|^${ $settings }{ 'interface' }|;
#		}
#		
## Component can interact with the component objects, the stored component settings,
## or data loaded from the component to the functional env.
## For the latter two, component changes the parameter to refer to the appropriate
## section of %env, which allows access to specific values in those sections.
#		
#		$load_obj = $unload_obj = $get_obj = $data_call = $settings_call = 0;
#		
## Note that unloading can only happen during the unload stage; but loading
## is not restricted to a stage, because we might need to create a component
## during the request.
#		$load_obj = 1 if ref( $params[ 0 ] ) eq $settings->{ 'module' } &&
#			! defined( $q->( $name ) );
## Note, following is for when main closure returns '' (instead of nothing)
## on request for non-existent member.
#			#! $q->( $name );
#		$unload_obj = 1 if $params[ 0 ] eq 'remove' &&
#			$q->env( 'request_stage' ) == _unload_stage();
#		$get_obj = 1 if ! $params[ 0 ];
#		
## Component object related.
#		if ( $load_obj || $unload_obj || $get_obj )
#		{
#			return $get_obj
#				? $q->( $name )
#				: $q->( $name => $params[ 0 ] );
#		}
#		
#		$data_call = 1 if $params[ 0 ] =~ m|^data\b|i;
#		$settings_call = 1 if $params[ 0 ] =~ m|^settings\b|i;
#		
#		if ( $reading )
#		{
#			$data_call = ( $params[ 0 ] =~ s|^data|$name|i );
#			$settings_call = ( $params[ 0 ] =~ s|^settings|component:$name|i );
#			
#			if ( $data_call || $settings_call )
#			{
#				return $q->env( $params[ 0 ] );
#			}
#			else
#			{
#				return $q->env( "component:$name:$params[ 0 ]" ) ||
#					$q->env( "$name:$params[ 0 ]" );
#			}
#		}
#		elsif ( $writing )
#		{
#			my( $i );
#			
#			for ( $i = 0; $i < @params; $i += 2 )
#			{
#				$data_call = ( $params[ $i ] =~ s|^data|$name|i );
#				$settings_call = ( $params[ $i ] =~ s|^settings|component:$name|i );
#				$params[ $i ] = "$name:$params[ $i ]" unless $data_call || $settings_call;
#			}
#			
#			return $q->env( @params );
#		}
#		
#		$q->warn( "Component routine unable to fulfill request from $caller" );
#	}
#	else
#	{
#		return $q->env( "component:$params[ 0 ]" );
#	}
#}


## method ENV  (public, object)
## purpose:
##	Access to object's functional environment.
##	The functional env is read-write before request processing begins; then
##	stored values become read-only.  New values may be added (and are read-only).
## usage:
##	Self.
##	Optionally: a value key;
##	  or list of hash refs of env settings and config file names to load.
#
#sub env ($;@)
#{
#	my( $q, $editable, $reading, $cfg_load, $caller, %writing );
#	
#	$q = shift();
#	$editable = 0;
#	$reading = '';
#	$cfg_load = '';
#		
#	$caller = ( caller( 1 ) )[ 3 ];
#	
## If no parameters, return the entire functional env, flattened.
#	return $q->_flatten( $q->( ) ) unless @_;
#	
#	$cfg_load = shift() if ref( $_[ 0 ] ) eq 'ARRAY';
#	$reading = shift() if @_ == 1;
#	%writing = @_;
#	
## Values in env can be changed before processing starts, or by the processing routine.
#	$editable = 1 if $q->( 'request_stage' ) == _prestart() ||
#		$caller eq 'Qoan::RequestManager::process_request';
#	
## Caller can pass a list of config file names and hash refs containing env key-value
## pairs in an array ref.  It must be the first parameter.
## This kind of mass-update is only allowed if env is "editable" (even if all the values are new).
#	if ( $cfg_load )
#	{
#		return unless $editable;
#		
#		for ( @{ $cfg_load } )
#		{
#			$q->( Qoan::Controller->retrieve_config( $_ ) ) if ! ref $_;
#			$q->( %{ $_ } ) if ref( $_ ) eq 'HASH';
#		}
#		
#		return 1;  # ??? return value after config load??
#	}
#	
## Only a single key parameter submitted, return the value.
#	return $q->( $reading ) if $reading;
#	
## Remove keys with defined values if env is not editable.
#	unless( $editable )
#	{
#		for ( keys %writing )
#		{
#			delete $writing{ $_ } if defined $q->( $_ );
## Note, following is used when main closure returns '' (instead of nothing)
## on request for non-existent member.
#			#delete $writing{ $_ } if $q->( $_ );
#		}
#	}
#	
#	return $q->( %writing );
#}


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


sub _route_compare ($$)
{
	my( $q, $route, $path, @route, $route_converted, @compared );
	
	$q = shift();
	$route = shift();
	$path = shift();
	
	$q->report( "Comparing path $path to route $route .." );
	
	$route =~ s|^/||;
	@route = split( '/', $route );
	
	for ( @route )
	{
		$_ =~ s|^(?::\w+){1,}(\??)$|/$1(\\w+)$1|;
		$_ = "/$_" unless $_ =~ m|^/|;
	}
	
	$route_converted = join( '', @route );
	
	$q->report( "Route converted to $route_converted .." ) if $route ne $route_converted;
	
	@compared = ( $path =~ m|^$route_converted$| );
	
	return @compared;
}


sub send_response
{
	my( $q, %response, %headers, @headers, $header_name );
	
	$q = shift();
	
	return unless $q->_allowed_caller(
		'eq' => [ 'Qoan::RequestManager::process_request', $q->app_package ] );
	
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


1;
