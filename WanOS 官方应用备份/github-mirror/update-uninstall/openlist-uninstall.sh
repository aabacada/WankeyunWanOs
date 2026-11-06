#!/bin/sh
set -eu
systemctl stop openlist >/dev/null 2>&1 || true
systemctl disable openlist >/dev/null 2>&1 || true
rm -f /etc/systemd/system/openlist.service
systemctl daemon-reload >/dev/null 2>&1 || true
echo "[OpenList] 已卸载服务，数据目录保留在 ${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/openlist}"
