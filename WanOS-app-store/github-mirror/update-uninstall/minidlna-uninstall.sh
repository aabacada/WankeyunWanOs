#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/minidlna}"
log(){ printf '%s\n' "[MiniDLNA] $*"; }
systemctl stop wanos-minidlna-panel wanos-minidlna 2>/dev/null || true
systemctl disable wanos-minidlna-panel wanos-minidlna 2>/dev/null || true
rm -f /etc/systemd/system/wanos-minidlna-panel.service /etc/systemd/system/wanos-minidlna.service
systemctl daemon-reload 2>/dev/null || true
rm -rf "$APP_DIR"
log "卸载完成。媒体目录和索引数据保留在 /opt/wanos-data/apps/minidlna。"
