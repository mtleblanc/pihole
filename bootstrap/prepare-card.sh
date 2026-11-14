#!/usr/bin/env bash
# Make a freshly flashed Raspberry Pi OS Lite (64-bit) card reachable over
# SSH as 'pi' with key-only login, without Raspberry Pi Imager's
# customisation (which didn't get applied when we tried it).
#
# Run on a Linux machine with the card inserted and both partitions
# (bootfs, rootfs) mounted:
#     sudo ./bootstrap/prepare-card.sh
#
# What it does, and why:
#  - The image ships a placeholder 'pi' user (uid 1000) with a nologin shell,
#    normally enabled by the first-boot "new user" flow. We enable it
#    directly: bash shell, password locked ('*': key-only), passwordless sudo.
#  - Installs bootstrap/authorized_keys for pi.
#  - Removes the new-user flow's leftovers (SSH banner, console wizard).
#  - Enables sshd via the 'ssh' flag file on bootfs.
# Cloud-init's user-data on bootfs is not used: the image's cloud-init state
# already treats the card as provisioned, so per-instance config is skipped.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

R=$(lsblk -nro LABEL,MOUNTPOINTS | awk '$1=="rootfs"{print $2; exit}')
B=$(lsblk -nro LABEL,MOUNTPOINTS | awk '$1=="bootfs"{print $2; exit}')
[[ -n "$R" && -f "$R/etc/rpi-issue" ]] || { echo "Pi rootfs not mounted (got '$R')" >&2; exit 1; }
[[ -n "$B" && -f "$B/cmdline.txt" ]] || { echo "Pi bootfs not mounted (got '$B')" >&2; exit 1; }
grep -q '^pi:x:1000:' "$R/etc/passwd" || { echo "no placeholder pi user (uid 1000) in image" >&2; exit 1; }
echo "rootfs: $R"
echo "bootfs: $B"

sed -i '/^pi:/s#:/usr/sbin/nologin$#:/bin/bash#' "$R/etc/passwd"
sed -i 's#^pi:[^:]*:#pi:*:#' "$R/etc/shadow"

install -d -o 1000 -g 1000 -m 755 "$R/home/pi"
install -d -o 1000 -g 1000 -m 700 "$R/home/pi/.ssh"
install -o 1000 -g 1000 -m 600 "$HERE/authorized_keys" "$R/home/pi/.ssh/authorized_keys"

echo 'pi ALL=(ALL) NOPASSWD: ALL' >"$R/etc/sudoers.d/010_pi-nopasswd"
chmod 440 "$R/etc/sudoers.d/010_pi-nopasswd"

rm -f "$B/userconf.txt" \
      "$R/etc/ssh/sshd_config.d/rename_user.conf" \
      "$R/etc/systemd/system/multi-user.target.wants/userconfig.service"
touch "$B/ssh"

sync
grep '^pi:' "$R/etc/passwd"
echo "Done. Unmount, boot the Pi with Ethernet, then: ssh pi@raspberrypi.local"
