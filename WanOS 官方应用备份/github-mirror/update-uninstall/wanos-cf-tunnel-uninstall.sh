#!/bin/sh
set -eu

APP_ID="wanos-cf-tunnel"
APP_NAME="WanOS Cloudflare Tunnel"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
SERVICE="/etc/systemd/system/$APP_ID.service"
PID_FILE="$DATA_DIR/$APP_ID.pid"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

if has_cmd systemctl; then
  systemctl stop "$APP_ID" >/dev/null 2>&1 || true
  systemctl disable "$APP_ID" >/dev/null 2>&1 || true
fi
if [ -s "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" >/dev/null 2>&1 || true
  rm -f "$PID_FILE"
fi
pkill -f "$APP_DIR/bin/wanos-cf-tunnel" >/dev/null 2>&1 || true
rm -f "$SERVICE"
if has_cmd systemctl; then systemctl daemon-reload >/dev/null 2>&1 || true; fi
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then
  rm -rf "$DATA_DIR"
  log "uninstalled, data removed"
else
  log "uninstalled, data kept: $DATA_DIR"
fi
