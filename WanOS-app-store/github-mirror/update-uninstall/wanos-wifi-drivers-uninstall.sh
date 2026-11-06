#!/bin/sh
set -eu
ROOT="${WANOS_WIFI_DRIVER_ROOT:-/opt/wanos/components/wifi-drivers}"
APP_ID="wanos-wifi-drivers"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PANEL_SERVICE="wanos-wifi-drivers-panel"
if command -v systemctl >/dev/null 2>&1; then
  systemctl disable --now "$PANEL_SERVICE" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/$PANEL_SERVICE.service"
  systemctl daemon-reload >/dev/null 2>&1 || true
fi
rm -rf "$ROOT"
rm -rf "$APP_DIR" "$DATA_DIR"
rm -f /usr/local/bin/wanos-wifi-driver-scan
echo "[WanOS WiFi] driver component metadata removed"
echo "[WanOS WiFi] loaded kernel modules and system firmware are kept for network safety"
