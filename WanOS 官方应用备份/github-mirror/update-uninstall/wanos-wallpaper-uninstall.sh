#!/bin/sh
set -eu

APP_ID="wanos-wallpaper"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
SERVICE="/etc/systemd/system/$APP_ID.service"

systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
rm -f "$SERVICE"
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
echo "uninstalled"
