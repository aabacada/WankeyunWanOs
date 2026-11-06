#!/bin/sh
set -eu
APP_ID="wol-network-wakeup"
APP_NAME="WOL网络唤醒"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${WOL_APP_PORT:-12100}"
ADDR="${WOL_APP_ADDR:-0.0.0.0:$PORT}"
BIN_URL="${WOL_APP_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/wol-app-linux-armv7}"
ICON_URL="${WOL_APP_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/wol-network-wakeup.png}"
BIN_SHA256="${WOL_APP_BIN_SHA256:-49ea8878853c3052a95ebd60fcc90a3324255cb7be03ab1643942f5c10934126}"
TMP_BIN="$DATA_DIR/.tmp-wol-app"
LOG_FILE="/var/log/wanos-wol-network-wakeup-install.log"
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
  if [ "$mode" = "addr" ]; then exec_line="$BIN_DIR/wol-app -addr $ADDR"; else exec_line="$BIN_DIR/wol-app"; fi
  cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS WOL Network Wakeup
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=PORT=$PORT
Environment=WOL_PORT=$PORT
Environment=WOL_APP_PORT=$PORT
Environment=WOL_ADDR=$ADDR
Environment=WOL_APP_ADDR=$ADDR
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
mv "$TMP_BIN" "$BIN_DIR/wol-app"
chmod 0755 "$BIN_DIR/wol-app"
install_static_assets
cat >"$APP_DIR/README-WanOS.txt" <<EOF
WOL网络唤醒已安装。

访问地址:
http://设备IP:$PORT

数据目录:
$DATA_DIR

服务管理:
systemctl status $APP_ID --no-pager
journalctl -u $APP_ID -n 120 --no-pager
EOF
write_service addr
systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 2
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  log "带 -addr 参数启动失败，尝试无参数启动。"
  write_service plain
  systemctl daemon-reload
  systemctl restart "$APP_ID"
  sleep 2
fi
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 || true
  fatal "WOL网络唤醒启动失败，请查看日志。"
fi
log "安装完成。访问地址 http://设备IP:$PORT"
