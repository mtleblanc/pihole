#!/usr/bin/env bash
# Provision a fresh Raspberry Pi OS Lite (64-bit) install as the home server:
# Pi-hole, Samba-shared USB drive, and Transmission routed over NordVPN.
#
# Usage: sudo ./install.sh            # run all steps
#        sudo ./install.sh vpn samba  # run only the named steps
#
# Every step is idempotent; re-running is safe.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR
cd "$REPO_DIR"

# shellcheck source=lib/common.sh
source lib/common.sh

[[ $EUID -eq 0 ]] || die "Run with sudo: sudo ./install.sh"
[[ "$(dpkg --print-architecture)" == "arm64" ]] ||
    warn "Expected a 64-bit (arm64) OS, found $(dpkg --print-architecture)."

set -a
# shellcheck source=config.env
source config.env
[[ -f secrets.env ]] && source secrets.env
set +a

# --- Secrets ------------------------------------------------------------
ask_secret() {
    local var="$1" prompt="$2" optional="${3:-}" value
    [[ -n "${!var:-}" ]] && return
    while :; do
        read -r -s -p "$prompt: " value; echo
        [[ -n "$value" || -n "$optional" ]] && break
    done
    printf -v "$var" '%s' "$value"
    export "${var?}"
    SECRETS_CHANGED=1
}

SECRETS_CHANGED=0
ask_secret NORD_USER "NordVPN service username (my.nordaccount.com > Manual setup)"
ask_secret NORD_PASS "NordVPN service password"
ask_secret SMB_PASS "Samba password for user ${PI_USER}"
ask_secret PIHOLE_WEB_PASS "Pi-hole web admin password"
ask_secret TRANSMISSION_RPC_PASS "Transmission web UI password (blank = no auth)" optional
export TRANSMISSION_RPC_USER="${TRANSMISSION_RPC_USER:-transmission}"

if [[ $SECRETS_CHANGED -eq 1 ]]; then
    umask 077
    cat >secrets.env <<EOF
NORD_USER=$(printf '%q' "$NORD_USER")
NORD_PASS=$(printf '%q' "$NORD_PASS")
SMB_PASS=$(printf '%q' "$SMB_PASS")
PIHOLE_WEB_PASS=$(printf '%q' "$PIHOLE_WEB_PASS")
TRANSMISSION_RPC_USER=$(printf '%q' "$TRANSMISSION_RPC_USER")
TRANSMISSION_RPC_PASS=$(printf '%q' "${TRANSMISSION_RPC_PASS:-}")
EOF
    chown "$PI_USER:" secrets.env
    umask 022
    info "Saved credentials to secrets.env (gitignored, mode 600)."
fi

# --- Steps --------------------------------------------------------------
ALL_STEPS=(base network drive vpn transmission samba pihole)
STEPS=("$@")
[[ ${#STEPS[@]} -gt 0 ]] || STEPS=("${ALL_STEPS[@]}")

for step in "${STEPS[@]}"; do
    file=$(ls steps/[0-9][0-9]-"$step".sh 2>/dev/null) || die "Unknown step: $step (have: ${ALL_STEPS[*]})"
    log "Step: $step"
    # shellcheck disable=SC1090
    source "$file"
done

log "Done. Run 'sudo bin/status' to verify."
