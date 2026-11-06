#!/bin/sh
set -eu
APP_ID="wanos-test-app"
systemctl disable --now "${APP_ID}.service" >/dev/null 2>&1 || true
rm -f "/etc/systemd/system/${APP_ID}.service"
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "/opt/wanos/apps/${APP_ID}"
echo "WanOS 测试应用已卸载"
