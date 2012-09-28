
package Qoan::Interface::IConfig_YAMLTiny;

# Configuration file access through limited YAML.
#

use strict;

our $VERSION = '0.01';

use Qoan::Interface ();

our @ISA = qw| Qoan::Interface |;
our @EXPORT = qw| load  retrieve  loaded  search |;


my( $cfg_handler );
my( $default_cfg_dir, %files );

( $default_cfg_dir = ( caller( 1 ) )[ 1 ] ) =~ s|[^/]+$||;
$default_cfg_dir .= 'configs/';


sub accessor
{
	my( $controller ) = shift();
	
	$cfg_handler = shift() if ref( $_[ 0 ] ) eq 'YAML::Tiny' && ! defined( $cfg_handler );
	
	return $cfg_handler unless @_;
	return $controller->component( @_ );
}


sub _before_new
{
	my( $controller ) = shift();
	
	return undef unless $controller->_allowed_caller( 'eq' => [ 'Qoan::Controller::_load_component' ] );
	return 1;
}


# Sub load returns a true or false value depending on
# whether the file to load exists/successfully loads.
sub load
{
	my( $controller );
	
	$controller = shift();
	
# WARN  This package-name check is likely not sufficient.
	#shift if ref( $_[ 0 ] ) || $_[ 0 ] =~ m|::|;
	
	my( $path, $file_name, $settings, $load_error );
	$path = $file_name = '';
	
# $file_name might be an absolute path.  If it is just a file name,
# include the default config path in the Minicache call.
	$file_name = shift();
	
# Skip loading file if caller submitted a hash ref of config values.
	unless ( $settings = shift() )
	{
		$path = $default_cfg_dir unless $file_name =~ m|/|;
		$cfg_handler->read( $path . $file_name );
		$load_error = $cfg_handler->errstr;
		print STDERR 'error: ' . $load_error . "\n" if $load_error;
		$settings = $cfg_handler->read( $path . $file_name )->[ 0 ];
	}
	
# Note, can't overwrite previously loaded sets.
	$files{ $file_name } = $settings
		if ref( $settings ) eq 'HASH' && ! exists $files{ $file_name };
	
	return 1 if exists $files{ $file_name };
	return 0;
}


# Note that if the file was requested with a path and not merely a file name,
# the retrieve call must supply the same path.  If the load call received only
# a file name, and found the config file in the default dir, the retrieve call
# needs only the file name.
sub retrieve
{
# WARN  This package-name check is likely not sufficient.
	#shift if ref( $_[ 0 ] ) || $_[ 0 ] =~ m|::|;
	my( $controller, $file_name, $setting_name );
	
	$controller = shift();
	$file_name = shift();
	$setting_name = shift() || '';
	
	return undef unless $file_name =~ m|^[\.\w/]+$|;
	
	load( $controller, $file_name ) if ! exists $files{ $file_name };
	
	return $files{ $file_name }->{ $setting_name } if $setting_name;
	return %{ $files{ $file_name } } if $file_name && ref( $files{ $file_name } ) eq 'HASH';
	return;
}


sub loaded
{
	return keys %files;
}


sub search
{
# WARN  This package-name check is likely not sufficient.
	#shift if ref( $_[ 0 ] ) || $_[ 0 ] =~ m|::|;
	my( $controller, $setting_name, %found );
	
	$controller = shift();
	$setting_name = shift();
	
	$found{ $_ } = retrieve( $controller, $_, $setting_name ) for keys %files;
	
	return %found;
}


1;
