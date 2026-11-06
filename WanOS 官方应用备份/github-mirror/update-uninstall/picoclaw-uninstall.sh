#!/bin/sh
set -eu
APP_ID="picoclaw"
systemctl disable --now "$APP_ID.service" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/$APP_ID.service"
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "/opt/wanos/apps/$APP_ID"
# 保留 /root/.picoclaw，避免误删用户 API Key 和机器人配置。
echo "PicoClaw 已卸载。用户配置 /root/.picoclaw 已保留，如需彻底删除请手动清理。"
