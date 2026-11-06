#!/bin/sh
set -eu
APP_ID="xianyu-autodelivery"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
log(){ printf '%s\n' "[闲鱼自动发货] $*"; }
[ "$(id -u)" = "0" ] || { echo "请使用 root 卸载。" >&2; exit 1; }
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/$APP_ID.service"
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then rm -rf "$DATA_DIR"; fi
log "已卸载闲鱼自动发货。数据目录默认保留在 $DATA_DIR，如需删除数据请执行：WANOS_KEEP_APP_DATA=0 sh uninstall.sh"
