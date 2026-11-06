#!/bin/sh
set -eu
log(){ echo "[YT-DLP] $*"; }
systemctl stop yt-dlp-web 2>/dev/null || true
systemctl disable yt-dlp-web 2>/dev/null || true
rm -f /etc/systemd/system/yt-dlp-web.service
systemctl daemon-reload 2>/dev/null || true
rm -rf /opt/wanos/apps/yt-dlp-web
rm -rf /opt/wanos-data/apps/yt-dlp-web
log "uninstalled"
