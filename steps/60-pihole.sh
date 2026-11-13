# Pi-hole v6. Fresh installs are made unattended by pre-seeding
# /etc/pihole/pihole.toml; settings and lists are then (re)applied on every
# run so the repo stays the source of truth.

if ! command -v pihole >/dev/null; then
    install -d -m 0755 /etc/pihole
    if [[ ! -f /etc/pihole/pihole.toml ]]; then
        cat >/etc/pihole/pihole.toml <<EOF
[dns]
  upstreams = $PIHOLE_UPSTREAMS
  interface = "$LAN_IFACE"
EOF
    fi
    # Read by the installer to seed gravity on first run.
    cp files/pihole/adlists.list /etc/pihole/adlists.list

    installer=$(mktemp)
    curl -fsSL https://install.pi-hole.net -o "$installer"
    bash "$installer" --unattended
    rm -f "$installer"
fi

conf() { pihole-FTL --config "$1" "$2" >/dev/null; }
conf dns.upstreams "$PIHOLE_UPSTREAMS"
conf dns.interface "$LAN_IFACE"
conf dns.listeningMode LOCAL
conf dns.queryLogging true
conf dns.cache.size 10000
conf dns.domainNeeded true
conf dns.bogusPriv true
conf dns.blocking.active "$PIHOLE_BLOCKING_ENABLED"
conf misc.privacylevel 0

pihole setpassword "$PIHOLE_WEB_PASS" >/dev/null

# Lists -> gravity.db (type 3 = regex deny). Additive: entries removed from
# the repo files are not deleted from the database.
sql() { pihole-FTL sqlite3 /etc/pihole/gravity.db "$1"; }
q() { printf "'%s'" "${1//\'/\'\'}"; }
while read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    sql "INSERT OR IGNORE INTO adlist (address, enabled) VALUES ($(q "$url"), 1);"
done <files/pihole/adlists.list
while read -r re; do
    [[ -z "$re" || "$re" == \#* ]] && continue
    sql "INSERT OR IGNORE INTO domainlist (type, domain, enabled) VALUES (3, $(q "$re"), 1);"
done <files/pihole/regex-deny.list

pihole -g >/dev/null
systemctl enable pihole-FTL
info "Pi-hole admin: http://${STATIC_IP%/*}/admin/  (blocking: $PIHOLE_BLOCKING_ENABLED)"
