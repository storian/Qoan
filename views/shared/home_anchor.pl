my( $s );

$s = qoan( 'env', 'uri:app_root' );
$s .= '/' . qoan( 'env', 'application_alias' ) if qoan( 'env', 'uri:alias:virtual' );

$s;
