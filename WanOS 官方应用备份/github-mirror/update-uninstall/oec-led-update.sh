#!/bin/sh
set -eu
SCRIPT_URL="${OEC_LED_INSTALL_URL:-https://wanos.xyz/downloads/apps/oec-led/install.sh}"
TMP="/tmp/oec-led-install.sh"
if command -v curl >/dev/null 2>&1; then
  curl -fL --connect-timeout 20 --retry 2 -o "$TMP" "$SCRIPT_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$TMP" "$SCRIPT_URL"
else
  echo "missing curl/wget" >&2
  exit 1
fi
chmod +x "$TMP"
sh "$TMP"
