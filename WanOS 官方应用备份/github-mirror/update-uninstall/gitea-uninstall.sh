#!/bin/sh
set -eu
log(){ echo "[Gitea] $*"; }
systemctl stop gitea 2>/dev/null || true
systemctl disable gitea 2>/dev/null || true
rm -f /etc/systemd/system/gitea.service
systemctl daemon-reload 2>/dev/null || true
rm -rf /opt/wanos/apps/gitea
rm -rf /opt/wanos-data/apps/gitea
log "卸载完成"
