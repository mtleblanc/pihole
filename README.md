# Home server (Raspberry Pi 4)

Reproducible setup for the Pi that provides:

| Service | What it does | Where |
|---|---|---|
| **Pi-hole** (v6) | Network DNS + ad blocking | `http://192.168.1.80/admin/` |
| **Samba** | Shares the USB drive | `smb://192.168.1.80/MyMedia` |
| **Transmission** | Torrents to the USB drive, **only via NordVPN** | `http://192.168.1.80:9091/transmission/web/` |
| **USB drive** | Mounts on plug-in, unmounts on removal | `/srv/media` |

## Rebuild from scratch

1. **Flash** *Raspberry Pi OS Lite (64-bit)* with Raspberry Pi Imager. In its
   settings: hostname `raspberrypi`, your username, SSH with your public key,
   and Wi-Fi if wanted. Plug in Ethernet.
2. **Boot and clone**:
   ```sh
   ssh <user>@raspberrypi.local
   sudo apt update && sudo apt install -y git
   git clone https://github.com/mtleblanc/pihole.git && cd pihole
   ```
3. **Credentials**: either `cp secrets.env.example secrets.env` and fill it in,
   or let the installer prompt for each one. You need:
   - NordVPN **service credentials** (my.nordaccount.com → NordVPN →
     *Manual setup*), which are not your login email and password
   - a Samba password, a Pi-hole admin password, and optionally a Transmission
     web UI password
4. **Install**: `sudo ./install.sh`
5. **Verify**: `sudo homeserver-status`

Site settings (IP, drive UUID, mount point, VPN country, …) are in
[`config.env`](config.env). Each step is idempotent, so after editing config
you can re-run all of it or just one step, e.g. `sudo ./install.sh vpn`.
Steps: `base network drive vpn transmission samba pihole`.

## How it works

### Transmission over VPN (with kill switch)
Only Transmission uses the VPN; everything else on the Pi uses the normal
connection.

- OpenVPN (`openvpn-client@nordvpn`) runs with `route-nopull`, so it does not
  take over the Pi's default route.
- Transmission runs as `debian-transmission`. Policy-routing rules send that
  user's traffic to routing table 100. That table's default route is the tunnel
  while it's up and `unreachable` while it's down.
- An nftables rule (`homeserver_killswitch`) rejects anything from that user
  leaving on any interface other than the tunnel, except LAN traffic (so the
  web UI works).
- `transmission-daemon` *requires* the kill switch unit, so it can't run
  without it.
- Each tunnel start fetches a currently recommended server from Nord's API
  (`nordvpn-update-config`). If the tunnel fails, OpenVPN exits and systemd
  restarts it on a different server.

Check with `sudo homeserver-status`: the "transmission" public IP must differ
from the "pi" one.

### USB drive hotplug
`/etc/systemd/system/srv-media.mount` is enabled as *WantedBy* the disk's
device unit, so it mounts whenever the disk appears and unmounts when it
disappears. `transmission-daemon` is bound to the mount: it starts when the
drive is mounted and stops when it's removed. The empty mountpoint is
`chattr +i`, so nothing can write to the SD card while the drive is
missing.

To eject cleanly before unplugging:
```sh
sudo systemctl stop srv-media.mount   # also stops transmission
```

### Samba
One share, `MyMedia`, for the login user. Files are group-owned by `media`
(shared with Transmission). `vfs_fruit` keeps macOS metadata in extended
attributes instead of littering `._*` files.

### Pi-hole
Installed unattended (v6). Upstreams, blocklists (`files/pihole/adlists.list`)
and regex rules (`files/pihole/regex-deny.list`) come from the repo and are
re-applied on each run.

## Repo layout
```
install.sh          entry point; loads config.env + secrets.env, runs steps/
config.env          site settings (committed)
secrets.env         credentials (gitignored; see secrets.env.example)
steps/NN-*.sh       one idempotent step per feature
files/              templates (${VAR} substituted at install time)
bin/status          health check → /usr/local/bin/homeserver-status
```
