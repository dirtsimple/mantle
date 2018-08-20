# Literate DevOps for Wordpress

Mantle is a [bedrock](https://github.com/roots/bedrock)-inspired, [imposer](https://github.com/dirtsimple/imposer) and [postmark](https://github.com/dirtsimple/postmark)-based, composer-oriented, docker-compose runtime environment for Wordpress development, built on [doco](https://github.com/bashup/doco), [.devkit](https://github.com/bashup/.devkit), and [dirtsimple/php-server](https://github.com/dirtsimple/php-server).

### State and Content Management

In addition to being a convenient template for Wordpress projects, Mantle is designed to work with [imposer](https://github.com/dirtsimple/imposer)  and [postmark](https://github.com/dirtsimple/postmark), automatically running `imposer apply` at container start to apply Wordpress configuration from your project source and environment variables, and `wp postmark tree content` to sync Wordpress content from Markdown files with YAML front matter.

(You can also manually run these commands to sync files at other times, or run `script/watch` to watch them for changes and apply them to the development DB.)

#### State Modules

State modules are Markdown documents (`*.state.md` files) that contain blocks of bash, jq, or PHP code, along with YAML or JSON data.  The PHP code embedded in the relevant state files is run using [wp-cli](https://wp-cli.org/), so state file code fragments have full access to the Wordpress API.

State modules are a bit like database "migrations" or Drupal "features", allowing you to expose Wordpress configuration in documented, revision-controlled files, instead of having values appear only inside various database tables.

For example, you can define a [state module](https://github.com/dirtsimple/imposer#how-state-modules-work) that reads various API keys from the container's environment and then tweaks Wordpress option values to use those keys instead of whatever was in the database before.  Or you can define modules that ensure specific plugins are installed or activated or deactivated, specific menus exist, etc.  (State modules can even include `php tweak` code snippets that get automatically combined automatically into a custom plugin, without needing to edit a theme's `functions.php`!)

See the [imposer documentation](https://github.com/dirtsimple/imposer) for more details.

#### Content Files for Posts and Pages

Any `*.md` files in the project's `content/` directory (or any subdirectory thereof) are automatically synced to create Wordpress posts or pages, converting Markdown to HTML for the post body, and using YAML front matter to set metadata like tags, dates, etc.  See the [postmark documentation](https://github.com/dirtsimple/postmark) for more details, and/or `wp help postmark`.

### Requirements and Installation

To run Mantle, you'll need git, docker, [jq](https://stedolan.github.io/jq/) 1.5+, and [docker-compose](https://docs.docker.com/compose/), on a machine with bash 4.4.  ([direnv](https://direnv.net/) is also highly recommended, but not strictly required: without it, you'll need to manually source the `.envrc` in your project directory to be able to access the `doco` and `dk` tools, among others.)  You will also need a tool for YAML to JSON conversion, such as [this one](https://github.com/bronze1man/yaml2json), PyYAML, or [yaml2json.php](https://packagist.org/packages/dirtsimple/yaml2json).

To begin using it, simply:

```bash
$ git clone https://github.com/dirtsimple/mantle myproject
$ cd myproject
$ script/setup
```

This will initialize the project, creating `.env` and `myproject.doco.md` files for you to edit.  (You can rename the `.doco.md` file, so long as it still ends in `.doco.md`).  Review and edit these files to make sure that things are configured to your needs.

The most critical settings are in the `.doco.md` file, where you will need to:

* Set the URLs and environments for your sites
* Determine how those URLs will be routed to their containers (e.g. via port mapping, or a reverse proxy such as [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy) or [Traefik](https://docs.traefik.io/)), and
* Decide whether you'll be using a project-specific mysql server (the default), or a shared one

Once you've configured your project, you can then `doco up` to create your sites.  Sites tagged with `mount-code` will automatically create a subdirectory named for that site, with a spun-off clone of [mantle-site](https://github.com/dirtsimple/mantle-site) in it for you to edit.  The subdirectory will be a new git repo with one commit, initializing the project.  From there you can configure other things at will.

(Note: if you're not using direnv and don't have doco installed globally, you'll need to either `source .envrc` in a subshell manually or run `script/console` to do it automatically.  This will add project tools like `doco` to your `PATH`, which in turn will provide `wp` , `imposer`, and `composer` scripts that run those commands inside the default container, i.e. by aliasing them to `doco wp` and `doco composer`.)

### Project Status

This project is in active development and lacks end-user documentation other than this file.  For developer documentation, see the [mantle-lib](https://github.com/dirtsimple/mantle-lib) and [mantle-site](https://github.com/dirtsimple/mantle-site) projects.