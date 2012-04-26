
my( $http_report, $errors, %env, $friendly_time );

# Remember, this is where we're grabbing the request report, so
# OUTPUTTING ADDITIONAL STUFF TO THE REPORT WON'T SHOW UP IN IT.
# Sad but true.

# Prettify main report.
$http_report = $renderer->get_cfg( 'run_report' );
$http_report =~ s|\n(\s*::[^\n]*)\n|\n<font color="blue">$1</font>\n|gs;
$http_report =~ s@\n([^\n]*(?:warn|fail)[^\n]*)\n@\n<font color="red">$1</font>\n@igs;

# Getting this here because $friendly_time needs it.
%env = $renderer->qoan( 'env' );

# Friendly timestamp, format e.g.: 2013 Jan 15 (Tue) 21:47:38 GMT
use POSIX;
$friendly_time = POSIX::strftime( "%Y %b %e (%a) %H:%M:%S GMT", gmtime( $env{ 'started' } ) );

# Prepend list of errors that occurred during run.
$errors .= $_ . ( $_ =~ m|\n\Z|s ? '' : "\n" ) for @{ $renderer->get_cfg( 'errors' ) };
$errors = $errors ? "\n\n$errors" : 'none.';

$http_report = "RUNTIME: $friendly_time\nERRORS:  $errors\n\n$http_report";

# Append functional environment values.
$http_report .= "\n\nFUNCTIONAL ENV:\n\n";
$http_report .= " :: $_ => $env{ $_ }\n" for sort keys %env;

# Wrap in basic HTML stuff.
$http_report = "<!DOCTYPE html>\n<title>Qoan Run Report</title>\n\n<pre>\n$http_report\n</pre>";

# Return.
$http_report;
