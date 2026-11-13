# Shared helpers for install steps. Sourced, not executed.

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx  %s\033[0m\n' "$*" >&2; exit 1; }

# render TEMPLATE DEST [MODE] - substitute ${UPPER_CASE} from the environment.
# Only the braced upper-case form is replaced; $foo, $FOO, ${foo}, ${1:-}
# etc. in templates (shell scripts, nft) survive untouched. So inside a
# template script, write runtime variables without braces or in lower case.
render() {
    local src="$1" dest="$2" mode="${3:-0644}" vars
    vars=$(grep -o '\${[A-Z_][A-Z0-9_]*}' "$src" | sort -u | tr -d '\n' || true)
    install -d "$(dirname "$dest")"
    envsubst "$vars" <"$src" >"$dest.tmp"
    chmod "$mode" "$dest.tmp"
    mv "$dest.tmp" "$dest"
}

# systemd unit name for a mount path, e.g. /srv/media -> srv-media.mount
mount_unit() { systemd-escape --path --suffix=mount "$1"; }

# systemd unit name for a device path
device_unit() { systemd-escape --path --suffix=device "$1"; }

apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}
