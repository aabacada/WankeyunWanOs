#!/bin/sh
set -eu
SCRIPT_URL="${EASYTIER_INSTALL_SCRIPT_URL:-https://wanos.xyz/downloads/apps/easytier/install.sh}"
TMP="/tmp/wanos-easytier-install-$$.sh"
if command -v curl >/dev/null 2>&1; then
  curl -fL --connect-timeout 20 --max-time 300 --retry 3 -o "$TMP" "$SCRIPT_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$TMP" "$SCRIPT_URL"
else
  echo "[EasyTier] ERROR: missing curl/wget" >&2
  exit 1
fi
chmod 0755 "$TMP"
sh "$TMP"
rm -f "$TMP"
