#!/bin/sh
# WanOS mirror build: 2026-06-02
set -eu

APP_ID="picoclaw"
APP_NAME="小龙虾AI助手"
APP_DIR="/opt/wanos/apps/${APP_ID}"
DATA_DIR="/opt/wanos-data/apps/${APP_ID}"
BIN_DIR="${APP_DIR}/bin"
SERVICE="/etc/systemd/system/${APP_ID}.service"
VERSION="${PICOCLAW_VERSION:-v0.2.4}"
PORT="${PICOCLAW_PORT:-18800}"
ARCHIVE="picoclaw_Linux_armv7.tar.gz"
DOWNLOAD_URL="${PICOCLAW_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/picoclaw_Linux_armv7.tar.gz}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT

log() { printf '%s\n' "[PicoClaw] $*"; }
fatal() { printf '%s\n' "[PicoClaw] ERROR: $*" >&2; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" = "0" ] || fatal "请使用 root 用户安装。"

ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*) ;;
  *) fatal "当前 PicoClaw 应用包暂只支持 ARMv7/armv7l，检测到：$ARCH。" ;;
esac

mkdir -p "$BIN_DIR" "$DATA_DIR" "$TMP_DIR"
cd "$TMP_DIR"
log "下载 PicoClaw：$DOWNLOAD_URL"
if has_cmd curl; then
  curl -fL --connect-timeout 20 --retry 2 -o "$ARCHIVE" "$DOWNLOAD_URL"
elif has_cmd wget; then
  wget -O "$ARCHIVE" "$DOWNLOAD_URL"
else
  fatal "缺少 curl/wget，无法下载 PicoClaw。"
fi

tar -zxvf "$ARCHIVE" >/dev/null
for name in picoclaw picoclaw-launcher; do
  found="$(find . -type f -name "$name" | head -n 1 || true)"
  [ -n "$found" ] || fatal "压缩包内未找到 $name。"
  cp "$found" "$BIN_DIR/$name"
  chmod 0755 "$BIN_DIR/$name"
done
optional_tui="$(find . -type f -name picoclaw-launcher-tui | head -n 1 || true)"
if [ -n "$optional_tui" ]; then
  cp "$optional_tui" "$BIN_DIR/picoclaw-launcher-tui"
  chmod 0755 "$BIN_DIR/picoclaw-launcher-tui"
else
  log "压缩包内未包含 picoclaw-launcher-tui，已跳过可选终端界面。"
fi

cat >"$APP_DIR/README-WanOS.txt" <<EOF
PicoClaw 已安装。

Web 控制台：
http://设备IP:${PORT}

首次配置：
1. 打开 Web 控制台。
2. 在模型页面添加自己的 API Key。
3. 如需 QQ 渠道，请在 PicoClaw 控制台或配置文件中填写 QQ Bot AppID/AppSecret。

配置目录通常位于 /root/.picoclaw/config.json。
EOF

cat >"$SERVICE" <<EOF
[Unit]
Description=PicoClaw Launcher Web UI
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment=HOME=/root
Environment=PICOCLAW_PORT=${PORT}
ExecStart=${BIN_DIR}/picoclaw-launcher -public
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$APP_ID.service"
rm -rf "$TMP_DIR"
log "PicoClaw 已安装并启动，Web 控制台端口：${PORT}。请自行配置大模型 API Key。"
