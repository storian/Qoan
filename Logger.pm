
package Qoan::Logger;

use strict;

our $VERSION;

$VERSION = '0.03';

#use Tie::Handle;
#our @ISA = q| Tie::Handle |; 

my( $real_stderr, $stderr_duped, $capturing_output, $passthrough, $redirector, $captured_output );
my( @captured_errors );
my( $dying ) = 0;


# Dupe STDERR immediately.
BEGIN
{
	$stderr_duped = 0;
	$capturing_output = 0;
	
	select( STDERR );
	
	if ( open( $real_stderr, ">&STDERR" ) )
	{
		$stderr_duped = 1;
		
		$SIG{ __WARN__ } = sub {
			local *__ANON__ = 'warn_handler';
			
			my( @print, @caller, $line, $routine );
			
			@print = @_;
			@caller = caller( 1 );
			
			for ( @print )
			{
				unless ( $_ =~ m| at [/\.\w]+ line \d+| )
				{
					chomp $_;
					$_ .= qq| via package "$caller[ 0 ]" at $caller[ 1 ] line $caller[ 2 ]\n|;
				}
				
				push @captured_errors, $_;
			}
			
# Don't print if $dying, die will take care of logging to STDERR.
			unless ( $dying )
			{
				print @print, ( $capturing_output ? 'WARNING' : ( ) );
			}
			#if ( $capturing_output && ! $dying )
			#{
			#	print @print, 'WARNING';
			#}
			#elsif ( ! $capturing_output )
			#{
			#	print @print;
			#}
		};
		
		$SIG{ __DIE__ } = sub {
			local *__ANON__ = 'die_handler';
			$dying = 1 unless ( caller( 0 ) )[ 1 ] =~ m|eval|;
			warn @_;
		};
	}
	else
	{
# Note, goes to real STDERR.
		warn q|Failed to duplicate STDERR|;
	}
}


# In the even of an uncontrolled halt to execution (death) in the midst of
# catching output to $captured_output (inappropriately in the middle of work), restore
# STDERR with the saved handle and write the log contents.
END
{
# See the note in sub _capture_on.
	close HEYA;
	
	if ( $stderr_duped && $capturing_output && ! $passthrough )
	{
		print $real_stderr "\nDumping captured output on die:\n";
		print $real_stderr $captured_output;
		_capture_off();
	}
}


sub bypass_print
{
	shift() if ref( $_[ 0 ] );  # Remove controller reference
	print $real_stderr join( "\n", @_ ), "\n";
}


# capture_output operates as a switch to turn the capture on or off.
sub capture_output
{
	return $capturing_output ? _capture_off() : _capture_on();
}


sub captured_errors
{
	return @captured_errors;
}


sub captured_output
{
	return $captured_output;
}


sub _capture_off
{
	if ( ! $capturing_output )
	{
# Note, goes to real STDERR.
		warn( q|Logger received request to turn off output capture when output capture is not on| );
	}
	elsif ( untie( *STDERR ) && open( STDERR, ">&", $real_stderr ) )
	{
		$capturing_output = 0;
		$redirector = '';
		return $captured_output;
	}
	else
	{
# WARN  how to tell if ! *STDERR untied or ! STDERR reopened?
		print $real_stderr q|Failed to turn off output capture|;
	}
}


