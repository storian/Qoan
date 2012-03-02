
package Qoan::Interface::DefaultView;

# Qoan::Interface::DefaultView
# 
# This component interface is the default one for the View component,
# and assists the Qoan::View module.

use strict;
use Qoan::Interface ();

use Qoan::View;

our $VERSION = '0.03';
our @ISA = qw| Qoan::Interface |;
our @EXPORT = qw| render |;


sub render
{
	my( $controller, %params, @publish_context );
	
	$controller = shift();
	%params = @_;  # view_start, sources
	
# Renderer should check this stuff too, but what the hell.
	unless ( $params{ 'view_start' } )
	{
		$controller->warn( 'No starting view received by call to render' );
		return;
	}
	
	unless ( $params{ 'sources' }->[ 0 ] )
	{
		$controller->warn( 'No view sources received by call to render' );
		return;
	}
	
# Exporting reporting and env access routines to view component.
# Note that these can't be used inside the renderer package itself, but
# will be available for any eval'ed view code.
	$controller->report( 'Aliasing controller access subs to Qoan::View..' );
	
# NOTE  this only checks the SERVER setting in the env.
#  Should the interface be flexible enough to accept the view as a contextual component?
	@publish_context = $controller->env( 'server:view:publish' );
	
# The unsightly shift is necessary for calls of the form $renderer->routine.
# None of these routines should receive refs as parameters.
	#local *Qoan::View::controller_env =    sub {  shift() if ref( $_[ 0 ] );  $controller->env( @_ );  };
	#local *Qoan::View::controller_report = sub {  shift() if ref( $_[ 0 ] );  $controller->report( @_ );  };
	#local *Qoan::View::controller_warn =   sub {  shift() if ref( $_[ 0 ] );  $controller->warn( @_ );  };
	
	no strict 'refs';
	local *{ 'Qoan::View::controller_' . $_ } = sub {  shift() if ref( $_[ 0 ] );  $controller->$_( @_ );  }
		for @publish_context;
	use strict 'refs';
	
	
# Render.
	return Qoan::View::render_view( %params );
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
