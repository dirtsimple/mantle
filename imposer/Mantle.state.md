## Tweaks and Extensions for Mantle Projects

### Automatic DB Initialization

If working with a new database, the Wordpress core may need to be installed, and sample data deleted.  This is done automatically upon `imposer apply`.   (Note that the active container needs to have `WP_ADMIN_USER`, `WP_ADMIN_EMAIL`, and `WP_ADMIN_PASS` environment variables set in order to perform an install.)

```shell
event on "before_apply" mantle-initdb

mantle-initdb() {
	mantle-is-installed && return
	mantle-db-exists || wp db create
	wp core install --skip-email --url="$WP_HOME" --title="Placeholder" \
		--admin_user="$WP_ADMIN_USER" --admin_email="$WP_ADMIN_EMAIL" \
		${WP_ADMIN_PASS:+--admin_password="$WP_ADMIN_PASS"}
	wp post delete 1 2 --force   # delete placeholder posts
}

mantle-db-command() { mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" "$@"; }
mantle-db-query() { echo "$@" | mantle-db-command; }
mantle-is-installed() { mantle-db-query "SHOW CREATE TABLE ${DB_PREFIX-wp_}options" >/dev/null 2>&1; }
mantle-db-exists() { mantle-db-query >/dev/null 2>&1; }
```

### Postmark Integration

Whenever `imposer apply` is run, we also import content from the `content/` directory, which saves a lot of PHP/Wordpress startup overhead that would happen from running it as a separate command.

```shell
require "dirtsimple/postmark"
postmark-content "content"
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

