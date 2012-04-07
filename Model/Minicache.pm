
package Qoan::Model::Minicache;

use strict;

our $VERSION = '0.02';

# Minicache parses a file into a perl hash to which it gives access via a closure.
# Basically it's a super-easy way to load a set of values recorded in a file as an object.
# Default mode is read-only; read-write allows storage of new values.
# Accepts subroutine references to load to provide more "object" functionality.

use Qoan::Model;
use Qoan::Helper::Require;

our @ISA = qw| Qoan::Model |;


# Defining _compile here to prevent "called to early to check prototype" warning
# due to _compile being recursive.
# COMMENTED OUT Feb 2012 after removing prototype declarations on subs.
#sub _compile ($$);


# Initialization settings include:
#	source: path to source file. Required.
#	paths: existence means prepend each path to source to check for file.
#	mode: RO or RW, defaults to RO.
#	helpers: Helper packages to import.
#	import: subroutine references to import.

#	preserve: preserves file as loaded (whitespace, comments, ordering) - defaults to on if comments found?
# inline comments?

#sub new ($$)
sub new
{
	my( $class, %cfg, @lines, %cache, $mini );
	
	$class = shift();
	%cfg = @_;
	
	$cfg{ 'mode' } ||= 'RO';
	
# Closure.
	$mini = sub {
		local *__ANON__ = "minicache_$cfg{ 'source' }";
		my $package = __PACKAGE__;
		return undef if ( caller( 1 ) )[ 3 ] !~ m|$package|;  # Allow only Private callers.
		
		my( $index, $value, @keypath, $loc );
		$index = shift();
		$value = shift() || '';
		
# Return all set values if none specified.
		return %cache if ! $index;
		
# Cfg access, read-only (as in, prevents changing of written values).
		return $cfg{ $index } if exists $cfg{ $index };
		
# Compound index processing.
		@keypath = split( ':', $index );
		$index = pop( @keypath );
		$loc = \%cache;
		
		for ( @keypath )
		{
			$loc->{ $_ } = { } unless defined $loc->{ $_ };
			$loc = $loc->{ $_ };
		}
		
# Cache write access.
		if ( $value && $cfg{ 'mode' } eq 'RW' )
		{
			if ( ref( $loc->{ $index } ) eq 'ARRAY' && ! ref $value )
			{
				push( @{ $loc->{ $index } }, $value );
				$cfg{ 'dirty' } = 1;
			}
			else
			{
				$loc->{ $index } = $value;
				$cfg{ 'dirty' } = 1;
			}
		}
		
# Return last index's value.
		return %{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'HASH';
		return @{ $loc->{ $index } } if ref( $loc->{ $index } ) eq 'ARRAY';
		return $loc->{ $index } if exists ${ $loc }{ $index };
		};
	
	bless $mini;
	
# Helpers are names of packages with code to import.
# WARN NOT TESTED 10/1/11
# WARN Should use Require helper.  Change 'helpers' to hash ref?
# WARN Note that ability to import helpers pushes Minicache toward a generic Model class.
	for ( @{ $cfg{ 'helpers' } } )
	{
		#eval "require $_"; import $_;
		$mini->_require( $_ ); import $_;
	}
	
# Imports are sub references to add to the package symbol table.
# WARN NOT TESTED 10/1/11
	for ( keys %{ $cfg{ 'import' } } )
	{
		#my $p = __PACKAGE__;
		*{ __PACKAGE__ . "::$_" } = ${ $cfg{ 'import' } }{ $_ };
	}
	
	@lines = _load_file( \%cfg );
	%cache = _parse_lines( \%cfg, \@lines );
	
	return $mini;
}


#sub cache ($)
sub cache
{
	my( $mini, %set, $compiled );
	
	$mini = shift();
	
	return 1 if ! $mini->( 'dirty' );
	
	%set = $mini->();
	$compiled = _compile( \%set, '' );
	
	#print "COMPILED:\n$compiled\n";
	return $mini->_write_file( $compiled );
}


#sub _compile ($$)
sub _compile
{
	my( $ref, $path, $section, $subsection, $k, $v );
	
	$ref = shift();
	$path = shift();
	$section = $subsection = '';
	
# No subsections possible in "array" sections (because no named values).
	if ( ref( $ref ) eq 'ARRAY' )
	{
		$section =  join( "\n\t", @{ $ref } );
		$section = "\n[ $path ]\n\t$section\n[/ $path ]\n";
	}
	
	if ( ref( $ref ) eq 'HASH' )
	{
		#while ( ( $k, $v ) = each %{ $ref } )
		for ( sort keys %{ $ref } )
		{
			if ( ref( ${ $ref }{ $_ } ) )
			{
				my $subpath = $path . ( $path && ':' ) . $_;
				$subsection .= _compile( ${ $ref }{ $_ }, $subpath );
			}
			else
			{
				$section .= ( $path && "\t" ) . "$_ : @{[ ${ $ref }{ $_ } ]}\n";
			}
		}
		
		$section = qq|\n\[ $path \]\n$section\[/ $path \]\n| if $path && $section;
		$section .= $subsection; # if $subsection;
	}
	
	return $section;
}


#sub get ($;$)
sub get
{
	my( $mini, $index, $thing );
	$mini = shift();
	$index = shift();
	
	return $mini->() if ! $index;
	return $mini->( $index );
}


# Note that this will set nothing if mode is RO.
#sub set ($$$)
sub set
{
	my( $mini, %set, $index, $value, $ok );
	
	$mini = shift();
	%set = @_;
	$ok = 1;
	
	while ( ( $index, $value ) = each %set )
	{
		$ok = 1 if $value eq $mini->( $index, $value );
		last unless $ok;
	}
	
	return $ok;  #$mini->( $index, $value );
}


#sub _load_file ($)
sub _load_file
{
	my( $cfg, $source, @lines, $file );
	$cfg = shift();
	
	for ( @{ ${ $cfg }{ 'paths' } } )
	{
		$source = ${ $cfg }{ 'source' };  # next line convenience
		${ $cfg }{ 'source' } = $_ . $source if -e $_ . $source;
	}
	
	$source = ${ $cfg }{ 'source' };
	
	return undef unless -e $source;
	
	eval { open( $file, '<', $source ) };
	if ( $@ ) {  warn( $@ ); return; }
	
	@lines = <$file>;
	close $file;
	
	return @lines;
}


#sub _write_file ($$)
sub _write_file
{
	my( $mini, @lines, $source, $file );
	$mini = shift();
	@lines = @_;
	
# (Source file name appended with path on load, see above.)
	$source = $mini->( 'source' );
	
	eval { open( $file, '>', $source ) };  # note, > replaces existing file
	
	if ( $@ || ! -e $source )
	{
		warn( $@ || "Created file fails existence check." );
		return;
	}
	
	print $file @lines;
	close $file;
	
	return 1;
}


#sub _parse_lines ($$)
sub _parse_lines
{
	my( $cfg, $line, $lines, $add_to, %cache, $section, $name, $value, $evalme, $section_name );
	
	( $cfg, $lines ) = @_;
	
	for ( @{ $lines } )
	{
		#print "line ==$_";  # has endline
# New, empty files apparently pass a single undefined "line".  Skip it.
		next unless defined $_;
		
# Skip line if only whitespace or if commented out (#, /*, //, ;).
		next if m|^\s*$| ||
			m|^\s*#| ||
			m|^\s*/\*| ||
			m|^\s*//| ||
			m|^\s*;|;
		
		$section_name = '' unless defined $section_name;
		$evalme = '' unless defined $evalme;
		
# Set section name if line is a section heading.
		if ( m|^\s*[<\[]\s*([\w:]+)\s*[>\]]| )
		{
			$section_name = $1;
			#print "  starting section: $section_name\n";
			next;
		}
		
# If line is a section closing tag, prepare compiled section to go into %cache.
		if ( m|^\s*[<\[]\s*/\s*$section_name\s*[>\]]| )
		{
			$name = $section_name;
			$value = $section;
			#print "  closing section $section_name\n";
			$section_name = $section = undef;
		}
		
# If the line has a name and equals/colon, it is a hash line.
		elsif ( m|^\s*([\w:]+)\s*(\*?[=:])\s*([^\n\r]*?)\s*$| )
		{
			( $name, $evalme, $value ) = ( $1, $2, $3 );
			#print "  key line: $name, $evalme, $value\n";
		}
		
# If the line has an optional equals/colon and a value, it is an array line.
		elsif ( m|^\s*(\*?[=:]?)\s*([^\n\r]+?)\s*$| )
		{
			( $evalme, $value ) = ( $1, $2 );
			#print "  value line: $evalme, $value\n";
		}
		
# Add value to hash.  Note this works for both adding a single line and a compiled section.
		if ( $name || $evalme || $value )
		{
			$value = eval "$value" if $evalme =~ m|\*|;
			$evalme = undef;
			$section = ( $name ? {  } : [  ] ) if $section_name && ! ref( $section );
			#print "  Setting add_to to: " . ( $section_name ? $section : %cache ) . "\n";
			$add_to = $section_name ? $section : \%cache;
			
			if ( ! $name )
			{
				push( @{ $section }, $value );
			}
			
			if ( $name )
			{
				my( $p );
				for $p ( split( /:/, $name ) )
				{
					if ( $name =~ m|$p$| )
					{
						#print "  Adding value: $name, $value\n";
						$add_to->{ $p } = $value;
						$name = $value = undef;
					}
					else
					{
						#print "  Creating section: $p\n";
						$add_to->{ $p } = {  } if ! exists ${ $add_to }{ $p };
						$add_to = $add_to->{ $p };
					}
				}
			}
		}
		#print "\n";
	}
	
	return %cache;
}


1;
