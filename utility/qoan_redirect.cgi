#!/usr/bin/perl

use strict;

my( $app_cfg, @apps_lines, %apps, $app_home, $qoan_home, $redirect_home, $requested, $app_code );

$app_cfg = 'qoan_redirect.cfg';

unless ( -e $app_cfg )
{
	my( $source, $request );
	$source = $ENV{ 'DOCUMENT_ROOT' };
	$request = $ENV{ 'REQUEST_URI' };
	$request =~ s|\?.*$||;
	for ( split( '/', $request ) )
	{
		next unless $_;
		last unless -e "$source/$_";
		$source .= "/$_";
	}
	$app_cfg = "$source/$app_cfg";
}

open( APPS, "<", $app_cfg );
@apps_lines = <APPS>;
close( APPS );

for ( @apps_lines )
{
	s|[\s\n]||g;
	next unless $_;
	$app_home = ( m|^app_home=([/\w]+)| )[ 0 ] if m|^app_home=|;
	$qoan_home = ( m|^qoan_home=([/\w]+)| )[ 0 ] if m|^qoan_home=|;
	$redirect_home = ( m|^redirect_home=([/\w]+)| )[ 0 ] if m|^redirect_home=|;
	$apps{ ( m|^(\w+)| )[ 0 ] } = ( m|=([/\w]+)| )[ 0 ] if m|^\w+=[/\w]+$|;
	$apps{ $_ } = "/$_/$_" if ( m|^\w+$| );
}

die 'No Qoan application home directory defined for Qoan redirector script' unless $app_home;

$requested = $ENV{ 'REQUEST_URI' };
$requested =~ s|^$redirect_home||;
$requested = ( $requested =~ m|^/?(\w+)| )[ 0 ];

if ( $apps{ $requested } =~ m|^INTERNAL| )
{
	$requested = ( $apps{ $requested } =~ m|/(\w+)| )[ 0 ] if $apps{ $requested } =~ m|^INTERNAL/|;
	print `perl @{[ $qoan_home || $app_home ]}/Qoan/utility/internal.pl $requested`;
	exit;
}

if ( exists $apps{ $requested } )
{
	print `perl $app_home/$apps{ $requested }.pl $requested`;
	exit;
}


# No application matches file list, provide default response.
my $reqstr = $ENV{ 'REQUEST_URI' };
$reqstr =~ s|^/||;
$reqstr =~ s|%(\d+)|chr( $1 + 12 )|eg;

print qq|Content-type: text/html

<html>
<head>
<title>Karma.</title>
</head>

<body bgcolor="#d8d8d0">

<center>
<p><font color="#003399">Your request for <b>$reqstr</b> has unfortunate karma.</font></p>
<img src="buddha.jpg" />
</center>

</body>

</html>
|;