sub _capture_on
{
	if ( ! $stderr_duped )
	{
		warn( q|STDERR not duplicated, can't redirect| );
	}
	elsif ( $capturing_output )
	{
		warn( q|Attempt made to redirect STDERR on already-redirected STDERR| );
	}
	#elsif ( close STDERR && open( STDERR, ">", \$captured_output ) )
	elsif ( close( STDERR ) && tie( *STDERR, __PACKAGE__ ) )
	{
		my $ok;
		
# A most interesting hack:
# Without the following line, when opening a view file in Qoan::View, the following warning
# is raised:
#    Filehandle STDERR reopened as $file only for input at [path to]/Qoan/View.pm line 210.
# 
# Apparently this warning has to do with the order of filehandles expected by Perl.
# Closing STDERR as is done here causes the expected order to change somehow, and so on
# the next open(), the warning happens.  Or at least something in it happens, because the
# following line does not raise the warning.  It does, however, prevent the Qoan::View
# (and presumably any other code's) file open()s from raising the warning.
		open( HEYA, '<', '/home/logs/error_log' );
		
		#select( STDERR );
		$| = 1;
		$capturing_output = 1;
		$passthrough = 0;
		$redirector = caller( 2 ) ? ( caller( 2 ) )[ 3 ] : ( caller( 1 ) )[ 0 ];
		$captured_output = '';
		
		$ok = 0;
		$ok = 1 if print "STDERR redirected to variable capture by $redirector";
		
		return $ok;
	}
	else
	{
		open( STDERR, ">&", $real_stderr );
		print STDERR "\nSTDERR not redirected!\n";
	}
}


# Capture is on by default.  If turned off, output will be lost unless
# pass-through is turned on.
sub capturing
{
	shift();  # Remove controller reference
	
	if ( scalar @_ )
	{
		$capturing_output = $_[ 0 ] ? 1 : 0;
	}
	
	return $capturing_output;
}


sub flush_captured
{
	print $real_stderr $captured_output;
	$captured_output = '';
}


# Pass-through is off by default.
sub passthrough
{
	shift();  # Remove controller reference
	
	if ( scalar @_ )
	{
		$passthrough = $_[ 0 ] ? 1 : 0;
	}
	
	return $passthrough;
}


sub print
{
	shift();  # Remove controller reference
	return print @_;
}


sub report
{
	shift();  # Remove controller reference
	return print @_;
}


sub stderr_duplicated
{
	return $stderr_duped;
}


sub warn
{
	shift();  # Remove controller reference
	warn @_;
	#return print @_;
}


## HANDLE OVERRIDES

# Pass-through => print messages to STDERR
# Capture => add messages to capture variable
sub PRINT
{
	my( $globref, $warning, $indents, $stack_idx, $caller_member, @msgs );
	
	$globref = shift();
	
	@msgs = @_;
	
	$warning = '';
	$warning = pop( @msgs ) if $msgs[ -1 ] eq 'WARNING';
	$indents = 0;
	$stack_idx = 0;
	$caller_member = $redirector eq 'main' ? 0 : 3;
	
	while ( caller( $stack_idx ) && ( caller( $stack_idx ) )[ $caller_member ] ne $redirector )
	{
		#print $real_stderr $stack_idx . ': ' . ( caller( $stack_idx ) )[ $caller_member ] . "\n" if $warning;
		$indents++ if ( caller( $stack_idx ) )[ $caller_member ] !~ m|^Qoan::Logger|;
		$indents-- if ( caller( $stack_idx ) )[ $caller_member ] =~ m|eval|;
		#$indents-- if ( caller( $stack_idx ) )[ $caller_member ] =~ m|die_handler$|;
		#$indents-- if ( caller( $stack_idx ) )[ $caller_member ] =~ m|warn_handler$|;
		$stack_idx++;
	}
	
	for ( @msgs )
	{
		$_ =~ s|\n| "\n" . ( '  ' x $indents ) |ges;
		$_ = "@{[ '  ' x $indents ]}@{[ $warning ? 'WARN: ' : '' ]}$_\n";
	}
	
# Print to real STDERR if pass-through is on.
	print $real_stderr @msgs if $passthrough;
	
# Capture output.
	$captured_output .= join( '', @msgs ) if $capturing_output;
	
	return 1 if ( caller( 1 ) )[ 3 ] eq 'Qoan::Logger::_capture_on';
}


sub PRINTF
{
	;
}


sub TIEHANDLE
{
	return bless \*REPORT, __PACKAGE__;
}


1;
