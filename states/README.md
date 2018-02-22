# States Directory

This directory is where state files (`*.state.md`) files go.  State files are jqmd script fragments which can also contain PHP code (in triple-backquoted `php` blocks).  The states listed in a WP instance's `MANTLE_STATES` setting are loaded at container start time, with JSON data being applied as per the [impose command](../impose.md), and PHP code being run afterward.

State files are run in the order specified in `MANTLE_STATES`, but all JSON data is processed before any PHP is run.  A simple example:

```yaml
options:
  some_setting: 23
```

```php
echo "I'm doing something!\n";
```

If this file were named `README.state.md` and `MANTLE_STATES` contained the word `README`, then at container start the Wordpress option `some_setting` would be set to 23 (unless overridden by a later state), and then after all options were processed, `I'm doing something!` would be output to the container's stdout log.

## Compiling States

When `*.state.md` files are changed, you must run `doco compile`  or `dk compile` to rebuild them.  If your project is in active development, you can add `; doco compile` to your `DOCO_PROFILE` to have the files rebuilt whenever a `doco` command is run.