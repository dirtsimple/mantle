## Services

### PHP Servers

```shell
VERSION 2.1
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
  stage:
    env_file: [ "./deploy/stage.env" ]
  dev:
    env_file: [ "./deploy/dev.env" ]
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
        doco -- mysql exec $REPLY mysql -uroot mysql
    }
}
```
## Commands

Commands are implemented in [Commands.md](Commands.md):

```shell
include Commands.md bin/mantle-commands
```

