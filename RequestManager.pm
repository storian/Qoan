
package Qoan::RequestManager;

use strict;

our $VERSION = '0.01';


#sub _prestart () { 0 }
#sub _map_stage () { 1 }
#sub _load_stage () { 2 }
#sub _action_stage () { 3 }
#sub _render_stage () { 4 }
#sub _unload_stage () { 5 }
#sub _respond_stage () { 6 }
#sub _cleanup_stage () { 7 }
#sub _finished () { 8 }



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
