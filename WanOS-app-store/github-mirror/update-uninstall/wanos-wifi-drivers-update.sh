#!/bin/sh
set -eu
SCRIPT_URL="${WANOS_WIFI_DRIVERS_INSTALL_SCRIPT:-https://wanos.xyz/downloads/apps/wanos-wifi-drivers/install.sh}"
TMP="$(mktemp /tmp/wanos-wifi-drivers-update.XXXXXX.sh)"
cleanup(){ rm -f "$TMP"; }
trap cleanup EXIT
if command -v curl >/dev/null 2>&1; then
  curl -fL --connect-timeout 20 --max-time 300 --retry 3 -o "$TMP" "$SCRIPT_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$TMP" "$SCRIPT_URL"
else
  echo "[WanOS WiFi] missing curl/wget"
  exit 1
fi
head -n 1 "$TMP" | grep -q '^#!' || { echo "[WanOS WiFi] invalid install script"; exit 1; }
sh "$TMP"
