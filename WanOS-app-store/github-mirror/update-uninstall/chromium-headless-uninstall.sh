#!/bin/sh
set -eu
APP_ID="chromium-headless"
APP_DIR="/opt/wanos/apps/$APP_ID"
log(){ printf '%s\n' "[Chromium] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop chromium-headless-panel.service >/dev/null 2>&1 || true
systemctl disable chromium-headless-panel.service >/dev/null 2>&1 || true
systemctl stop chromium-headless.service >/dev/null 2>&1 || true
systemctl disable chromium-headless.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/chromium-headless-panel.service /etc/systemd/system/chromium-headless.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "已卸载。Chromium deb 包不会自动移除，避免影响系统依赖。"
