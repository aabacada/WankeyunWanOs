#!/bin/sh
set -eu
APP_ID="daidai-panel"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-0}"
log(){ printf '%s\n' "[呆呆面板] $*"; }
[ "$(id -u)" = "0" ] || { echo "请使用 root 卸载。" >&2; exit 1; }
systemctl stop daidai-panel.service >/dev/null 2>&1 || true
systemctl disable daidai-panel.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/daidai-panel.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" != "1" ]; then rm -rf "$DATA_DIR"; fi
log "已卸载呆呆面板。"
