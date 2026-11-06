#!/bin/sh
set -eu
APP_ID="xunlei"
APP_NAME="Xunlei"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
SERVICE="/etc/systemd/system/$APP_ID.service"
log(){ printf '%s
' "[$APP_NAME] $*"; }
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
rm -f "$SERVICE"
systemctl daemon-reload >/dev/null 2>&1 || true
pkill -f "$APP_DIR/bin/xunlei" >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then
  rm -rf "$DATA_DIR"
  log "uninstalled, data removed"
else
  log "uninstalled, data kept: $DATA_DIR"
fi
