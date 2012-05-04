my( $s );

$s = qoan( 'env', 'uri:lead' );
$s .= '/' . qoan( 'env', 'application_alias' ) if qoan( 'env', 'uri:alias:virtual' );

$s;
