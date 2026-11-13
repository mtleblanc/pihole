# Transmission: runs as debian-transmission, only while the drive is mounted,
# only with the kill switch loaded, traffic via the VPN table.

MOUNT_UNIT=$(mount_unit "$MOUNT_POINT")
export MOUNT_UNIT
SETTINGS=/etc/transmission-daemon/settings.json
DOWNLOAD_DIR="${MOUNT_POINT%/}/${TRANSMISSION_DOWNLOAD_SUBDIR}"
DOWNLOAD_DIR="${DOWNLOAD_DIR%/}"

render files/systemd/transmission-homeserver.conf \
    /etc/systemd/system/transmission-daemon.service.d/homeserver.conf
systemctl daemon-reload

# Settings may only be edited while the daemon is stopped (it rewrites the
# file on exit).
systemctl stop transmission-daemon.service

auth=false
[[ -n "${TRANSMISSION_RPC_PASS:-}" ]] && auth=true
host=$(hostname)

jq \
    --slurpfile over files/transmission/settings.json \
    --arg dl "$DOWNLOAD_DIR" \
    --argjson port "$TRANSMISSION_PEER_PORT" \
    --argjson auth "$auth" \
    --arg user "$TRANSMISSION_RPC_USER" \
    --arg pass "${TRANSMISSION_RPC_PASS:-}" \
    --arg hosts "$host,$host.local" \
    '. * $over[0] + {
        "download-dir": $dl,
        "peer-port": $port,
        "rpc-authentication-required": $auth,
        "rpc-username": $user,
        "rpc-host-whitelist": $hosts
     } + (if $auth then {"rpc-password": $pass} else {} end)' \
    "$SETTINGS" >"$SETTINGS.new"
chown --reference="$SETTINGS" "$SETTINGS.new"
chmod 0600 "$SETTINGS.new"
mv "$SETTINGS.new" "$SETTINGS"

if [[ -n "$TRANSMISSION_DOWNLOAD_SUBDIR" ]] && mountpoint -q "$MOUNT_POINT"; then
    install -d -o debian-transmission -g "$MEDIA_GROUP" -m 2775 "$DOWNLOAD_DIR"
fi

# Start with the drive, not at boot.
systemctl disable transmission-daemon.service 2>/dev/null || true
systemctl add-wants "$MOUNT_UNIT" transmission-daemon.service

if mountpoint -q "$MOUNT_POINT"; then
    systemctl start transmission-daemon.service
    info "Transmission web UI: http://${STATIC_IP%/*}:9091/transmission/web/"
else
    warn "Drive not mounted; transmission will start when it is."
fi
