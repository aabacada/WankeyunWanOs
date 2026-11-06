#!/bin/sh
set -eu

APP_ID="new-api"
APP_NAME="New API"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${NEW_API_PORT:-3000}"
ADDR="${NEW_API_ADDR:-0.0.0.0:$PORT}"
BIN_URL="${NEW_API_BIN_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/new-api/new-api-linux-armv7-v1}"
ICON_URL="${NEW_API_ICON_URL:-https://wanos.xyz/downloads/apps/new-api/icon.png}"
BIN_SHA256="${NEW_API_BIN_SHA256:-d76b406896c854b2d908d9ee0d800b85be63294870f500e0e6a45f9c439c69f2}"
TMP_BIN="$DATA_DIR/.tmp-new-api"
LOG_FILE="/var/log/wanos-new-api-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  if has_cmd curl; then
    curl -fL --connect-timeout 20 --max-time 1800 --retry 3 --retry-delay 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -O "$out" "$url"
  else
    fatal "缺少 curl/wget，无法下载应用文件。"
  fi
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "系统缺少 sha256sum，无法校验文件。"; fi
}

install_static_assets(){
  mkdir -p "$ASSET_DIR" "$DATA_DIR/assets"
  if fetch "$ICON_URL" "$DATA_DIR/assets/icon.png" >/dev/null 2>&1; then
    cp "$DATA_DIR/assets/icon.png" "$ASSET_DIR/icon.png" 2>/dev/null || true
    chmod 0644 "$DATA_DIR/assets/icon.png" "$ASSET_DIR/icon.png" 2>/dev/null || true
    log "已写入应用图标 assets/icon.png"
  else
    log "图标下载失败，不影响主服务启动。"
  fi
}

write_service(){
  cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS New API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=PORT=$PORT
Environment=NEW_API_PORT=$PORT
Environment=NEW_API_ADDR=$ADDR
Environment=SQLITE_PATH=$DATA_DIR/new-api.db
Environment=SESSION_SECRET=wanos-new-api-session-secret
Environment=CRYPTO_SECRET=wanos-new-api-crypto-secret
Environment=GIN_MODE=release
Environment=TZ=Asia/Shanghai
Environment=DATA_DIR=$DATA_DIR
Environment=APP_DATA=$DATA_DIR
ExecStart=$BIN_DIR/new-api
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

try_start(){
  write_service
  systemctl daemon-reload
  systemctl restart "$APP_ID"
  sleep 5
  systemctl is-active "$APP_ID" >/dev/null 2>&1
}

dump_diagnostics(){
  log "服务启动诊断："
  systemctl status "$APP_ID" --no-pager -l 2>&1 || true
  journalctl -u "$APP_ID" -n 120 --no-pager -l 2>&1 || true
}

[ "$(id -u)" = "0" ] || fatal "请使用 root 安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "当前架构不支持，本应用需要 ARMv7/armhf。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"

mkdir -p "$BIN_DIR" "$DATA_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true

log "下载 $APP_NAME: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
[ -s "$TMP_BIN" ] || fatal "应用二进制为空。"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "应用二进制校验失败。"

mv "$TMP_BIN" "$BIN_DIR/new-api"
chmod 0755 "$BIN_DIR/new-api"
install_static_assets

cat >"$DATA_DIR/.env" <<EOF
PORT=$PORT
SQLITE_PATH=$DATA_DIR/new-api.db
SESSION_SECRET=wanos-new-api-session-secret
CRYPTO_SECRET=wanos-new-api-crypto-secret
GIN_MODE=release
TZ=Asia/Shanghai
EOF
chmod 0600 "$DATA_DIR/.env" 2>/dev/null || true

cat >"$APP_DIR/README-WanOS.txt" <<EOF
New API 已安装。

访问地址:
http://设备IP:$PORT

数据目录:
$DATA_DIR

服务管理:
systemctl status $APP_ID --no-pager
journalctl -u $APP_ID -n 120 --no-pager
EOF

systemctl enable "$APP_ID" >/dev/null 2>&1 || true
if try_start; then
  log "已使用 PORT=$PORT 和 SQLITE_PATH=$DATA_DIR/new-api.db 启动。"
else
  dump_diagnostics
  fatal "$APP_NAME 启动失败，请查看日志。"
fi

log "安装完成。访问地址 http://设备IP:$PORT"
