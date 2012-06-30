
package Qoan::Interface::IConfig_YAMLTiny;

# Configuration file access through limited YAML.
#

use strict;

our $VERSION = '0.01';


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


# Sub load_config returns a true or false value depending on
# whether the file to load exists/successfully loads.
sub load_config
{
	my( $controller );
	
	$controller = shift();
	
# WARN  This package-name check is likely not sufficient.
	#shift if ref( $_[ 0 ] ) || $_[ 0 ] =~ m|::|;
	
	my( $path, $file_name, $settings );
	
# $file_name might be an absolute path.  If it is just a file name,
# include the default config path in the Minicache call.
	$file_name = shift();
	
# Skip using Minicache if caller submitted a hash ref of config values.
	unless ( $settings = shift() )
	{
		$path = [ $default_cfg_dir ] unless $file_name =~ m|/|;
		$settings = { Qoan::Model::Minicache->new( 'source' => $file_name, 'paths' => $path )->get };
	}
	
# Note, can't overwrite previously loaded sets.
	$files{ $file_name } = $settings if %{ $settings } && ! exists $files{ $file_name };
	
	return 1 if exists $files{ $file_name };
	return 0;
}


# Note that if the file was requested with a path and not merely a file name,
# the retrieve call must supply the same path.  If the load call received only
# a file name, and found the config file in the default dir, the retrieve call
# needs only the file name.
sub retrieve_config
{
# WARN  This package-name check is likely not sufficient.
	shift if ref( $_[ 0 ] ) || $_[ 0 ] =~ m|::|;
	
	my( $file_name, $setting_name );
	
	$file_name = shift();
	$setting_name = shift() || '';
	
	return undef unless $file_name =~ m|^[\.\w/]+$|;
	
	load_config( $file_name ) if ! exists $files{ $file_name };
	
	return $files{ $file_name }->{ $setting_name } if $setting_name;
	return %{ $files{ $file_name } } if $file_name && ref( $files{ $file_name } ) eq 'HASH';
	return;
}


sub loaded_files
{
	return keys %files;
}


sub search_files
{
# WARN  This package-name check is likely not sufficient.
	shift if ref( $_[ 0 ] ) || $_[ 0 ] =~ m|::|;
	
	my( $setting_name, %found );
	
	$setting_name = shift();
	
	$found{ $_ } = retrieve_config( $_, $setting_name ) for keys %files;
	
	return %found;
}


1;
