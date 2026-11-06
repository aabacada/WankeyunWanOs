#!/bin/sh
set -eu
APP_ID="webdav-server"
APP_DIR="/opt/wanos/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
log(){ printf '%s
' "[WebDAV] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop webdav-server-panel.service >/dev/null 2>&1 || true
systemctl stop webdav-server.service >/dev/null 2>&1 || true
systemctl disable webdav-server-panel.service >/dev/null 2>&1 || true
systemctl disable webdav-server.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/webdav-server-panel.service /etc/systemd/system/webdav-server.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then rm -rf /opt/wanos-data/apps/$APP_ID; fi
log "已卸载 WebDAV 应用。数据默认保留在 /opt/wanos-data/apps/webdav-server。"
