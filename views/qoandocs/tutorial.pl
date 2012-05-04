my( $name, $page );

$name = $renderer->qoan( 'env', 'request:name' );
$page = $renderer->qoan( 'env', 'request:page' ) || '1';

return '{{tutorial_index/}}' unless $name;


my( $s );
my( %longtitle, %shorttitle, $pages, $next, $link_next, $link_full, $tutorial_body );


%longtitle = (
	'manual_setup' => 'Manual Set-up',
	'qoan_setup' => 'Qoan Installation and Set-up',
	'application_setup' => 'Set Up a New Qoan Application',
	);

%shorttitle = (
	'manual_setup' => 'Manual Set-up',
	'qoan_setup' => 'Install Qoan',
	'application_setup' => 'New Qoan App Set-up',
	);

if ( $page eq 'full' )
{
	;
	$tutorial_body .= "{{tutorial:${name}_@{[ ++$pages ]}/}}" for grep { /\d+\.html$/ } glob( "$view{ 'source' }tutorial/$name*" );
}
else
{
	$pages++ for grep { /\d+\.html$/ } glob( "$view{ 'source' }tutorial/$name*" );
	
	return '{{tutorial_index/}}' unless $pages > 0;
	
	$next = $page + 1;
	$link_next = qq|<p>Go to <a href="tutorial?name=${name}&amp;page=$next">$shorttitle{ $name }, Step $next</a>.| if $page < $pages;
	
	$tutorial_body = "{{tutorial:${name}_$page/}}";
}

$s = qq|<h2>Tutorial: $longtitle{ $name }</h2>

$link_full

$tutorial_body

$link_next

<p><br />

{{tutorial:${name}_${page}_advanced/}}

{{/header_wrap}}
|;


return $s;
