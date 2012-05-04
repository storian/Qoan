my( $s, $sample_name );

$sample_name = $params;

$s = qq|<div class="code">
{{code_sample_$sample_name/}}
</div>|;

$s;
