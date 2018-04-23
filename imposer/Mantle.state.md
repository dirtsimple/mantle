## Tweaks and Extensions for Mantle Projects

### Commands

#### imposer og (options get)

Running `imposer og` ouptuts a paged and colorized JSON map of non-transient options sorted by option name for easy diffing.  This can be helpful in figuring out what you options to put in a state file.


```shell
imposer.og() {
	wp option list --unserialize --format=json --no-transients --orderby=option_name "$@" |
	jq 'map({key:.option_name, value:.option_value}) | from_entries'
}
```

### Wordpress Tweaks

#### Post GUIDs

To avoid changing post guids between dev, staging, and prod, we use proper UUID URNs as guids.  (This also avoids potential leakage of non-public URLs in RSS feeds.)

```php tweak
add_filter( 'wp_insert_post_data', function ( $data, $postarr ) {
	if ( '' === $data['guid'] ) {
		$data['guid'] = wp_slash( 'urn:uuid:' . wp_generate_uuid4() );
	}
	return $data;
}, 10, 2 );
```

