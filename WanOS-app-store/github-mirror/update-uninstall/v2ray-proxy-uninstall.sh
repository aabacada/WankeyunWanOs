#!/bin/sh
set -eu
APP_ID="v2ray-proxy"
APP_DIR="/opt/wanos/apps/$APP_ID"
log(){ printf '%s\n' "[V2Ray] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop v2ray-proxy-panel.service >/dev/null 2>&1 || true
systemctl disable v2ray-proxy-panel.service >/dev/null 2>&1 || true
systemctl stop v2ray-proxy.service >/dev/null 2>&1 || true
systemctl disable v2ray-proxy.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/v2ray-proxy-panel.service /etc/systemd/system/v2ray-proxy.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "已卸载。配置数据保留在 /opt/wanos-data/apps/v2ray-proxy"
