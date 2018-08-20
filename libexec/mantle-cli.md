# Mantle CLI

## Developer Commands

These commands execute their arguments inside exactly one service container, as the developer user.  If no services are specified, the default is to run against the `dev` container.

### asdev

Run the specified command line inside the container using the `as-developer` tool.

```shell
doco.asdev() {
	require-services 1 asdev exec || return
	local target=$REPLY
	target "$target" is-started || doco up -d
	set -- as-developer "$@"
	[[ -t 1 ]] || set -- -T "$@"
	doco "$target" exec "$@"
}
```

### wp

```shell
doco.wp() { doco asdev env PAGER='less' LESS=R wp "$@"; }
```

### db

```shell
doco.db() { doco wp db "$@"; }
```

### composer

```shell
doco.composer() { doco asdev composer "$@"; }
```

### imposer

```shell
doco.imposer() { doco asdev imposer "$@"; }
```

## Color and Paging

We exetend the doco `config` and `jq` command to provide paged and colorized output, using .devkit's `tty` module.  The pager and YAML colorizer can be set using `DOCO_PAGER` and `DOCO_YAML_COLOR`.

```shell
# color & paging
tty_prefix=DOCO_
source .devkit/modules/tty
doco.config()  { tty pager colorize-yaml -- compose-untargeted config  "$@"; }
colorize-yaml() { tty-tool YAML_COLOR pygmentize -f 256 -O style=igor -l yaml; }
```