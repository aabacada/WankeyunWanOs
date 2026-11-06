#!/bin/sh
set -eu

APP_ID="nut-ups"
APP_DIR="/opt/wanos/apps/${APP_ID}"
SERVICE="/etc/systemd/system/nut-web-panel.service"

log() { printf '%s\n' "[NUT] $*"; }
[ "$(id -u)" = "0" ] || { printf '%s\n' "[NUT] ERROR: 请使用 root 用户卸载。" >&2; exit 1; }

systemctl stop nut-web-panel >/dev/null 2>&1 || true
systemctl disable nut-web-panel >/dev/null 2>&1 || true
rm -f "$SERVICE"
systemctl daemon-reload
rm -rf "$APP_DIR"
log "卸载完成。NUT 系统组件和 /etc/nut 配置已保留，避免影响正在使用的 UPS 服务。"
