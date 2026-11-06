#!/bin/sh
set -eu
APP_ID="minecraft-java"
APP_DIR="/opt/wanos/apps/$APP_ID"
log(){ printf '%s\n' "[Minecraft] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop minecraft-java-panel.service >/dev/null 2>&1 || true
systemctl disable minecraft-java-panel.service >/dev/null 2>&1 || true
systemctl stop minecraft-java.service >/dev/null 2>&1 || true
systemctl disable minecraft-java.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/minecraft-java-panel.service /etc/systemd/system/minecraft-java.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
log "已卸载。世界和配置保留在 /opt/wanos-data/apps/minecraft-java"
