#!/bin/sh
set -eu

APP_ID="onlyoffice-personal"
APP_DIR="${WANOS_APP_DIR:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA:-/opt/wanos-data/apps/$APP_ID}"

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  systemctl disable --now "$APP_ID.service" 2>/dev/null || true
  rm -f "/etc/systemd/system/$APP_ID.service"
  systemctl daemon-reload 2>/dev/null || true
else
  pkill -f "$APP_DIR/bin/$APP_ID" 2>/dev/null || true
fi

rm -rf "$APP_DIR"
printf '%s\n' "[OnlyOffice Personal] uninstalled. User data kept at $DATA_DIR"
