#!/bin/sh
set -eu
APP_ID="mariadb-adminer"
APP_DIR="/opt/wanos/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
log(){ printf '%s\n' "[MariaDB] $*"; }
[ "$(id -u)" = "0" ] || { echo "请使用 root 卸载。" >&2; exit 1; }
systemctl stop mariadb-adminer 2>/dev/null || true
systemctl disable mariadb-adminer 2>/dev/null || true
rm -f /etc/systemd/system/mariadb-adminer.service
systemctl daemon-reload 2>/dev/null || true
systemctl stop mariadb 2>/dev/null || systemctl stop mysql 2>/dev/null || true
systemctl disable mariadb 2>/dev/null || systemctl disable mysql 2>/dev/null || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then rm -rf /opt/wanos-data/apps/mariadb-adminer; fi
log "已卸载应用入口。数据库软件包不会自动删除；数据默认保留在 /opt/wanos-data/apps/mariadb-adminer/mysql。"
