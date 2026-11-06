#!/bin/sh
set -eu
URL="${WANOS_AI_INSTALL_URL:-https://wanos.xyz/downloads/apps/wanos-ai-assistant/install.sh}"
TMP="$(mktemp /tmp/wanos-ai-assistant-update.XXXXXX.sh)"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$TMP"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$TMP" "$URL"
else
  echo "missing curl/wget" >&2
  exit 1
fi
sh "$TMP"
