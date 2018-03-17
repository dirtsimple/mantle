# Imposer States Directory

This directory is where state files (`*.state.md`) files go.  State files are [jqmd](https://github.com/bashup/jqmd) script fragments which can also contain PHP code (in triple-backquoted `php` blocks).  The states listed in a WP instance's `MANTLE_STATES` setting are loaded at container start time, with JSON data being applied as per the [imposer command](https://github.com/dirtsimple/imposer), and PHP code being run afterward.

State files are run in the order specified in `MANTLE_STATES`, but all JSON data is processed before any PHP is run.  A simple example:

```yaml
options:
  some_setting: 23
```

```php
echo "I'm doing something!\n";
```

If this file were named `README.state.md` and `MANTLE_STATES` contained the word `README`, then at container start the Wordpress option `some_setting` would be set to 23 (unless overridden by a later state), and then after all options were processed, `I'm doing something!` would be output to the container's stdout log.

Generally speaking, `MANTLE_STATES` should only be set once, in (`deploy/all.env`) so it will apply to all containers.  (It can be overridden in an individual container's `.env` file, however, if there is a need to have different states during development or deployment.  But it is usually better to use the same states for all containers, with the state files using other variables to do things that are container-specific.)
