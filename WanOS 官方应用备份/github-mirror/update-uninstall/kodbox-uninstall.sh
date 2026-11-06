#!/bin/sh
set -eu
APP_ID="kodbox"
APP_DIR="/opt/wanos/apps/$APP_ID"
log(){ printf '%s\n' "[KodBox] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop kodbox.service >/dev/null 2>&1 || true
systemctl disable kodbox.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/kodbox.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "已卸载。数据保留在 /opt/wanos-data/apps/kodbox"
