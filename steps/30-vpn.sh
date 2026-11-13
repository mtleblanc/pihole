# NordVPN tunnel used only by transmission, plus a kill switch.
#
#  * openvpn runs with route-nopull: the rest of the Pi (Pi-hole, Samba,
#    SSH, apt) uses the normal connection.
#  * Policy routing sends every packet from the debian-transmission user
#    through routing table $VPN_ROUTE_TABLE, whose only route is the tunnel.
#    When the tunnel is down that table holds an "unreachable" route, so
#    the traffic fails instead of falling back to eth0.
#  * An nftables rule rejects anything from debian-transmission that leaves
#    on an interface other than the tunnel (LAN replies excepted), as a
#    second line of defence.
#  * Each (re)start of the tunnel fetches a fresh recommended server from the
#    Nord API, and openvpn exits on persistent failure so systemd restarts
#    it on a new server. (The old setup pinned one server and silently
#    sat disconnected for months.)

VPN_DEV="nordtun"
LIBEXEC="/usr/local/libexec/homeserver"
export VPN_DEV LIBEXEC

# Credentials
install -d -m 0755 /etc/openvpn/client
umask 077
printf '%s\n%s\n' "$NORD_USER" "$NORD_PASS" >/etc/openvpn/client/nordvpn.auth
umask 022

# Scripts
install -d "$LIBEXEC" /etc/homeserver
render files/vpn/nordvpn-update-config "$LIBEXEC/nordvpn-update-config" 0755
render files/vpn/vpn-up "$LIBEXEC/vpn-up" 0755
render files/vpn/vpn-down "$LIBEXEC/vpn-down" 0755
render files/vpn/killswitch "$LIBEXEC/killswitch" 0755
render files/vpn/killswitch.nft /etc/homeserver/killswitch.nft

# Units
render files/systemd/homeserver-killswitch.service /etc/systemd/system/homeserver-killswitch.service
render files/systemd/openvpn-nordvpn.conf \
    /etc/systemd/system/openvpn-client@nordvpn.service.d/homeserver.conf

# Remove the packaged openvpn.service wrapper for /etc/openvpn/*.conf; we use
# the openvpn-client@ template instead.
systemctl disable openvpn.service 2>/dev/null || true

systemctl daemon-reload
systemctl enable --now homeserver-killswitch.service
systemctl enable openvpn-client@nordvpn.service
systemctl restart openvpn-client@nordvpn.service

info "Waiting for tunnel..."
for _ in $(seq 1 30); do
    ip link show "$VPN_DEV" >/dev/null 2>&1 && ip route show table "$VPN_ROUTE_TABLE" | grep -q "dev $VPN_DEV" && break
    sleep 2
done
if ip route show table "$VPN_ROUTE_TABLE" | grep -q "dev $VPN_DEV"; then
    info "Tunnel up via $(grep -m1 '^# server:' /etc/openvpn/client/nordvpn.conf | cut -d' ' -f3)"
else
    warn "Tunnel not up yet. Check: journalctl -u openvpn-client@nordvpn -f"
fi
