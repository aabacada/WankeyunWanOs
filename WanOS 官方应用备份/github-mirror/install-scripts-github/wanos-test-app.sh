#!/bin/sh
set -eu
APP_ID="wanos-test-app"
APP_NAME="WanOS 测试应用"
APP_DIR="/opt/wanos/apps/${APP_ID}"
BIN="${APP_DIR}/${APP_ID}"
SERVICE="/etc/systemd/system/${APP_ID}.service"
PORT="${WANOS_APP_PORT:-18090}"
BASE_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106"
BIN_URL="${BASE_URL}/wanos-test-app-linux-armv7"

mkdir -p "${APP_DIR}"
TMP="${APP_DIR}/.${APP_ID}.download"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "${BIN_URL}" -o "${TMP}"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "${TMP}" "${BIN_URL}"
else
  echo "curl 或 wget 不存在，无法下载安装文件" >&2
  exit 1
fi
chmod 0755 "${TMP}"
mv "${TMP}" "${BIN}"
cat > "${SERVICE}" <<EOF
[Unit]
Description=${APP_NAME}
After=network.target

[Service]
Type=simple
Environment=PORT=${PORT}
ExecStart=${BIN}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "${APP_ID}.service"
echo "${APP_NAME} 已安装并启动，端口 ${PORT}"
