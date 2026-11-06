#!/bin/sh
set -eu
APP_ID="xiaoya-alist"
CONTAINER="xiaoya-alist"
APP_DIR="/opt/wanos/apps/$APP_ID"
log(){ printf '%s\n' "[Xiaoya Alist] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop "$APP_ID-panel.service" >/dev/null 2>&1 || true
systemctl disable "$APP_ID-panel.service" >/dev/null 2>&1 || true
systemctl stop "$APP_ID.service" >/dev/null 2>&1 || true
systemctl disable "$APP_ID.service" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/$APP_ID.service" "/etc/systemd/system/$APP_ID-panel.service"
systemctl daemon-reload >/dev/null 2>&1 || true
if command -v docker >/dev/null 2>&1; then docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; fi
rm -rf "$APP_DIR"
log "uninstalled. data kept at /opt/wanos-data/apps/xiaoya-alist"
