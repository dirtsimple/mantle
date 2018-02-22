## `impose`: Impose States on a Wordpress Instance

This is a jqmd script designed to run at startup of a Mantle Wordpress container.  It ensures that a database has been created and the Wordpress core has been installed, before proceeding to load applicable states.

(Note: the `WP_HOME`, `WP_ADMIN_USER`, and `WP_ADMIN_EMAIL` variables must be defined if Wordpress is not already installed.)

```shell
# Run as developer user
[[ $(whoami) == 'developer' ]] || exec as-developer "$0" "$@";

# Exit on error
set -euo pipefail

# Generate initial .lock if not present
[[ -f "$CODE_BASE/composer.lock" ]] || composer install --working-dir="$CODE_BASE" $COMPOSER_OPTIONS

if ! REPLY=$(wp db tables); then
    wp db create
fi

if ! wp core is-installed; then
    wp core install --skip-email \
        --url="$WP_HOME" \
        --title="Placeholder" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_email="$WP_ADMIN_EMAIL" \
        ${WP_ADMIN_PASS:+--admin_password="$WP_ADMIN_PASS"}
fi
```

### Load State JSON

YAML and JSON blocks in state files are processed using a doco-style recursive add:

```jq defs
def jqmd_data($data): . as $orig |
    reduce paths(type=="array") as $path (
        (. // {}) * $data; setpath( $path; ($orig | getpath($path)) + ($data | getpath($path)) )
    );
```

The default state map begins with an empty options map:

```yaml
options: {}
```

which is then processed from PHP to modify wordpress options:

```php
$state = json_decode($args[0], true);
$options = empty($state['options']) ? [] : $state['options'];

foreach ($options as $opt => $new) {
    $old = get_option($opt);
    if (is_array($old) && is_array($new)) $new = array_replace_recursive($old, $new);
    if ($new !== $old) {
        if ($old === false) add_option($opt, $new); else update_option($opt, $new);
    }
}
```

### Process State Files

```shell
for REPLY in ${MANTLE_STATES-}; do source ./states/$REPLY.state; done

REPLY=$(RUN_JQ -c -n)
printf '%s\n' '<?php' "${mdsh_raw_php[@]}" | wp eval-file - "$REPLY"

CLEAR_FILTERS  # prevent auto-run to stdout
```
