#!/bin/sh
set -eu

APP_ID="quark-auto-save"
APP_NAME="Quark Auto Save"
CONTAINER="${QUARK_AUTO_SAVE_CONTAINER:-wanos-quark-auto-save}"
IMAGE="${QUARK_AUTO_SAVE_IMAGE:-cp0204/quark-auto-save:latest}"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
KEEP_IMAGE="${WANOS_KEEP_DOCKER_IMAGE:-0}"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }

systemctl stop "$APP_ID.service" >/dev/null 2>&1 || true
systemctl disable "$APP_ID.service" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/$APP_ID.service"
systemctl daemon-reload >/dev/null 2>&1 || true

if command -v docker >/dev/null 2>&1; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  if [ "$KEEP_IMAGE" != "1" ]; then docker rmi "$IMAGE" >/dev/null 2>&1 || true; fi
fi

rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then
  rm -rf "$DATA_DIR"
  log "uninstalled, data removed"
else
  log "uninstalled, data kept: $DATA_DIR"
fi
