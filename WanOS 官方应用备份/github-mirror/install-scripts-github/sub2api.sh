#!/bin/sh
set -eu

APP_ID="sub2api"
APP_NAME="sub2api"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${SUB2API_PORT:-18080}"
ADDR="${SUB2API_ADDR:-0.0.0.0:$PORT}"
BIN_URL="${SUB2API_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/sub2api-linux-armv7-v1}"
ICON_URL="${SUB2API_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/sub2api.png}"
BIN_SHA256="${SUB2API_BIN_SHA256:-ff5d9fc7d1cdc144a645b6a7db9e1a7a5d1d12e5070c280a669079de8cc167bf}"
TMP_BIN="$DATA_DIR/.tmp-sub2api"
LOG_FILE="/var/log/wanos-sub2api-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  case "$url" in
    file://*) src="${url#file://}"; [ -s "$src" ] || fatal "file not found: $src"; cp "$src" "$out" ;;
    *)
      if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 1800 --retry 3 --retry-delay 2 -o "$out" "$url";
      elif has_cmd wget; then wget -O "$out" "$url";
      else fatal "缺少 curl/wget，无法下载应用文件。"; fi
      ;;
  esac
  [ -s "$out" ] || fatal "下载文件为空：$out"
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "系统缺少 sha256sum，无法校验应用文件。"; fi
}

[ "$(id -u)" = "0" ] || fatal "请使用 root 用户安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "本应用仅支持 ARMv7 / armhf 设备。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/sub2api" >/dev/null 2>&1 || true

log "下载主程序：$BIN_URL"
fetch "$BIN_URL" "$TMP_BIN"
got="$(sha256_file "$TMP_BIN")"
[ "$got" = "$BIN_SHA256" ] || fatal "主程序校验失败：want $BIN_SHA256 got $got"
mv -f "$TMP_BIN" "$BIN_DIR/sub2api"
chmod 0755 "$BIN_DIR/sub2api"

if fetch "$ICON_URL" "$ASSET_DIR/icon.png" >/dev/null 2>&1; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
fi

cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
APP_DIR="$APP_DIR"
DATA_DIR="$DATA_DIR"
PORT="$PORT"
ADDR="$ADDR"
cd "$DATA_DIR"
if [ -n "${SUB2API_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/sub2api" $SUB2API_ARGS
fi
exec "$APP_DIR/bin/sub2api"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS sub2api
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=PORT=$PORT
Environment=SUB2API_PORT=$PORT
Environment=SUB2API_ADDR=$ADDR
Environment=GIN_MODE=release
Environment=TZ=Asia/Shanghai
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
sub2api 已安装。

访问地址：http://设备IP:$PORT
服务名：sub2api
数据目录：$DATA_DIR
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 4
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "服务启动失败，请查看：journalctl -u sub2api -n 120 --no-pager"
fi
log "安装完成，访问地址：http://设备IP:18080"
