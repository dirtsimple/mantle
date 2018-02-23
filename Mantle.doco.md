# Mantle Configuration

## Services

### PHP Servers

```shell
VERSION 2.1
SERVICES dev stage prod
set-alias servers dev stage prod
set-alias cmd-default dev   # default to 'dev' service
```

#### URL Components

The `{DEV,STAGE,PROD}_URL`, variables are split into `*_SCHEME`, `*_HOST`, and `*_PATH` variables, for use by routing profiles.  (So, for example, the `STAGE_HOST` variable will be the host of `STAGE_URL`.)

```shell
split-url() {
    [[ $2 =~ ([^:]+)://([^/]+)(.*/)$ ]] || loco_error "Invalid URL for $1: $2"
    export "$1_SCHEME=${BASH_REMATCH[1]}"
    export "$1_HOST=${BASH_REMATCH[2]}"
    export "$1_PATH=${BASH_REMATCH[3]}"
}

split-url DEV "$DEV_URL"
split-url STAGE "$STAGE_URL"
split-url PROD "$PROD_URL"
```

#### Defaults

```yaml
services:
  prod: &defaults
      image: dirtsimple/php-server
      env_file: [ "./deploy/all.env" ]
      environment:
        RUN_SCRIPTS: "bin/impose"
        PHP_CONTROLLER: "true"
        PHP_MEM_LIMIT: "256"
        PUBLIC_DIR: public
        NGINX_OWNED: public/ext/uploads
        NGINX_WRITABLE: public/ext/uploads
        NGINX_READABLE: .
        NGINX_NO_WRITE: .
        EXCLUDE_PHP: /ext/uploads
        PAGER: "less"
        EXTRA_APKS: "less jq nano bind-tools mysql-client"
  stage:
    <<: *defaults
  dev:
    <<: *defaults
```
#### Environment-Specific Config

```yaml
services:
  prod:
    restart: always
    env_file: [ "./deploy/prod.env" ]
    environment: { WP_HOME: "${PROD_URL}", WP_ENV: "prod" }
  stage:
    env_file: [ "./deploy/stage.env" ]
    environment: { WP_HOME: "${STAGE_URL}", WP_ENV: "stage" }
  dev:
    env_file: [ "./deploy/dev.env" ]
    environment: { WP_HOME: "${DEV_URL}", WP_ENV: "dev" }
    volumes:
      - .:/var/www/html
      - empty:/var/www/html/deploy
volumes:
  empty:
```

## Profiles

Mantle profiles are loaded from any `MANTLE_PROFILE_xxx` vars defined by the `.env`, or set from `/etc/doco/config` or `~/.config/doco`.

```shell
load-mantle-profiles() {
    for REPLY in "${!MANTLE_PROFILES_@}"; do REPLY=${!REPLY}; eval "$REPLY"; done
}
```

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
   local -n h=${1^^}_HOST p=${1^^}_PATH
   FILTER "$1"'( .labels |= ( ."traefik.frontend.rule"="'"Host:$h${p:+;PathPrefix:$p}"'"))'
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
    local -n h=${1^^}_HOST p=${1^^}_PATH
    [[ $p == / ]] || loco_error "nginx-proxy can only route to virtual hosts"
    FILTER "$1"'(.environment |= (.VIRTUAL_PORT=80 | .VIRTUAL_HOST="'"$h"'"))'
}
```

## Initialization

Commands are implemented in [Commands.md](Commands.md); profiles are loaded afterward.

```shell
include Commands.md bin/mantle-commands
load-mantle-profiles
```

