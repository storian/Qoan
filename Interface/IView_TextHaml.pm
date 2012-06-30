
package Qoan::Interface::IView_TextHaml;

# Qoan::Interface::IView_TextHaml
# 
# This component interface is the default one for the View component,
# and assists the Text::Haml module.

use strict;
use Qoan::Interface ();


our $VERSION = '0.03';
our @ISA = qw| Qoan::Interface |;
our @EXPORT = qw| render |;

my $renderer;


sub accessor
{
	my( $controller ) = shift();
	
	$renderer = shift() if ref( $_[ 0 ] ) eq 'Text::Haml' && ! defined( $renderer );
	
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
	my( $controller, %params, $view );
	
	$controller = shift();
	#$view = shift();
	%params = @_;  # view_start, sources
	$controller->report( join( ' ', 'view parameters: ', %params ) );
	
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
	if ( $view =~ m|\.haml$| )
	{
		$controller->report( "Render file" );
		$view = $renderer->render_file( $view );
	}
	else
	{
		$controller->report( "Render string" );
		$view = $renderer->render( $view );
	}
	
	return $view;
}


1;
