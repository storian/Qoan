
package Qoan::View;

use strict;

our $VERSION = '0.10';

# The Qoan::View package is responsible for building the view returned
# to the client.

my( %cache, %cache_cfg );

%cache_cfg = ( 'last_expiration_check' => time(), 'cache_expiration' => 10 );


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub new
{
	return if _called_by_evaled_view();
	
	my( $renderer, %render_cfg, @caller );
	
# Zotz package name.
	shift();
	
	%render_cfg = @_;
	
	$render_cfg{ 'source_type' } ||= 'files';
	$render_cfg{ 'max_passes' } ||= 30;
	$render_cfg{ 'max_passes' } = 30 if $render_cfg{ 'max_passes' } > 30;
	
	$renderer = sub {
		local *__ANON__ = 'qoan_renderer_main_closure';
		
		my $package = __PACKAGE__;
		return if ( caller( 1 ) )[ 3 ] !~ m|^$package|;  # Allow only Private accessors.
		
		my( $index, $value ) = @_;
		
# Return all set values if none specified.
		return %render_cfg unless $index;
		
		$render_cfg{ $index } = $value if $value;
		return $render_cfg{ $index } if exists $render_cfg{ $index };
		};
	
	bless $renderer, __PACKAGE__;
	
	return $renderer;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub cache_cfg
{
	return if _called_by_evaled_view();
	
	my( %cfg ) = @_;
	
	$cache_cfg{ $_ } = $cfg{ $_ } for keys %cfg;
	
	return;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub cache_expire
{
	return if _called_by_evaled_view();
	
	my( $expiration, $now, $cached );
	
# Expiration time is minutes; convert to seconds.
	$expiration = $cache_cfg{ 'cache_expiration' } || 10;
	$expiration *= 60;
	
	$now = time();
	
# Don't bother checking views unless enough time has passed since last check.
	return unless $now > ( $cache_cfg{ 'last_expiration_check' } + $expiration );
	
# Reset last check time.
	$cache_cfg{ 'last_expiration_check' } = $now;
	
	for ( keys %cache )
	{
		$cached = $cache{ $_ }->{ 'time' };
		delete $cache{ $_ } if $now > ( $cached + $expiration );
	}
	
	return;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub cache_purge
{
	return if _called_by_evaled_view();
	%cache = ( );
	return;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub _cache_retrieve
{
	return unless ( caller( 1 ) )[ 3 ] eq 'Qoan::View::_fetch_view';
	
	return %{ $cache{ $_[ 0 ] } } if defined $cache{ $_[ 0 ] };
	return;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub _cache_skip
{
	return unless ( caller( 1 ) )[ 3 ] eq 'Qoan::View::_fetch_view';
	
	my( $renderer, $name );
	
	$renderer = shift();
	$name = shift();
	
	return 1 if $renderer->( 'skip_cache' );
	
	return 0 unless $name;
	
	for ( @{ $cache_cfg{ 'do_not_cache' } } )
	{
		return 1 if $_ eq $name;
	}
	
	return 0;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub _cache_store
{
	return unless ( caller( 1 ) )[ 3 ] eq 'Qoan::View::_fetch_view';
	
	my( $name, %view ) = @_;
	
	$view{ 'time' } = time();
	$cache{ $name } = { %view };
	
	return %{ $cache{ $name } };
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub get_cfg
{
	my( $renderer, $cfg_index );
	
	$renderer = shift();
	$cfg_index = shift();
	
	return $renderer->( $cfg_index ) if $cfg_index;
	return $renderer->( );
}


# method VIEW_RENDER
# purpose:
#		Builds a view to return to the client through
#		successive cycles of interpolation.
# usage:
#		- renderer object ref
#		- parameter set for identifying view to use;
#			view_start: name/ID of starting view
#			sources: where to search for view (e.g., filesys dirs, db connect strings)

# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub render_view
{
	return if _called_by_evaled_view();
	
	my( $renderer, %params );
	my( $re_check, $re_simple, $re_wrapper1, $re_wrapper2, $i );
	my( $view );
	
# Note this routine doesn't use the controller object.  Remove check?
	$renderer = shift();
	
	%params = @_;
# Required parameters are:
#	view_start (string), and
#	sources (array ref)
	
	unless ( $params{ 'view_start' } )
	{
		warn 'No starting view supplied to render call';
		return 0;
	}
	
# Word chars and forward slash chars are allowed; that's it.
	unless ( $params{ 'view_start' } =~ m|^[\w:]+$| )
	{
		warn 'Starting view name has invalid format';
		return 0;
	}
	
	unless ( ref( $params{ 'sources' } ) eq 'ARRAY' && $params{ 'sources' }->[ 0 ] )
	{
		warn 'No source supplied to render call';
		return 0;
	}
	
# Store params in object.
	for ( keys %params )
	{
		$renderer->( $_ => $params{ $_ } );
	}
	
# The REGULAR EXPRESSIONS.
#  Checks for interpolation symbols in view text - finds either simple symbols {{*/}}
#  or closing wrap symbols {{/*}} WITHOUT embedded interpolation symbols.
	$re_check = qr@{{ # opening braces
		(/?) # closing tag slash, if present
		(?=(.+?)}}) # lookahead capture match to first closing braces
		(?(?{ index( $^N, "\x7b\x7b" ) == -1 }) # condition: lookahead capture has no opening braces in it
			[\w:]+(?:|\s.+?)(?(?{!$1})/)}} # iftrue: the pattern for the rest of the symbol
			| \0 # iffalse: null char, should not match (in theory)
		) # end conditional
		@x;
	
#  Interpolates simple symbols {{*/}}.
	$re_simple = qr@{{ # opening braces
		(?=(.+?)}}) # $1 - lookahead capture match to first closing braces
		(?(?{ index( $^N, "\x7b\x7b" ) == -1 }) # condition
			([\w:]+)(?:|\s(.+?))/}} # $2, $3 - iftrue: captures view name and parameters
			| \0
		) # end conditional
		@x;
	
#  Interpolates wrap symbols {{/*}} WITH opening tags.
	$re_wrapper1 = qr@
		{{([\w:]+)}} # $1 - opening wrap tag (no slash, no parameters), capture view name
		(.*?) # $2 - capture text to be wrapped
		{{/ # opening braces and slash for closing wrap tag
		(?=(.+?)}}) # $3 - lookahead capture match to first closing braces
		(?(?{ index( $^N, "\x7b\x7b" ) == -1 }) # condition
			\1(?:|\s(.+?))}} # $4 - iftrue: captures view parameters
			| \0
		) # end conditional
		@xs;
	
#  Interpolates wrap symbols {{/*}} WITHOUT opening tags.
	$re_wrapper2 = qr@^
		(.*?) # $1 - capture text to be wrapped
		{{/ # opening braces and slash for closing wrap tag
		(?=(.+?)}}) # $2 - lookahead capture match to first closing braces
		(?(?{ index( $^N, "\x7b\x7b" ) == -1 }) # condition
			([\w:]+)(?:|\s(.+?))}} # $3, $4 - iftrue: captures view name and parameters
			| \0
		) # end conditional
		@xs;
	
