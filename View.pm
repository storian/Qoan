
package Qoan::View;

use strict;

our $VERSION = '0.10';

# The Qoan::View package is responsible for building the view returned
# to the client.

# This is for bargain-basement cache operations.
my %cache;


sub purge_cache
{
	%cache = ( );
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

sub render_view #($$) #($$$)
{
	my( $renderer, %params );
	my( $re_check, $re_simple, $re_wrapper1, $re_wrapper2, $i );
	my( $view );
	
# Note this routine doesn't use the controller object.  Remove check?
	#$renderer = shift();
	$renderer = bless( { }, __PACKAGE__ );
	
	%params = @_;
# Required parameters are:
#	view_start (string), and
#	sources (array ref)
	$renderer->{ $_ } = $params{ $_ } for keys %params;
	$renderer->{ 'source_type' } ||= 'files';
	$renderer->{ 'cache_expiration' } ||= '10';
	$renderer->{ 'max_passes' } ||= 15;
	
	unless ( $renderer->{ 'view_start' } )
	{
		warn 'No starting view supplied to render call';
		return 0;
	}
	
# Word chars and forward slash chars are allowed; that's it.
	unless ( $renderer->{ 'view_start' } =~ m|^[\w:]+$| )
	{
		warn 'Starting view name has invalid format';
		return 0;
	}
	
	unless ( defined $renderer->{ 'sources' }[ 0 ] )
	{
		warn 'No source supplied to render call';
		return 0;
	}
	
	
	$view = '{{' . $renderer->{ 'view_start' }. '/}}';
	
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
	
	while ( $view =~ m@$re_check@ )
	{
		$i++;
		last if $i > $renderer->{ 'max_passes' };
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
	
# The view can contain headers.
	return $view;
}


# method _FETCH_VIEW
# purpose:
#		Fetches the text for a single view for the _build_view
#		routine.  Evals if it is an executable view.
# usage:
#		- request object ref
#		- name of view
#		- parameters for executable view (string)
#		- text to insert if it is a wrapper view
#		NOTE: currently it is necessary always to supply a
#		$params in order to supply an $insert, to prevent
#		_fetch_view from getting confused.  However, only
#		_build_view calls (and should call) this sub, so it
#		shouldn't be an inconvenience for anyone.

sub _fetch_view ($$;$$)
{
	my( $renderer );
	my( $name, $params, @params, $evalme, $insert, $text, $source );
	
	$renderer = shift();
	$name = shift() || '';
	$params = shift() || '';
	$insert = shift() || '';
	
# Provides a default split of the $params string, on commas.
# If this is not how the view wants its parameters split, it will have to
# do it itself.
	@params = split( /,/, $params );
	
	$text = '';
	
# The view name can be a path to a resource beneath the source root directory.
# Directories are distinguished by :, not by / or \ (will cause problems with
# the / used to close view tags).
	$name =~ s|:|/|g;
	
	print STDERR "Including view $name..";
	
# Checking cache for view.
	if ( exists $cache{ $name } )
	{
# WARN  removing from cache should happen in another routine.
		my $delete = ( time() - $cache{ $name }->{ 'time' } ) > ( $renderer->{ 'cache_expiration' } * 60 ) ? 1 : 0;
		
		if ( $delete )
		{
			delete $cache{ $name };
		}
		else
		{
			print STDERR "Retrieving from cache..\n";
			$text = $cache{ $name }->{ 'text' };
			$evalme = $cache{ $name }->{ 'eval' };
		}
	}
	
# View not found in cache.
	if ( ! $text )
	{
		if ( $renderer->{ 'source_type' } eq 'files' )
		{
			my( @globbed, @found, $file );
			
			for $source ( @{ $renderer->{ 'sources' } } )
			{
				#$source = $_;
				@globbed = glob( "$source$name.*" );
				
				push( @found, $_ ) for grep { ! /~$/ } @globbed;
				
				next if @found == 0;
				last if @found > 1;
				
				print STDERR "Opening file: $found[ 0 ]..\n";
				open( $file, '<', $found[ 0 ] );
				$text .= $_ for <$file>;
				close $file;
				
				$evalme = ( $found[ 0 ] =~ m|\.pl$| ) ? 1 : 0;
				
				last if @found == 1;
			}
			
			if ( @found == 0 )
			{
				warn "No view found with name $name";
			}
			
			if ( @found > 1 )
			{
				warn "More than one view found with the name $name in $source";
				return;
			}
		}
		elsif ( $renderer->{ 'source_type' } eq 'database' )
		{
			;
			#$v = $renderer->_execsql( 'select * from view where view_name = ?', &_GETROW, $name );
		}
	}
	
# Caching view.
	unless ( exists $cache{ $name } )
	{
		$cache{ $name } = { 'text' => $text, 'time' => time(), 'eval' => $evalme };
	}

	
	$text = eval $text if $evalme;
	warn "  error for EVAL $name: $@" if $@;
	
# Set to zero-len string if undefined (prevents later warnings).
	unless ( defined $text )
	{
		warn "View $name undefined";
		$text = '';
	}
	
	$text =~ s/{{}}/$insert/ if $insert;
	
# Remove any trailing newline char.
	chomp( $text );
	
	return $text;
	
}


1;
