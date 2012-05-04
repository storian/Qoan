my( $s );

$s = $renderer->qoan( 'env', $params[ 0 ] );
# Following to prevent 'uninitialized' warnings
$s = '' unless defined $s;

$s;