# Turn starting view name into interpolation symbol.
	$view = '{{' . $params{ 'view_start' } . '/}}';
	
	while ( $view =~ m@$re_check@ )
	{
		$i++;
		last if $i > $renderer->( 'max_passes' );
		print STDERR "Rendering pass $i..";
		
		while ( $view =~ s@$re_simple@$renderer->_fetch_view( $2, $3 )@eg )
		{
			1;
		}
		
		while ( $view =~ s@$re_wrapper1@$renderer->_fetch_view( $1, $4, $2 )@eg )
		{
			1;
		}
		
		while ( $view =~ s@$re_wrapper2@$renderer->_fetch_view( $3, $4, $1 )@eg )
		{
			1;
		}
		
	}
	
# Check views expiration.
	cache_expire();
	
# Skip-cache's life lasts only for a single render.
# Making it unconditional means it can reset the value on subsequent calls
# if a reset fails for some reason.
	$renderer->( 'skip_cache' => undef );
	
	return $view;
}


# Purpose:  Locates view in available resources, fetches view text, passes to filter.
# Context:  Private, callable only by sub render_view.
# Receives: 1) renderer ref
#           2) view name
#           3) optional parameter string for use in view processing
#           4) optional insertion text for wrapping view tags
# Returns:  Processed view text.
# External: a) prints to STDERR
#           b) globs filenames in a source directory
#           c) opens/closes view file
#           d) calls warn
#           e) db call -- NOT IMPLEMENTED
#           f) calls sub _cache_skip
#           g) calls sub _cache_store
#           h) calls sub _eval_view
#
sub _fetch_view
{
	return unless ( caller( 1 ) )[ 3 ] eq 'Qoan::View::render_view';
	
	my( $renderer );
	my( $name, $params, @params, $insert, %view, $text, $source, $evalme );
	
	$renderer = shift();
	$name = shift() || '';
	$params = shift() || '';
	$insert = shift() || '';
	
# Provides a default split of the $params string, on commas.
# If this is not how the view wants its parameters split, it will have to
# do it itself.
	#@params = split( /,/, $params );
	
# The view name can be a path to a resource beneath the source root directory.
# Directories are distinguished by :, not by / or \ (will cause problems with
# the / used to close view tags).
	$name =~ s|:|/|g;
	
# External a)
	print STDERR "Including view $name $params..";
	
# Check cache for view; fetch if not in cache.
	unless ( %view = _cache_retrieve( $name ) )
	{
		if ( $renderer->( 'source_type' ) eq 'files' )
		{
			my( @globbed, @found, $file );
			
			for ( @{ $renderer->( 'sources' ) } )
			{
				$view{ 'source' } = $_;
# External b)
				@globbed = glob( "$view{ 'source' }$name.*" );
				
				push( @found, $_ ) for grep { ! /~$/ } @globbed;
				
				next if @found == 0;
				last if @found > 1;
				
# External a)
				print STDERR "Opening file: $found[ 0 ]..";
# External c)
				open( $file, '<', $found[ 0 ] );
				$view{ 'text' } .= $_ for <$file>;
# External c)
				close $file;
				
				$view{ 'evalme' } = ( $found[ 0 ] =~ m|\.pl$| ) ? 1 : 0;
				
				last if @found == 1;
			}
			
			if ( @found == 0 )
			{
# External d)
				warn "No view found with name $name";
			}
			
			if ( @found > 1 )
			{
# External d)
				warn "More than one view found with the name $name in $view{ 'source' }";
				return;
			}
		}
		elsif ( $renderer->( 'source_type' ) eq 'database' )
		{
			;
# External e)
			#$v = $renderer->_execsql( 'select * from view where view_name = ?', &_GETROW, $name );
		}
		
# Caching and retrieving view.
# NOTE  the _cache_skip call is an object call because caching might be off
# for this render.
# External f)
		unless ( $renderer->_cache_skip( $name ) )
		{
			#print STDERR "Caching view..\n";
# External g)
			%view = _cache_store( $name, %view );
		}
	}
	
	
# The view evaluation is a separate routine in order to firewall eval'ed code
# off from the variables in this one.
	if ( $view{ 'evalme' } )
	{
# External h)
		$view{ 'text' } = $renderer->_eval_view(
			'name' => $name, 'inserting' => ( $insert ? 1 : 0 ),
			'params' => $params, %view );
	}
	
# This is to provide a line break between views for the Qoan controller report.
# External a)
	print STDERR "";
	
# Set view text to zero-len string if undefined (prevents later warnings).
	unless ( defined $view{ 'text' } )
	{
# External d)
		warn "View $name undefined";
		$view{ 'text' } = '';
	}
	
	if ( $insert )
	{
# External d)
		$view{ 'text' } =~ s/{{\s*}}/$insert/ or warn 'No interpolation symbol for insertion text';
	}
	
# Remove any trailing newline char.
	chomp( $view{ 'text' } );
	
	return $view{ 'text' };
	
}


