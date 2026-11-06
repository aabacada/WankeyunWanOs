#!/bin/sh
set -eu

APP_ID="ddns-go"
APP_NAME="DDNS-GO 动态域名"
APP_DIR="/opt/wanos/apps/${APP_ID}"
DATA_DIR="/opt/wanos-data/apps/${APP_ID}"
BIN_DIR="${APP_DIR}/bin"
SERVICE="/etc/systemd/system/${APP_ID}.service"
PORT="${DDNS_GO_PORT:-9876}"
ARCHIVE="ddns-go_6.13.3_linux_armv7.tar.gz"
DOWNLOAD_URL="${DDNS_GO_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/ddns-go_6.13.3_linux_armv7.tar.gz}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
CONFIG_FILE="${DATA_DIR}/ddns-go.yaml"

log() { printf '%s\n' "[DDNS-GO] $*"; }
fatal() { printf '%s\n' "[DDNS-GO] ERROR: $*" >&2; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" = "0" ] || fatal "请使用 root 用户安装。"

ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*) ;;
  *) fatal "当前 DDNS-GO 应用包暂只支持 ARMv7/armv7l，检测到：$ARCH。" ;;
esac

mkdir -p "$BIN_DIR" "$DATA_DIR" "$TMP_DIR"
cd "$TMP_DIR"
log "下载 DDNS-GO：$DOWNLOAD_URL"
if has_cmd curl; then
  curl -fL --connect-timeout 20 --retry 2 -o "$ARCHIVE" "$DOWNLOAD_URL"
elif has_cmd wget; then
  wget -O "$ARCHIVE" "$DOWNLOAD_URL"
else
  fatal "缺少 curl/wget，无法下载 DDNS-GO。"
fi

tar -zxvf "$ARCHIVE" >/dev/null
found="$(find . -type f -name ddns-go | head -n 1 || true)"
[ -n "$found" ] || fatal "压缩包内未找到 ddns-go。"
cp "$found" "$BIN_DIR/ddns-go"
chmod 0755 "$BIN_DIR/ddns-go"

cat >"$APP_DIR/README-WanOS.txt" <<EOF
DDNS-GO 已安装。

Web 控制台：
http://设备IP:${PORT}

用途：
把动态公网 IP 自动同步到 Cloudflare、阿里云、腾讯云等 DNS 服务商。

配置文件：
${CONFIG_FILE}
EOF

cat >"$SERVICE" <<EOF
[Unit]
Description=DDNS-GO Dynamic DNS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${DATA_DIR}
ExecStart=${BIN_DIR}/ddns-go -l :${PORT} -f 300 -c ${CONFIG_FILE}
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
rm -rf "$TMP_DIR"
log "安装完成，Web 控制台：http://设备IP:${PORT}"
