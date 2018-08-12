# Mantle Configuration

Mantle loads its configuration variables, functions, and docker-compose configuration in this order (with later items overriding earlier ones):

* `/etc/doco/config` and `~/.config/doco`, if they exist
* The project `.env` file (variables only, docker-compose env file format)
* The project `.envrc` file (regular shell format, functions and variables)
* This file and [Commands.md](Commands.md)
* `/etc/mantlerc.md` and `~/.config/mantlerc.md`, if they exist

After the above files are loaded, the configuration is then modified as follows:

* Servers' `env_files` are prepended by any `MANTLE_DEFAULTS`
* Commands defined by any `MANTLE_PROFILES_*` are executed
* The `PROD_URL`, `DEV_URL`, and `STAGE_URL` variables are exported, normalized to have a trailing `/`
* The `DOCO_PROFILE` is executed, if set

This allows you to define sitewide default profiles for URL routing, database access, `.env` files with passwords, API keys, etc.

```shell
load-mantle-config() {
    if [[ "${!MANTLE_*}" ]]; then
        # For security, MANTLE_* vars can only be set from known/trusted files, so
        # we clear them first, then reload them from the project .env file
        unset "${!MANTLE_@}"
        [[ ! -f "$LOCO_ROOT/.env" ]] || export-env "$LOCO_ROOT/.env"
    fi

    # Load local config files
    for REPLY in /etc/mantlerc.md ~/.config/mantlerc.md; do
        [[ ! -f "$REPLY" ]] || include "$REPLY";
    done

    # Prepend env_files from MANTLE_DEFAULTS
    if [[ "${MANTLE_DEFAULTS-}" ]]; then
        FILTER 'servers(.env_file |= (env.MANTLE_DEFAULTS / ":" + . | map(select(. != "")) ))'
    fi

    # Execute MANTLE_PROFILES_*
    for REPLY in "${!MANTLE_PROFILES_@}"; do eval "${!REPLY}"; done

    # Validate and normalize URLs
    parse-url "$DEV_URL" DEV_URL
    parse-url "$STAGE_URL" STAGE_URL
    parse-url "$PROD_URL" PROD_URL
}
```

## Services

### PHP Servers

```shell
VERSION 3.3
SERVICES dev stage prod
GROUP servers   := dev stage prod
GROUP --default := dev   # default to 'dev' service
```

```yaml
services:
  prod:
    # TODO: image should be a variable, and a git repo+ref should be set
    image: dirtsimple/mantle:latest
    restart: always
    env_file: [ "./deploy/all.env", "./deploy/prod.env" ]
    environment: { WP_HOME: "${PROD_URL}", WP_ENV: "prod" }
  stage:
    image: dirtsimple/mantle:latest
    env_file: [ "./deploy/all.env", "./deploy/stage.env" ]
    environment: { WP_HOME: "${STAGE_URL}", WP_ENV: "stage" }
  dev:
    image: dirtsimple/mantle:latest
    build:
      context: docker
    env_file: [ "./deploy/all.env", "./deploy/dev.env" ]
    environment: { WP_HOME: "${DEV_URL}", WP_ENV: "dev", MODD_CONF: "modd.conf" }
    volumes:
      - .:/var/www/html
      - empty:/var/www/html/deploy
volumes:
  empty:
```

## Profiles

### localdb

If the `localdb` profile is used, a local mysql database container is used, with its data stored under `./deploy/db`.  The PHP servers are configured to depend on it being up, and to use it as their `DB_HOST`.

```yaml !const localdb
# const localdb:
services:
  mysql:
    image: mysql
    restart: always
    volumes:
      - ./deploy/db:/var/lib/mysql

  prod: &localdb
    depends_on: [ "mysql" ]
    environment:
      DB_HOST: "mysql"
  stage:
    <<: *localdb
  dev:
    <<: *localdb
```

```shell
localdb() {
    FILTER 'jqmd_data(localdb)'
    run-dba() {
        REPLY=; [[ -t 0 && -t 1 ]] || REPLY=-T
        doco mysql up -d
        doco -- mysql exec $REPLY mysql -uroot mysql
    }
}
```
### route-via-traefik

The `route-via-traefik` profile configures service routing via [traefik](https://docs.traefik.io), setting labels to enable automatic service detection:

```yaml !const traefik
# const traefik:
services:
  prod: &traefik
    labels:
      traefik.port: "80"
      traefik.enable: "true"
      traefik.frontend.passHostHeader: "true"
  stage:
    <<: *traefik
  dev:
    <<: *traefik
```

```shell
route-via-traefik() {
    FILTER 'jqmd_data(traefik)'
    add-traefik-route prod
    add-traefik-route stage
    add-traefik-route dev
}

add-traefik-route() {
   REPLY="${1^^}_URL"; parse-url "${!REPLY}"; local -n h=REPLY[2] p=REPLY[4] port=REPLY[3]
   [[ ! "$port" ]] || loco_error "$REPLY -- ports not currently supported for traefik routes"
   FILTER "$1"'( .labels |= ( ."traefik.frontend.rule"="'"Host:$h${p:+;PathPrefix:$p/}"'"))'
}
```

### route-nginx-proxy

The `route-via-nginx-proxy` profile configures service routing via [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy), by setting `VIRTUAL_HOST` and `VIRTUAL_PORT` environment vars:

```shell
route-via-nginx-proxy() {
    add-nginx-proxy-route prod
    add-nginx-proxy-route stage
    add-nginx-proxy-route dev
}

add-nginx-proxy-route() {
    REPLY="${1^^}_URL"; parse-url "${!REPLY}"; local -n h=REPLY[2] p=REPLY[4] port=REPLY[3]
    [[ ! "$p$port" ]] || loco_error "$REPLY -- nginx-proxy can't route ports or paths"
    FILTER "$1"'(.environment |= (.VIRTUAL_PORT=80 | .VIRTUAL_HOST="'"$h"'"))'
}
```

### route-via-ports

The `route-via-ports` profile publishes ports using the host:port info from the corresponding URLs.  If the host isn't an IP address, it's converted to one using the first entry from `getent hosts`.

```shell
route-via-ports() {
    add-port-route prod
    add-port-route stage
    add-port-route dev
}

add-port-route() {
    REPLY="${1^^}_URL"; parse-url "${!REPLY}"; local -n h=REPLY[2] p=REPLY[4] port=REPLY[3]
    [[ ! "$p" ]] || loco_error "$REPLY -- port routing can't route paths"
    [[ $h =~ ^[0-9.]+$ ]] || local h=($(getent hosts "$h"))
    FILTER "$1"'(.ports += ["'"${h:+$h:}${port:-80}:80"'"])'
}
```

## Initialization

Commands are implemented in [Commands.md](Commands.md); profiles and other configuration are loaded afterward.

```shell
. .envrc
include Commands.md
load-mantle-config
```

