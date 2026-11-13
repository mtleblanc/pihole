# USB drive: hotplug mount/unmount via systemd.
#
# The mount unit is WantedBy the disk's device unit, so systemd mounts it
# whenever the disk appears (boot or hotplug), and BindsTo the device so it
# is unmounted (and dependents stopped) when the disk disappears.
# The empty mountpoint is made immutable so nothing can write to the SD card
# by accident while the drive is absent.

DRIVE_DEV="/dev/disk/by-uuid/$DRIVE_UUID"
MOUNT_UNIT=$(mount_unit "$MOUNT_POINT")
DEVICE_UNIT=$(device_unit "$DRIVE_DEV")
export DRIVE_DEV MOUNT_UNIT DEVICE_UNIT

if ! mountpoint -q "$MOUNT_POINT"; then
    install -d -m 0755 "$MOUNT_POINT"
    chattr +i "$MOUNT_POINT"
fi

render files/systemd/media.mount "/etc/systemd/system/$MOUNT_UNIT"
systemctl daemon-reload
systemctl enable "$MOUNT_UNIT"

if [[ -e "$DRIVE_DEV" ]]; then
    systemctl start "$MOUNT_UNIT"
    # Top-level only; files already on the drive keep their ownership.
    chgrp "$MEDIA_GROUP" "$MOUNT_POINT"
    chmod 2775 "$MOUNT_POINT"
    info "Mounted $DRIVE_DEV at $MOUNT_POINT"
else
    warn "Drive $DRIVE_UUID not connected; it will mount automatically when plugged in."
fi
