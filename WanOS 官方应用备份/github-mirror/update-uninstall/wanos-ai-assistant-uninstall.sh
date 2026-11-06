#!/bin/sh
set -eu

APP_ID="wanos-ai-assistant"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"

systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/$APP_ID.service"
rm -f /etc/nginx/conf.d/00-wanos-ai-assistant.conf /etc/nginx/conf.d/02-wanos-ai-assistant.conf /etc/nginx/conf.d/02-wanos-ai-assistant-location.conf
systemctl daemon-reload >/dev/null 2>&1 || true
if command -v nginx >/dev/null 2>&1; then
  nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
fi
rm -rf "$APP_DIR"
echo "WanOS 智能助手已卸载，配置保留在 /opt/wanos-data/apps/$APP_ID"
