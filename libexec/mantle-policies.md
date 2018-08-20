## Policies

Policies are singletons that control required aspects of a mantle project, such as database administration, credential assignment, and routing.  For each policy type, there is a variable indicating which policy is actually in use, and it becomes read-only once the policy is selected, which happens at project finalization if the policy isn't used before that point.

```shell
event on "finalize project" event resolve "select policies"

policy() {
	policy-type-exists "$1" || fail "Policy type '$1' doesn't exist" || return
	"policy.$@"
}

policy-type-exists() { fn-exists "policy.$1"; }

policy-type() {
	! policy-type-exists "$1" || fail "policy type '$1' already defined" || return
	event quote "$@"
	eval "policy.$1() { select-policy $REPLY && policy.$1 \"\$@\"; }"
	event on "select policies" select-policy "$@"
}

select-policy() {
	policy-type-exists "$1" || fail "policy type '$1' doesn't exist" || return
	local -n selected=$2; [[ ${selected+_} ]] || selected=$3
	fn-exists "$1.$selected" || fail "$1 policy '$selected' does not exist" || return
	readonly "$2"; eval "policy.$1() { $1.$selected \"\$@\"; }"
	"$1.$selected" init  # initialize the policy
}
```

### The Policy Base Class

`policy` is the base class for all policies, providing default implementations of the methods shared by all policy types.  In particular, policies have:

* an `init` that's called when the policy is selected
* a `project-config` that's called by the default `init`
* `before-site` and `after-site` methods that get called around each site definition
* a `new-site` that's called when a project's deployment `.env` is created

```shell
policy::init() {
	this project-config
	event on "before site"      "$this" before-site
	event on "after site"       "$this" after-site
	event on "new site"         "$this" new-site
	event on "finalize project" "$this" finalize-config
}

policy::project-config() { :; }
policy::finalize-config() { :; }
policy::before-site() { :; }
policy::after-site() { :; }
```

## Database Administration

The DBA policy is set using the `DBA_POLICY` variable, and it defaults to the `project-db` policy.  The base class is `dba-policy`, which understands how to create and drop users and generate database passwords.

```shell
doco.dba() { policy dba dba-command; }  # simple CLI

policy-type dba DBA_POLICY project-db

gen-dbpass() { openssl rand -base64 18; }
sql-escape() { set -- "${@//\\/\\\\}"; set -- "${@//\'/\\\'}"; REPLY=("$@"); }

dba-policy::new-site() {
	.env -f "${DEPLOY_ENV}" generate DB_PASSWORD gen-dbpass
	! .env parse DB_USER DB_NAME DB_HOST DB_PASSWORD || local "${REPLY[@]}"
	event on "before commands" "$this" mkuser "$DB_NAME" "$DB_USER" "$DB_PASSWORD"
}

dba-policy::mkuser() {
	sql-escape "$2" "$3"
	printf \
        "GRANT ALL PRIVILEGES ON \`%s\`.* TO '%s'@'%%' IDENTIFIED BY '%s'; FLUSH PRIVILEGES;" \
        "$1" "${REPLY[0]}" "${REPLY[1]}" | this dba-command
}

dba-policy::dropuser() {
	sql-escape "$DB_USER"
	printf "DROP USER '%s'@'%%'; FLUSH PRIVILEGES;" "$REPLY" | this dba-command
}

dba-policy::dba-command() { fail "policy '$this needs a dba-command method"; }
```

### The project-db policy

The `project-db` dba policy implements a project-local mysql service, making each site depend on it.  A newly generated database's name and user ID are the site's service name.

```shell
dba.project-db() { local this=$FUNCNAME __mro__=(project-db dba-policy policy); this "$@"; }

project-db::finalize-config() {
	# Make sure we have a root password
	this .env generate MYSQL_ROOT_PASSWORD gen-dbpass
}

project-db::.env() { .env -f ./deploy/mysql.env "$@"; }

project-db::up() {
	! target mysql is-started || return 0

	if target mysql is-created; then
		doco -- mysql start
	else
		doco -- mysql up -d
		while [[ ! -f deploy/db/client-key.pem ]]; do sleep .1; done
		while read -r -t 2; do :; done < <(doco -- mysql tail)
	fi

	this .env parse MYSQL_ROOT_PASSWORD ||
		fail "./deploy/mysql.env is missing its password" || return
	local "${REPLY[@]}"  # read password

	doco -- mysql exec -T mysql_config_editor set --skip-warn -G auto \
		-h localhost -u root -p <<<"$MYSQL_ROOT_PASSWORD" 2>/dev/null
}

project-db::dba-command() {
	this up; REPLY=; [[ -t 0 && -t 1 ]] || REPLY=-T   # don't use pty unless interactive
	doco -- mysql exec $REPLY mysql --login-path=auto mysql
}

project-db::new-site() {
	.env -f "$DEPLOY_ENV" set +DB_USER="$SERVICE" +DB_NAME="$SERVICE" +DB_HOST=mysql
	dba-policy::new-site "$@"
}
```

The database is implemented as an auto-restarting service named `mysql`, with its data stored in `./deploy/db`:

```yaml @func project-db::project-config
# project-db::project-config
services:
  mysql:
    image: mysql
    restart: always
    env_file: ./deploy/mysql.env
    volumes:
      - ./deploy/db:/var/lib/mysql
```

Each site is marked as dependent on the mysql service, so it will start if they start.

```yaml @func project-db::before-site
# project-db::before-site
services:
  \($SERVICE):
    depends_on: [ mysql ]
```

