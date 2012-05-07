#!/usr/bin/perl

use strict;

my( $redir_cfg_shared, $redir_cfg_app, @apps_lines, %apps, $app_home, $qoan_home, $redirect_home, $requested );

$redir_cfg_app = $ENV{ 'DOCUMENT_ROOT' };

for ( split( '/', $ENV{ 'REQUEST_URI' } ) )
{
	next unless $_;
	$_ =~ s|\?.*$||;
	last unless -e "$redir_cfg_app/$_";
	$redir_cfg_app .= "/$_";
}

$redir_cfg_shared = 'qoan_redirect.cfg';
$redir_cfg_app .= "/$redir_cfg_shared";

for ( $redir_cfg_shared, $redir_cfg_app )
{
	next unless open( APPS, "<", $_ );
	@apps_lines = <APPS>;
	close( APPS );
	
	for ( @apps_lines )
	{
		s|[\s\n]||g;
		next unless $_;
		$apps{ ( m|^(\w+)| )[ 0 ] } = ( m|=([/\w]+)| )[ 0 ] if m|^\w+=[/\w]+$|;
		$apps{ $_ } = "/$_/$_" if ( m|^\w+$| );
	}
}

die 'No Qoan application home directory defined for Qoan redirector script' unless $apps{ 'app_home' };

$requested = $ENV{ 'REQUEST_URI' };
$requested =~ s|^$apps{ 'redirect_home' }||;
$requested = ( $requested =~ m|^/?(\w+)| )[ 0 ];

if ( $apps{ $requested } =~ m|^INTERNAL| )
{
	$requested = ( $apps{ $requested } =~ m|/(\w+)| )[ 0 ] if $apps{ $requested } =~ m|^INTERNAL/|;
	print `perl -I $apps{ 'app_home' } @{[ $apps{ 'qoan_home' } || $apps{ 'app_home' } ]}/Qoan/utility/internal.pl $requested`;
	exit;
}

if ( exists $apps{ $requested } )
{
	print `perl -I $apps{ 'app_home' } $apps{ 'app_home' }/$apps{ $requested }.pl $requested`;
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
