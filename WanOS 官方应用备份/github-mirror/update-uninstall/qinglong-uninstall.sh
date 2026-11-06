#!/bin/sh
set -eu
APP_ID="qinglong"
CONTAINER="${QINGLONG_CONTAINER:-wanos-qinglong}"
IMAGE="${QINGLONG_IMAGE:-whyour/qinglong:2.17.7-linuxarmv7}"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-0}"
KEEP_IMAGE="${WANOS_KEEP_DOCKER_IMAGE:-0}"
log(){ printf '%s
' "[青龙面板] $*"; }
[ "$(id -u)" = "0" ] || { echo "请使用 root 卸载。" >&2; exit 1; }
systemctl stop qinglong.service >/dev/null 2>&1 || true
systemctl disable qinglong.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/qinglong.service
systemctl daemon-reload >/dev/null 2>&1 || true
if command -v docker >/dev/null 2>&1; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  if [ "$KEEP_IMAGE" != "1" ]; then docker rmi "$IMAGE" >/dev/null 2>&1 || true; fi
fi
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" != "1" ]; then rm -rf "$DATA_DIR"; fi
log "已卸载青龙面板。"
