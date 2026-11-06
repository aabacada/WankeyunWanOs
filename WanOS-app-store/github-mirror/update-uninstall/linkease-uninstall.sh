#!/bin/sh
set -eu
log(){ echo "[易有云] $*"; }
/opt/wanos/apps/linkease/bin/linkease --serviceControl stop >/dev/null 2>&1 || true
/opt/wanos/apps/linkease/bin/linkease --serviceControl uninstall >/dev/null 2>&1 || true
systemctl stop com.linkease.linkeasedaemon.service 2>/dev/null || true
systemctl disable com.linkease.linkeasedaemon.service 2>/dev/null || true
rm -f /etc/systemd/system/com.linkease.linkeasedaemon.service
systemctl daemon-reload 2>/dev/null || true
rm -f /usr/sbin/linkease /usr/sbin/heif-converter /usr/sbin/linkease-media
rm -rf /usr/sbin/linkmount
rm -rf /opt/wanos/apps/linkease /opt/wanos-data/apps/linkease
log "卸载完成"
