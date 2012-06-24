#!/usr/bin/perl -w

use strict;

my( $cgi_execution );

#print STDERR " :: $_ => $ENV{ $_ }\n" for sort keys %ENV;

$cgi_execution = exists $ENV{ 'GATEWAY_INTERFACE' } ? 1 : 0;

if ( ( ! @ARGV && ! $cgi_execution ) || ( $ARGV[ 0 ] && $ARGV[ 0 ] =~ m@^(?:-h|--help)$@ ) )
{
	print STDERR usage();
	exit;
}

print STDERR "Qoan Redirect: command line arguments exist for CGI execution.\n"
	if $cgi_execution && @ARGV;


# 1.  Determine arguments.
# Allowed arguments:
#  -q, --request  : "request URI"
#  -r, --root     : "document root"
#  -c, --cookie   : "cookie"
#  -m, --method   : "request method"
#  -f, --file     : path to file containing "request headers" (whose labels must match other allowed args)
#  -p, --profiler : runs Qoan call through profiler

my( %env, $profiler, $export );

$profiler = '';
$export = '';

{
	my( @args, $k, $v, $re_root, $re_request, $re_method, $re_cookie, $key_matched );
	
	$re_root    = '^([/\-\.\w]+)$';
	$re_request = '^([/\-\.\?\w=\%]+)$';
	$re_method  = '^(?:POST|GET)$';
	$re_cookie  = '^((?:\w+=\w+;? ?){1,})$';
	
	@args = @ARGV;
	
	while ( @args )
	{
		$k = shift @args;
		$v = '';
		$key_matched = 0;
		
		if ( $k =~ m|^--\w+=| || $k =~ m|^-[qrcmfp]=| )
		{
			( $k, $v ) = split( '=', $k, 2 );
		}
		else
		{
			$v = shift( @args ) unless $args[ 0 ] =~ m|^--\w+=| || $args[ 0 ] =~ m|^-[qrcmfp]=|;
		}
		
		if ( $k =~ m@^(-r|--root)$@ )
		{  $env{ 'DOCUMENT_ROOT' }  ||= ( $v =~ m|$re_root| )[ 0 ];     $key_matched = 1; }
		
		if ( $k =~ m@^(-q|--request)$@ )
		{  $env{ 'REQUEST_URI' }    ||= ( $v =~ m|$re_request| )[ 0 ];  $key_matched = 1; }
		
		if ( $k =~ m@^(-m|--method)$@ )
		{  $env{ 'REQUEST_METHOD' } ||= ( $v =~ m|$re_method| )[ 0 ];   $key_matched = 1; }
		
		if ( $k =~ m@^(-c|--cookie)$@ )
		{  $env{ 'HTTP_COOKIE' }    ||= ( $v =~ m|$re_cookie| )[ 0 ];   $key_matched = 1; }
		
		if ( $k =~ m@^(-p|--profiler)$@ )
		{  $profiler ||= ( $v || 'default profiler' );  $key_matched = 1; }
		
		unless ( $key_matched ) {  print "Argument $k not recognized; please review usage.\n\n", usage();  exit;  }
		
		# profiling ?
	}
	
# Provide default REQUEST_METHOD, to provide for the Qoan app, if calling from command line.
	$env{ 'REQUEST_METHOD' } ||= 'GET' unless $cgi_execution;
	
# If running as CGI, get these values, required by subsequent logic, from server ENV.
	if ( $cgi_execution )
	{
		#$env{ 'REQUEST_URI' }   = ( $ENV{ 'REQUEST_URI' } =~ m|$re_request| )[ 0 ];
		#$env{ 'DOCUMENT_ROOT' } = ( $ENV{ 'DOCUMENT_ROOT' } =~ m|$re_root| )[ 0 ];
		$env{ 'REQUEST_URI' }   = $ENV{ 'REQUEST_URI' };
		$env{ 'DOCUMENT_ROOT' } = $ENV{ 'DOCUMENT_ROOT' };
	}
	
# Export environment values if called from the command line.
	if ( ! $cgi_execution )
	{
		@env{ 'REDIRECT_URL', 'QUERY_STRING' } = split( /\?/, $env{ 'REQUEST_URI' } );
		
		$export = 'export ';
		$export .= "$_=$env{ $_ } " for keys %env;
		$export .= '; ';
		print STDERR "EXPORT CMD: $export\n";
	}
}


# 2.  Process arguments to call Qoan application.
my( $redir_cfg_shared, $redir_cfg_app, @cfg_lines, %apps, $requested );

$redir_cfg_app = $env{ 'DOCUMENT_ROOT' };

for ( split( '/', $env{ 'REQUEST_URI' } ) )
{
	next unless $_;
	$_ =~ s|\?.*$||;
	last unless -e "$redir_cfg_app/$_";
	$redir_cfg_app .= "/$_";
}

$redir_cfg_shared = 'qoan_redirect.config';
$redir_cfg_app .= "/$redir_cfg_shared";

for ( $redir_cfg_shared, $redir_cfg_app )
{
	next unless open( APPS, "<", $_ );
	@cfg_lines = <APPS>;
	close( APPS );
	
	for ( @cfg_lines )
	{
		s|[\s\n]||g;
		next unless $_;
		$apps{ $1 } = $2 if m|^(\w+)=([/\w]+)$|;  # == 2?
		$apps{ $_ } = "/$_/$_" if ( m|^\w+$| );
	}
}

die 'No Qoan application home directory defined for Qoan redirector script' unless $apps{ 'qoan_home' };

$apps{ 'redirect_home' } ||= '';

$requested = ( $env{ 'REQUEST_URI' } =~ m|^$apps{ 'redirect_home' }/?(\w+)| )[ 0 ];

die qq|Path reversal exists in path for requested app "$requested"| if $apps{ $requested } =~ m|\.\.|;

if ( $apps{ $requested } =~ m|^INTERNAL| )
{
	$requested = ( $apps{ $requested } =~ m|/(\w+)| )[ 0 ] if $apps{ $requested } =~ m|^INTERNAL/|;
	print `$export perl -I $apps{ 'qoan_home' } $apps{ 'qoan_home' }/Qoan/utility/internal.pl $requested`;
	exit;
}

if ( exists $apps{ $requested } )
{
	$apps{ 'apps_home' } ||= $apps{ 'qoan_home' };
	$apps{ 'apps_home' } .= '/' unless $apps{ 'apps_home' } =~ m|/$|;
	print `$export perl -I $apps{ 'qoan_home' } $apps{ 'apps_home' }$apps{ $requested }.pl $requested`;
	exit;
}


# No application matches file list, provide default response.
my $reqstr = $env{ 'REQUEST_URI' };
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
<img src="/cgi-bin/buddha.jpg" />
</center>

</body>

</html>
|;

exit;


sub usage
{
	return "USAGE\n";
}
