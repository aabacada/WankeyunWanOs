#!/bin/sh
set -eu
APP_ID="ntfy"
APP_NAME="ntfy 通知服务"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
SERVICE="/etc/systemd/system/$APP_ID.service"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
log(){ printf '%s\n' "[$APP_NAME] $*"; }
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
rm -f "$SERVICE"
systemctl daemon-reload >/dev/null 2>&1 || true
pkill -f "$APP_DIR/bin/ntfy" >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then
  rm -rf "$DATA_DIR"
  log "uninstalled, data removed"
else
  log "uninstalled, data kept: $DATA_DIR"
fi
