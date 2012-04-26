
package Qoan::Interface::IView_QoanView;

# Qoan::Interface::DefaultView
# 
# This component interface is the default one for the View component,
# and assists the Qoan::View module.

use strict;
use Qoan::Interface ();
#use Qoan::View;

our $VERSION = '0.03';
our @ISA = qw| Qoan::Interface |;
our @EXPORT = qw| render |;

my $renderer;


sub accessor
{
	my( $controller ) = shift();
	
	$renderer = shift() if ref( $_[ 0 ] ) eq 'Qoan::View' && ! defined( $renderer );
	
	return $renderer unless @_;
	return $controller->component( @_ );
}


sub _before_new
{
	my( $controller ) = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	return 1;
}


sub render
{
	my( $controller, %params, $view, %renderer_vals );
	
	$controller = shift();
	%params = @_;  # view_start, sources
	
# Renderer should check this stuff too, but what the hell.
	unless ( $params{ 'view_start' } )
	{
		$controller->warn( 'No starting view received by call to render' );
		return;
	}
	
	unless ( ref( $params{ 'sources' } ) eq 'ARRAY' && $params{ 'sources' }->[ 0 ] )
	{
		$controller->warn( 'No view sources received by call to render' );
		return;
	}
	
# Render.
	#$view = Qoan::View::render_view( %params );
	#$view = $controller->view->render_view( %params );
	$view = $renderer->render_view( %params );
	
# Store renderer env values post-render to controller env.
	#%renderer_vals = $controller->view->env();
	#$renderer_vals{ "renderer:postrender:$_" } = delete $renderer_vals{ $_ } for keys %renderer_vals;
	#$controller->env( %renderer_vals );
	
	return $view;
}


1;

__DATA__


sub render_old
{
	my( $controller, %params, $view_module, $status, $headers, $body );
	
	$controller = shift();
	%params = @_;  # view_start, sources
	
# Only request handler proper can call this routine.
	return unless $controller->_allowed_caller( 'eq' => [ 'Qoan::RequestManager::process_request' ] );
	
	unless ( $params{ 'view_start' } )
	{
		$controller->warn( 'No starting view received' );
		return;
	}
	
	unless ( $params{ 'sources' }->[ 0 ] )
	{
		$controller->warn( 'No view sources received' );
		return;
	}
	
# Exporting reporting and env access routines to view component.
# Note that these can't be used inside the renderer package itself, but
# will be available for any eval'ed view code.
#	$view_module = $controller->$accessor( 'module' );
	$controller->report( "Aliasing subs to the view module: $view_module" );
	
	no strict 'refs';
	local *{ $view_module . '::controller_env' } = sub {  shift() if ref( $_[ 0 ] );  $controller->env( @_ );  };
	local *{ $view_module . '::controller_report' } = sub {  shift() if ref( $_[ 0 ] );  $controller->report( @_ );  };
	local *{ $view_module . '::controller_warn' } = sub {  shift() if ref( $_[ 0 ] );  $controller->warn( @_ );  };
	use strict 'refs';
	
# Render.
#	$body = $controller->$accessor->render_view( %params );
	#$body = Qoan::View->render_view( %params );
	
	return $body;
}
