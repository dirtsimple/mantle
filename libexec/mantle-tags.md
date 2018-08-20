## Site Tags

### Environments

The default environments don't do anything:

```shell
tag.dev() { :; }
tag.prod() { :; }
tag.stage() { :; }
```

### Routing Tags

#### routed-by-traefik

The `routed-by-traefik` tag configures service routing via [traefik](https://docs.traefik.io), setting labels to enable automatic service detection:

```shell
tag.routed-by-traefik() {
	parse-url "$WP_HOME"; local -n h=REPLY[2] p=REPLY[4] port=REPLY[3]
	[[ ! "$port" ]] || fail "$REPLY -- ports not supported for traefik routes" || return
	labels[traefik.frontend.passHostHeader]=true
	labels[traefik.enable]=true
	labels[traefik.port]=80
	labels[traefik.frontend.passHostHeader]=true
	labels[traefik.frontend.rule]="Host:$h${p:+;PathPrefix:$p/}"
}
```

#### routed-by-nginx-proxy

The `routed-by-nginx-proxy` tagconfigures service routing via [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy), by setting `VIRTUAL_HOST` and `VIRTUAL_PORT` environment vars:

```shell
tag.routed-by-nginx-proxy() {
	parse-url "$WP_HOME"; local -n h=REPLY[2] p=REPLY[4] port=REPLY[3]
	[[ ! "$p$port" ]] || fail "$REPLY -- nginx-proxy can't route ports or paths" || return
	env[VIRTUAL_HOST]="$host"
	env[VIRTUAL_PORT]=80
}
```
#### routed-by-port

The `routed-by-port` tag publishes ports using the host:port info from the corresponding URLs.  If the host isn't an IP address, it's converted to one using the first entry from `getent hosts`.

```shell
tag.routed-by-port() {
	parse-url "$WP_HOME"; local -n host=REPLY[2] path=REPLY[4] port=REPLY[3]
	[[ ! "$path" ]] || fail "$REPLY -- port routing can't route paths" || return
	[[ $host =~ ^[0-9.]+$ ]] || local host=($(getent hosts "$host"))
	FILTER '.services[$SERVICE].ports += [%s]' "${host:+$host:}${port:-80}:80"
}
```
### Other Tags

```shell
tag.always-up() { FILTER '.services[$SERVICE].restart = "always"'; }

tag.build-image() { FILTER '.services[$SERVICE].build.context = "docker"'; } # XXX

tag.watch() { env[MODD_CONF]="modd.conf"; }

tag.mount-code() {
	[[ -d "$SERVICE" ]] || (
		git clone -q --depth=1 https://github.com/dirtsimple/mantle-site "./$SERVICE"
		cd "./$SERVICE" && rm -rf .git &&
			git init && git add . && git ci -m "New mantle site"
	)
	volumes+=("./$SERVICE:/var/www/html");
	realpath.relative "$LOCO_PWD/" "$LOCO_ROOT"
	if [[ ${REPLY}/ == "$SERVICE"/* ]]; then
		event on "before commands" GROUP --default /= "$SERVICE"
	fi
}

```

