#!/bin/sh
set -eu
log(){ echo "[Typecho] $*"; }
systemctl stop typecho-blog 2>/dev/null || true
systemctl disable typecho-blog 2>/dev/null || true
rm -f /etc/systemd/system/typecho-blog.service
systemctl daemon-reload 2>/dev/null || true
rm -rf /opt/wanos/apps/typecho-blog
rm -rf /opt/wanos-data/apps/typecho-blog
log "卸载完成"
