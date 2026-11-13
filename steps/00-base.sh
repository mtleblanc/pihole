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
