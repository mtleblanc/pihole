# Base system: updates, packages, timezone, shared media group.

timedatectl set-timezone "$TIMEZONE"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
apt_install \
    curl ca-certificates jq gettext-base git \
    nftables iproute2 \
    openvpn \
    transmission-daemon \
    samba \
    e2fsprogs

getent group "$MEDIA_GROUP" >/dev/null || groupadd --system "$MEDIA_GROUP"
usermod -aG "$MEDIA_GROUP" "$PI_USER"
usermod -aG "$MEDIA_GROUP" debian-transmission

install -m 0755 bin/status /usr/local/bin/homeserver-status

# SSH: keys only. Refuse to lock ourselves out if the user has no keys.
if [[ -s "$(getent passwd "$PI_USER" | cut -d: -f6)/.ssh/authorized_keys" ]]; then
    printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' \
        >/etc/ssh/sshd_config.d/10-homeserver.conf
    sshd -t && systemctl reload ssh
else
    warn "No authorized_keys for $PI_USER; leaving SSH password login enabled."
fi
# Leftovers of the image's first-boot "new user" flow.
rm -f /etc/ssh/sshd_config.d/rename_user.conf
systemctl disable userconfig.service 2>/dev/null || true
