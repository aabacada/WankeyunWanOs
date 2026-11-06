#!/bin/sh
set -eu
APP_ID="nvr-lite"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
log(){ printf '%s\n' "[NVR] $*"; }
[ "$(id -u)" = "0" ] || { echo "[NVR] ERROR: 请使用 root 卸载。" >&2; exit 1; }
systemctl stop nvr-lite-panel.service >/dev/null 2>&1 || true
systemctl stop nvr-lite.service >/dev/null 2>&1 || true
systemctl disable nvr-lite-panel.service nvr-lite.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/nvr-lite-panel.service /etc/systemd/system/nvr-lite.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then
  rm -rf "$DATA_DIR"
  log "已卸载网络摄像机录像，数据也已删除。"
else
  log "已卸载网络摄像机录像。录像和配置默认保留在 $DATA_DIR。"
fi
