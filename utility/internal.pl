#!/usr/bin/perl -w

# Internal.pl is the generic application script for all
# internal Qoan applications.

use strict;

my( $app_code, $qoan_path, $cfg_path, $view_path );

BEGIN
{
	$app_code = $ARGV[ 0 ];
	$qoan_path = ( caller( 0 ) )[ 1 ];
	$qoan_path =~ s|/Qoan/utility/internal.pl$||;
	$cfg_path = $qoan_path . '/Qoan/configs/';
	$view_path = $qoan_path . '/Qoan/views/';
}

use Qoan::Controller (
	'app_config' => "$cfg_path$app_code.config",
	'component:view:store' => "$view_path$app_code/" );

Qoan::Controller->process_request;

exit;
