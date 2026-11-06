#!/bin/sh
set -eu
APP_ID="sqlite-phpliteadmin"
APP_DIR="/opt/wanos/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
log(){ printf '%s\n' "[SQLite] $*"; }
[ "$(id -u)" = "0" ] || { echo "请使用 root 卸载。" >&2; exit 1; }
systemctl stop sqlite-phpliteadmin 2>/dev/null || true
systemctl disable sqlite-phpliteadmin 2>/dev/null || true
rm -f /etc/systemd/system/sqlite-phpliteadmin.service
systemctl daemon-reload 2>/dev/null || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then rm -rf /opt/wanos-data/apps/sqlite-phpliteadmin; fi
log "已卸载应用。数据库文件默认保留在 /opt/wanos-data/apps/sqlite-phpliteadmin/databases。"
