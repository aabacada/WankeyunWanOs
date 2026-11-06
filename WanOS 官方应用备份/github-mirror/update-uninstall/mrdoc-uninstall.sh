#!/bin/sh
set -eu
log(){ echo "[MrDoc] $*"; }
systemctl stop mrdoc 2>/dev/null || true
systemctl disable mrdoc 2>/dev/null || true
rm -f /etc/systemd/system/mrdoc.service
rm -f /etc/nginx/sites-enabled/mrdoc-wanos.conf /etc/nginx/sites-available/mrdoc-wanos.conf
systemctl daemon-reload 2>/dev/null || true
nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null || true
rm -rf /opt/wanos/apps/mrdoc
rm -rf /opt/wanos-data/apps/mrdoc
log "uninstalled"
