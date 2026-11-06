#!/bin/sh
set -eu
APP_ID="xianyu-autodelivery"
APP_NAME="闲鱼自动发货"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${XIANYU_AUTODELIVERY_PORT:-12088}"
ADDR="${XIANYU_AUTODELIVERY_ADDR:-0.0.0.0:$PORT}"
BIN_URL="${XIANYU_AUTODELIVERY_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/xianyu-autodelivery-linux-armv7-v8}"
ICON_URL="${XIANYU_AUTODELIVERY_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/xianyu-autodelivery.png}"
BIN_SHA256="${XIANYU_AUTODELIVERY_BIN_SHA256:-6fa9089d9789ef1bb45e09c6ba84eadbd13b0566a7e200bfec9442685b24acd8}"
TMP_BIN="$DATA_DIR/.tmp-xianyu-autodelivery"
LOG_FILE="/var/log/wanos-xianyu-autodelivery-install.log"
log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
fetch(){
  url="$1"; out="$2"
  if has_cmd curl; then
    curl -fL --connect-timeout 20 --max-time 1200 --retry 3 --retry-delay 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -O "$out" "$url"
  else
    fatal "缺少下载工具"
  fi
}
sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "系统缺少 sha256sum"; fi
}
install_static_assets(){
  mkdir -p "$APP_DIR/assets" "$DATA_DIR/assets"
  if fetch "$ICON_URL" "$DATA_DIR/assets/xianyu.png" >/dev/null 2>&1; then
    cp "$DATA_DIR/assets/xianyu.png" "$APP_DIR/assets/xianyu.png" 2>/dev/null || true
    chmod 0644 "$DATA_DIR/assets/xianyu.png" "$APP_DIR/assets/xianyu.png" 2>/dev/null || true
    log "已写入应用内部资源 assets/xianyu.png"
  else
    log "图标下载失败，请稍后重试更新"
  fi
}
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "当前架构不支持 $(uname -m)" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd"
mkdir -p "$BIN_DIR" "$DATA_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
log "下载 $APP_NAME: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
[ -s "$TMP_BIN" ] || fatal "二进制为空"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "二进制校验失败"
mv "$TMP_BIN" "$BIN_DIR/xianyu-autodelivery"
chmod 0755 "$BIN_DIR/xianyu-autodelivery"
install_static_assets
cat >"$APP_DIR/README-WanOS.txt" <<EOF
闲鱼自动发货已安装.

访问地址:
http://设备IP:$PORT

静态资源:
$APP_DIR/assets/xianyu.png
$DATA_DIR/assets/xianyu.png

服务管理:
systemctl status $APP_ID --no-pager
journalctl -u $APP_ID -n 120 --no-pager
EOF
cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Xianyu Auto Delivery
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=PORT=$PORT
Environment=XIANYU_PORT=$PORT
Environment=XIANYU_AUTODELIVERY_PORT=$PORT
Environment=DATA_DIR=$DATA_DIR
Environment=APP_DATA=$DATA_DIR
ExecStart=$BIN_DIR/xianyu-autodelivery -addr $ADDR
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 2
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  log "启动失败，尝试使用环境变量启动"
  sed -i "s#ExecStart=.*#ExecStart=$BIN_DIR/xianyu-autodelivery#" "$SERVICE"
  systemctl daemon-reload
  systemctl restart "$APP_ID"
  sleep 2
fi
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 || true
  fatal "启动失败"
fi
log "安装完成。访问地址 http://设备IP:$PORT"
