## Mantle Core API

### Site Definition

#### `SITE`

```shell
SITE() {
	# Add to the --sites group and create the service target
	GROUP --sites += "$1"

	# parse and save the normalized URL
	parse-url "$2" || return; set -- "$1" "$REPLY" "${@:3}"

	# prep now, run later
	if-not-in created_sites "$1" \
		event on "finalize project" build-service "$1" mantle-site "$@"

	event has "finalize project" build-service "$1" mantle-site "$@" ||
		fail "site '$1' has already been defined with different parameters"
}

```
#### Tag Registration and Application

```shell
declare -gA TAGGED

before-tag() { event on "before tag $1" "${@:2}"; }
after-tag()  { event on  "after tag $1" "${@:2}"; }

tag-exists() { fn-exists "tag.$1" || event has "before tag $1" || event has "after tag $1"; }
apply-tags() { for REPLY; do if-not-in TAGGED["$SERVICE"] "$REPLY" __apply_tag "$REPLY"; done; }

__apply_tag() {
	tag-exists "$1" ||
		fail "Undefined tag '$1' for '$SERVICE'${tag_chain:+ (via $tag_chain)}" || return
	local tag_chain=${tag_chain:+$tag_chain, }$1
	event emit "before tag $1"; ! fn-exists "tag.$1" || "tag.$1"; event emit "after tag $1"
}

```

#### Site Tags and Configuration

```shell
event on "before site" env-file -q ./deploy/@all.env

mantle-site() {
	local -r WP_HOME=$2 WP_ENV=$3 DEPLOY_ENV="./deploy/$1.env"
	image="dirtsimple/mantle2:latest"
	expose WP_HOME WP_ENV WP_ADMIN_USER WP_ADMIN_PASS
	env[WP_ADMIN_EMAIL]=${WP_ADMIN_EMAIL:-$USER@$HOSTNAME}

	event emit "before site"
	event emit "before site $1"
	apply-tags mantle-site "${@:3}"  # WP_ENV is also a tag
	! fn-exists "site.$1" || "site.$1"
	event emit "after site"
	event emit "after site $1"

	env-file -q "$DEPLOY_ENV"
	[[ -f "$DEPLOY_ENV" ]] || new-site "$@"
}

```

#### Handling Newly-Created Sites

```shell
new-site() {
	[[ -d deploy ]] || mkdir deploy || exit
	.env -f "$DEPLOY_ENV" puts "# $SERVICE environment"
	env-file "$DEPLOY_ENV"

	# don't allow config changes in new-site event
	readonly image env labels volumes env_files
	event emit "new site" "$@"
}

event on "new site" generate-wp-keys

generate-wp-keys() {
	set -- AUTH SECURE_AUTH LOGGED_IN NONCE
	.env -f "$DEPLOY_ENV"
	while (($#)); do
		.env generate "$1_KEY"  openssl rand -base64 48
		.env generate "$1_SALT" openssl rand -base64 48
		shift
	done
}

```

### Service Building

```shell
build-service() {
	SERVICES "$1"
	local -r SERVICE=$1; local image env_files=() volumes=(); local -A env labels
	FILTER "( . "; APPLY . SERVICE
	"${@:2}"

	FILTER '( .services[$SERVICE] |= ( .'
	put-string image       ${image+"$image"}
	put-map    environment env
	put-map    labels      labels
	put-list   volumes     "${volumes[@]}"
	FILTER ". )))"
	#event on "finalize project" eval 'echo "$jqmd_filters"'
}

put-map()    {                       JSON-MAP "$2";      put-struct "$1" "$REPLY"; }
put-list()   { (($#>1)) || return 0; JSON-LIST "${@:2}"; put-struct "$1" "$REPLY"; }
put-string() { (($#>1)) || return 0; JSON-QUOTE "$2";    put-struct "$1" "$REPLY"; }
put-struct() { FILTER ".$1 |= jqmd_data($2 | mantle::uninterpolate)"; }

expose() { for REPLY; do [[ ! ${!REPLY+_} ]] || env["$REPLY"]=${!REPLY}; done; }

env-file() {
	local q='' f; [[ ${1-} != -q ]] || { q=y; shift; }
	for f; do
		[[ $f != *%s.env ]] || f=${f/%"%s.env"/"$SERVICE.env"}
		if [[ -f "$f" ]]; then
			if-new-in-array env_files "$f" load-env "$f"
		elif [[ ! $q ]]; then
			fail ".env file $f does not exist" || return
		fi
	done
}

load-env() {
	! .env -f "$1" parse ||
		for REPLY in "${REPLY[@]}"; do env["${REPLY%%=*}"]="${REPLY#*=}"; done
}
```

### Misc. Configuration

```shell
fn-exists .env || source dotenv

doco-target::is-created() {
	project-name "$TARGET_NAME"; [[ "$(docker ps -aqf name="$REPLY")" ]]
}
doco-target::is-started() {
	project-name "$TARGET_NAME"; [[ "$(docker ps -qf name="$REPLY")" ]]
}

include-if-exists() { while (($#)); do [[ ! -f "$1" ]] || include "$1"; shift; done; }

if-not-in() { local -n v=$1; [[ ${v-} != *"<$2>"* ]] || return 0; v+="<$2>"; "${@:3}"; }

if-new-in-array() {
	local -n v=$1; [[ "< ${v[*]/%/ ><} " != *"< $2 >"* ]] || return 0; v+=("$2"); "${@:3}"
}
```

### URL Parsing

The `parse-url` function parses an absolute URL in `$1` and sets `REPLY` to an array containing:

* The URL normalized to include a trailing `/`
* The URL scheme
* The URL host
* The URL port (or an empty string)
* The URL path (or an empty string if no non-`/` path was included)

```shell
parse-url() {
	[[ $1 =~ ([^:]+)://([^/:]+)(:[0-9]+)?(/.*)$ ]] || loco_error "Invalid site URL: $1"
	REPLY=("${BASH_REMATCH%/}/" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]#:}"  "${BASH_REMATCH[4]%/}")
}
```

### jq functions

```coffeescript +DEFINE
# This code is actually jq, not coffeescript, but github and my editor don't speak jq :(
def mantle::uninterpolate:
	# escape '$' to prevent interpolation
    if type == "string" then
        . / "$" | map (. + "$$") | add | .[:-2]
    elif type == "array" then
        map(mantle::uninterpolate)
    elif type == "object" then
        to_entries | map( .value |= mantle::uninterpolate ) | from_entries
    else .
    end
;
```

