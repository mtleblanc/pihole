# Static IP on the LAN interface (Pi-hole must not move).
# Raspberry Pi OS Bookworm+ uses NetworkManager.

con=$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$LAN_IFACE" '$2==d{print $1; exit}')
if [[ -z "$con" ]]; then
    con=$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2 ~ /ethernet/{print $1; exit}')
fi
[[ -n "$con" ]] || die "No NetworkManager connection found for $LAN_IFACE"

current=$(nmcli -g ipv4.addresses connection show "$con")
if [[ "$current" == "$STATIC_IP" ]]; then
    info "$LAN_IFACE ($con) already at $STATIC_IP"
else
    info "Setting $con to $STATIC_IP via $GATEWAY"
    # The Pi itself resolves through Pi-hole, with a public fallback.
    nmcli connection modify "$con" \
        ipv4.method manual \
        ipv4.addresses "$STATIC_IP" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "127.0.0.1 8.8.8.8" \
        ipv4.ignore-auto-dns yes
    warn "IP changes to ${STATIC_IP%/*} on next reconnect/reboot; an SSH session on another IP will drop."
    nmcli connection up "$con" || true
fi
