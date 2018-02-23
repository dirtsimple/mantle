# Mantle Configuration

## Services

### PHP Servers

```shell
VERSION 2.1
SERVICES dev stage prod
set-alias servers dev stage prod
set-alias cmd-default dev   # default to 'dev' service
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

Commands are implemented in [Commands.md](Commands.md); profiles are loaded afterward.

```shell
include Commands.md
load-mantle-profiles
```

