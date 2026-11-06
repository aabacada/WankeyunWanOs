#!/bin/sh
set -eu
APP_ID="verysync"
APP_DIR="/opt/wanos/apps/$APP_ID"
log(){ printf '%s\n' "[微力同步] $*"; }
[ "$(id -u)" = "0" ] || { echo "请使用 root 用户卸载。" >&2; exit 1; }
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/$APP_ID.service"
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "卸载完成。配置数据保留在 /opt/wanos-data/apps/$APP_ID。"
