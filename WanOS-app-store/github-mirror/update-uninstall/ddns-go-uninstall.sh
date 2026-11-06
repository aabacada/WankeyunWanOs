#!/bin/sh
set -eu

APP_ID="ddns-go"
APP_DIR="/opt/wanos/apps/${APP_ID}"
SERVICE="/etc/systemd/system/${APP_ID}.service"

log() { printf '%s\n' "[DDNS-GO] $*"; }
[ "$(id -u)" = "0" ] || { printf '%s\n' "[DDNS-GO] ERROR: 请使用 root 用户卸载。" >&2; exit 1; }

systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
rm -f "$SERVICE"
systemctl daemon-reload
rm -rf "$APP_DIR"
log "卸载完成。配置数据保留在 /opt/wanos-data/apps/${APP_ID}。"
