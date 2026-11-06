#!/bin/sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.sh" ]; then
  sh "$SCRIPT_DIR/install.sh"
else
  tmp="/tmp/wanos-minidlna-install.sh"
  if command -v curl >/dev/null 2>&1; then
    curl -fL -o "$tmp" https://wanos.xyz/downloads/apps/minidlna/install.sh
  else
    wget -O "$tmp" https://wanos.xyz/downloads/apps/minidlna/install.sh
  fi
  sh "$tmp"
fi
