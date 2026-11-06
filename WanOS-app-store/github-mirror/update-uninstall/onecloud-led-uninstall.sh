#!/bin/sh
set -eu
APP_ID="onecloud-led"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
log(){ printf '%s
' "[OneCloud LED] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop onecloud-led-panel >/dev/null 2>&1 || true
systemctl disable onecloud-led-panel >/dev/null 2>&1 || true
rm -f /etc/systemd/system/onecloud-led-panel.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "uninstalled, user config kept"