# Purpose:  Internal default "filter" for perl files.
# Context:  Private, called by sub _fetch_view only.
# Receives: 1) renderer ref
#           .) view parameters
# Returns:  eval'ed view
# External: a) eval'ed code could potentially have any number of external calls.
#           b) calls warn.
# Note: the eval'ing of the view is in a separate sub to provide some
#       security wrt variables in the eval context.
#
sub _eval_view
{
	return unless ( caller( 1 ) )[ 3 ] eq 'Qoan::View::_fetch_view';
	
	my( $renderer, %view, $inserting, @params, $evaled );
# These lexicals prevent access by the eval'ed views to the package lexicals
# of the same names.
	my( %cache, %cache_cfg );
	
	$renderer = shift();
	%view = @_;
	$inserting = $view{ 'inserting' };
	@params = split( /,/, $view{ 'params' } );
	
# External a)
	$evaled = eval $view{ 'text' };
# External b)
	warn "error for EVAL $view{ 'name' }: $@" if $@;
	
	return $evaled;
}


# Purpose:  x
# Context:  x
# Receives: x
# Returns:  x
# External: x
#
sub _called_by_evaled_view
{
	my( @caller1, @caller2 );
	
# Eval'ed views may not call.
	@caller1 = ( caller( 1 ) )[ 0, 3 ];
	@caller2 = ( caller( 2 ) )[ 0, 3 ];
	
	return 1 if $caller1[ 0 ] eq __PACKAGE__ &&
		$caller1[ 1 ] eq '(eval)' &&
		$caller2[ 1 ] eq 'Qoan::View::_fetch_view';
	
	return 0;
}


1;
