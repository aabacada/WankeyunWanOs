#!/bin/sh
set -eu
APP_ID="nvr-lite"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
TMP="/tmp/wanos-nvr-lite-install.sh"
URL="https://wanos.xyz/downloads/apps/nvr-lite/install.sh"
log(){ printf '%s\n' "[NVR] $*"; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || { echo "[NVR] ERROR: 请使用 root 更新。" >&2; exit 1; }
if has_cmd curl; then
  curl -fL --connect-timeout 15 --max-time 120 -o "$TMP" "$URL"
elif has_cmd wget; then
  wget -O "$TMP" "$URL"
else
  echo "[NVR] ERROR: 系统缺少 curl/wget，无法下载更新脚本。" >&2
  exit 1
fi
chmod +x "$TMP"
sh "$TMP"
rm -f "$TMP"
log "更新完成。"
