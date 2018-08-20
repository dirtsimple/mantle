## Mantle Tags and Sites

This file defines your mantle sites, and any custom tags you want to create for them.  In the first part of the file, you can include any libraries or site-specific markdown modules that contain your tag definitions:

```shell
source "libexec/mantle-lib.sh"   # load mantle's core functionality

# Load site and user-level configs, if they exist
include-if-exists /etc/mantlerc.md
include-if-exists ~/.config/mantlerc.md
```

### Sites

Sites are defined by calling the shell function `SITE` *servicename url environ tags...* with your desired settings and tags.  You can define sites before the tags have been defined

```shell
VERSION 3.3   # docker-compose format version; must be 2 or higher

# List your sites below as `SITE dirname URL environ tags...`
# SITE dev   https://dev.mysite.com/   dev   routed-by-traefik mount-code watch build-image
# SITE stage https://stage.mysite.com/ stage routed-by-traefik
# SITE prod  https://mysite.com/       prod  routed-by-traefik always-up
```

### Tags and Event Handlers

Define and document your project-specific tag functions here, e.g. `tag.mantle-site` for all sites,  `tag.staging` for staging sites, etc.  You can use shell functions, or jqmd `@func` blocks.  For example, this `yaml @func tag.mantle-site` block defines the template for all sites' service definitions:

```yaml @func tag.mantle-site
# This template will apply to all sites by default, but can be overridden
# by specific tags or sites.  (The jq variables $SERVICE, $WP_HOME and $WP_ENV
# correspond to the first three arguments passed to the SITE function.)

services:
  \($SERVICE):
    image: dirtsimple/mantle:latest
```
You can define additional functions like this to create templates for other tags.  (You must explicitly declare any parameters other than `SITE`, `WP_ENV`, or `WP_HOME`, however.)

If you need to do other things besides set a template, you can define a shell function instead, e.g.:

```shell
tag.example() {
    # this code will be run for all sites tagged `example`, with the service name
    # in $SERVICE and the site URL in $WP_HOME.  In addition, jq filters can access
    # `$SERVICE`.
    return
}
```

Alternately, you can register one or more event handlers with `before-tag` and `after-tag`.  For example, `before-tag "foo" env-file "/etc/foo.env"` will add the named `.env` file to sites tagged `foo`, before the `tag.foo` function or template runs (if it exists).

Tags can include other tags by calling `apply-tags` and the desired tag names, which means you can extend one tag to includes another, e.g. `after-tag production apply-tags always-up` to apply the `always-up` tag to all production sites.

Last, but not least, you can also register handlers for:

* `event on "before site"` -- called at the start of each site definition
* `event on "before site X"` -- called before applying any tags (including `all`) to site `X`
* `site.X` -- if a function named `site.X` exists, it's called after applying tags to site `X`
* `event on "after site X"` -- called after applying all tags (including `all`) to site `X`
* `event on "after site"` -- called at the end of every site defintion

### Environment Variables and .env Files

All of the above handlers can see `$SERVICE`, `$WP_ENV`, and `$WP_HOME`, as well as any variables defined by `.env` or other included config files or .env files.  If environment files are added to a site using `env-file`, the variables they define are added to the `$env[]` associative array, which is visible to site and tag functions and event handlers, and can be modified to change the environment that site's container will use.

A given function or event handler, of course, will only see values in `env[]` that were set or loaded by earlier functions or event handlers.  (e.g. a `tag.X` function can only see variables loaded by the `before tag X` event, or by earlier tags.)

By default, `./deploy/$SERVICE.env` file is added to a service's environment last, after all events and handlers are complete.  If handlers need to access or override its contents, they can load it earlier.  If a `./deploy/@all.env` file exists, it's loaded *first*, at the start of the `before site` event.
