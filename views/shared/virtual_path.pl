# "alias" -> get app alias 
# 

# action:route -> e.g. /story/:story_name/:section_name/:page_name
# uri: sections

my( $s );

$s = '{{insert_env uri:app_root/}}/{{insert_env application_alias/}}';

$s = $renderer->qoan( 'env', $params[ 0 ] );
# Following to prevent 'uninitialized' warnings
$s = '' unless defined $s;

$s;
