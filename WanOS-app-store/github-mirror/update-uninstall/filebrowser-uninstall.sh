#!/bin/sh
set -eu
log(){ echo "[Filebrowser] $*"; }

SERVICE_FILE="/etc/systemd/system/filebrowser.service"
APP_DIR="${WANOS_APP_INSTALL_DIR:-${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/filebrowser}}"
DATA_DIR="${WANOS_APP_DATA_DIR:-${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/filebrowser}}"

if [ -f "$SERVICE_FILE" ]; then
  exec_start="$(sed -n 's/^ExecStart=//p' "$SERVICE_FILE" | head -n 1 || true)"
  work_dir="$(sed -n 's/^WorkingDirectory=//p' "$SERVICE_FILE" | head -n 1 || true)"
  case "$exec_start" in
    */bin/filebrowser*) APP_DIR="${exec_start%%/bin/filebrowser*}" ;;
  esac
  if [ -n "$work_dir" ]; then
    DATA_DIR="$work_dir"
  fi
fi

systemctl stop filebrowser 2>/dev/null || true
systemctl disable filebrowser 2>/dev/null || true
pkill -f '/filebrowser .* -p 8082' 2>/dev/null || true
rm -f "$SERVICE_FILE"
systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed filebrowser 2>/dev/null || true

for dir in \
  "$APP_DIR" \
  "$DATA_DIR" \
  "/opt/wanos/apps/filebrowser" \
  "/opt/wanos-data/apps/filebrowser"
do
  case "$dir" in
    ""|"/"|"/opt"|"/opt/wanos"|"/opt/wanos-data"|"/mnt"|"/mnt/wanos") continue ;;
  esac
  if [ -e "$dir" ]; then
    rm -rf "$dir"
    log "已删除：$dir"
  fi
done

log "卸载完成"
