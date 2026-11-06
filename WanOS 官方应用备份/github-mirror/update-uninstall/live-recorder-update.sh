#!/bin/sh
set -eu
APP_ID="live-recorder"
APP_NAME="直播录制"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${LIVE_RECORDER_PORT:-18081}"
ADDR="${LIVE_RECORDER_ADDR:-0.0.0.0:$PORT}"
BIN_URL="${LIVE_RECORDER_BIN_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/live-recorder/live-recorder-armv7-go-v3}"
ICON_URL="${LIVE_RECORDER_ICON_URL:-https://wanos.xyz/downloads/apps/live-recorder/icon-small.png}"
BIN_SHA256="${LIVE_RECORDER_BIN_SHA256:-a1b850be1e8dcc46ce457b9c8b2c86eb11282666c7319f30da72935a0e546f5c}"
TMP_BIN="$DATA_DIR/.tmp-live-recorder"
LOG_FILE="/var/log/wanos-live-recorder-install.log"
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
    fatal "缺少 curl/wget，无法下载应用文件。"
  fi
}
sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "系统缺少 sha256sum，无法校验文件。"; fi
}
install_static_assets(){
  mkdir -p "$APP_DIR/assets" "$DATA_DIR/assets"
  if fetch "$ICON_URL" "$DATA_DIR/assets/icon.png" >/dev/null 2>&1; then
    cp "$DATA_DIR/assets/icon.png" "$APP_DIR/assets/icon.png" 2>/dev/null || true
    chmod 0644 "$DATA_DIR/assets/icon.png" "$APP_DIR/assets/icon.png" 2>/dev/null || true
    log "已写入应用图标 assets/icon.png"
  else
    log "图标下载失败，不影响主服务启动。"
  fi
}
write_service(){
  mode="$1"
  case "$mode" in
    addr) exec_line="$BIN_DIR/live-recorder -addr $ADDR" ;;
    port) exec_line="$BIN_DIR/live-recorder -port $PORT" ;;
    *) exec_line="$BIN_DIR/live-recorder" ;;
  esac
  cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Live Recorder
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=PORT=$PORT
Environment=LIVE_RECORDER_PORT=$PORT
Environment=LIVE_RECORDER_ADDR=$ADDR
Environment=DATA_DIR=$DATA_DIR
Environment=APP_DATA=$DATA_DIR
ExecStart=$exec_line
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}
try_start(){
  mode="$1"
  write_service "$mode"
  systemctl daemon-reload
  systemctl restart "$APP_ID"
  sleep 2
  systemctl is-active "$APP_ID" >/dev/null 2>&1
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
mv "$TMP_BIN" "$BIN_DIR/live-recorder"
chmod 0755 "$BIN_DIR/live-recorder"
install_static_assets
cat >"$APP_DIR/README-WanOS.txt" <<EOF
直播录制已安装。

访问地址:
http://设备IP:$PORT

数据目录:
$DATA_DIR

服务管理:
systemctl status $APP_ID --no-pager
journalctl -u $APP_ID -n 120 --no-pager
EOF
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
if try_start addr; then
  log "已使用 -addr 参数启动。"
elif try_start port; then
  log "已使用 -port 参数启动。"
elif try_start plain; then
  log "已使用默认参数启动。"
else
  systemctl status "$APP_ID" --no-pager -l 2>&1 || true
  fatal "直播录制启动失败，请查看日志。"
fi
log "安装完成。访问地址 http://设备IP:$PORT"
