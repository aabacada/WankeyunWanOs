#!/bin/sh
set -eu
APP_ID="adguard-home"
APP_DIR="/opt/wanos/apps/$APP_ID"
log(){ printf '%s\n' "[AdGuardHome] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop adguard-home.service >/dev/null 2>&1 || true
systemctl disable adguard-home.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/adguard-home.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "已卸载。配置数据保留在 /opt/wanos-data/apps/adguard-home"
