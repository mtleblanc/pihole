# Samba share of the media drive, authenticated as PI_USER.

render files/samba/smb.conf /etc/samba/smb.conf
testparm -s /etc/samba/smb.conf >/dev/null 2>&1 || die "smb.conf failed testparm"

printf '%s\n%s\n' "$SMB_PASS" "$SMB_PASS" | smbpasswd -s -a "$PI_USER" >/dev/null
smbpasswd -e "$PI_USER" >/dev/null

systemctl enable smbd nmbd
systemctl restart smbd nmbd
info "Share: smb://${STATIC_IP%/*}/${SMB_SHARE_NAME} (user ${PI_USER})"
