#!/bin/sh
set -eu
APP_ID="oec-led"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
log(){ printf '%s\n' "[OEC/T 指示灯] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop oec-led-panel >/dev/null 2>&1 || true
systemctl disable oec-led-panel >/dev/null 2>&1 || true
rm -f /etc/systemd/system/oec-led-panel.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "uninstalled, user config kept"
