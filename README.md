# Literate DevOps for Wordpress

Mantle is a [bedrock](https://github.com/roots/bedrock)-inspired, composer-oriented, docker runtime environment for Wordpress, built on [doco](https://github.com/bashup/doco), [.devkit](https://github.com/bashup/.devkit), and [dirtsimple/php-server](https://github.com/dirtsimple/php-server).

### State Management

In addition to being a convenient template for Wordpress projects, Mantle wraps [imposer](https://github.com/dirtsimple/imposer) with a [bootstrap script](bin/impose) that automatically runs at container start (but can also be run manually) to forcibly set aspects of Wordpress's state (usually in the database).

For example, you can define a [state](states/README.md) file that reads various API keys from the container's environment and then tweaks Wordpress option values to use those keys instead of whatever was in the database before.  Or you can define states that ensure specific plugins are installed or activated or deactivated, specific menus exist, etc.

In other words, states are like "migrations" or Drupal "features", allowing you to expose Wordpress configuration in documented, revision-controlled files, instead of having values appear only inside various database tables.

State files are Markdown documents (`*.state.md` files) that contain blocks of bash, jq, or PHP code, along with YAML or JSON data.  The PHP code embedded in the relevant state files is run using [wp-cli](https://wp-cli.org/), so state file code fragments have full access to the Wordpress API.

### Requirements and Installation

To run Mantle, you'll need git, docker, [jq](https://stedolan.github.io/jq/) 1.5+, and [docker-compose](https://docs.docker.com/compose/), on a machine with bash 4.  ([direnv](https://direnv.net/) is also highly recommended, but not strictly required: without it, you'll need to manually source the `.envrc` in your project directory to be able to access the `doco` and `dk` tools, among others.)

To begin using it, simply:

```bash
$ git clone https://github.com/dirtsimple/mantle myproject
$ cd myproject
$ script/setup
```

This will initialize the project, creating `myproject/.env` and various `myproject/deploy/*.env` files.  Review and edit these files to make sure that things are configured to your needs.

The most critical settings are in the main `myproject/.env` file, where you will need to:

* Set the URLs for your dev, stage, and prod environments
* Determine how those URLs will be routed to their containers (e.g. via port mapping, or a reverse proxy such as [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy) or [Traefik](https://docs.traefik.io/)), and
* Decide whether you'll be using a project-specific mysql server (the default), or a shared one

Once you've configured your project, you can then:

```bash
$ doco dev dba mkuser   # make a dev user w/generated password and db access
$ doco dev up -d        # create and start the dev container
```

(Note: if you're not using direnv and don't have doco installed globally, you'll need to `source .envrc` to add project tools like `doco` to your `PATH`.  This will also override `wp` and `composer` with scripts that run those commands inside the development container, i.e. by aliasing them to `doco wp` and `doco composer`.)

### Project Status

This project is in active development and lacks end-user documentation other than this file.  For developer documentation, see the [Configuration](Mantle.doco.md), [Commands](Commands.md), [impose](bin/impose), and [state files](./states/README.md) docs.
