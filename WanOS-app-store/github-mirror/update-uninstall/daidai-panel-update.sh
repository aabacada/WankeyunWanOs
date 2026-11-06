#!/bin/sh
set -eu
APP_ID="daidai-panel"
APP_NAME="呆呆面板"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PORT="${DAIDAI_PORT:-5701}"
PKG_URL="${DAIDAI_PACKAGE_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/daidai-panel/daidai-linux-armv7.tar.gz}"
PKG_SHA256="${DAIDAI_PACKAGE_SHA256:-f94f759e299844c501de6b8c2f4cbc453ea72d0b1e8932b05aaa183a1e661f6c}"
TMP_DIR="$DATA_DIR/.tmp-install"
LOG_FILE="/var/log/wanos-daidai-panel-install.log"
log(){ printf '%s\n' "[呆呆面板] $*"; }
fatal(){ printf '%s\n' "[呆呆面板] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
fetch(){
  url="$1"; out="$2"
  if has_cmd curl; then
    curl -fL --connect-timeout 20 --max-time 1200 --retry 3 --retry-delay 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -O "$out" "$url"
  else
    fatal "缺少 curl/wget，无法下载离线包"
  fi
}
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "当前架构不支持：$(uname -m)，本应用需要 ARMv7/armhf。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd sha256sum || fatal "系统缺少 sha256sum。"
has_cmd tar || fatal "系统缺少 tar。"
case "$PORT" in 80|8080|5700) fatal "$PORT 是系统或青龙常用端口，请改用 5701 或其他端口。" ;; esac
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/daidai-linux-armv7.tar.gz"
case "$PKG_URL" in
  file://*)
    ARCHIVE="${PKG_URL#file://}"
    log "使用本地离线包：$ARCHIVE"
    [ -s "$ARCHIVE" ] || fatal "本地离线包不存在：$ARCHIVE"
    ;;
  *)
    log "下载呆呆面板离线包：$PKG_URL"
    fetch "$PKG_URL" "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"
    ;;
esac
[ -s "$ARCHIVE" ] || fatal "离线包为空"
got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
log "离线包 SHA256：$got"
[ "$got" = "$PKG_SHA256" ] || fatal "离线包校验失败：want $PKG_SHA256 got $got"
rm -rf "$APP_DIR/.extract"
mkdir -p "$APP_DIR/.extract"
tar -xzf "$ARCHIVE" -C "$APP_DIR/.extract"
BIN="$(find "$APP_DIR/.extract" -maxdepth 2 -type f -name 'daidai-linux-armv7' | head -n 1)"
[ -n "$BIN" ] || fatal "离线包中未找到 daidai-linux-armv7"
SRC_DIR="$(dirname "$BIN")"
rm -rf "$APP_DIR/bin" "$APP_DIR/web"
mkdir -p "$APP_DIR/bin"
cp "$BIN" "$APP_DIR/bin/daidai-panel"
chmod +x "$APP_DIR/bin/daidai-panel"
[ -d "$SRC_DIR/web" ] && cp -a "$SRC_DIR/web" "$APP_DIR/web"
cat >"$APP_DIR/config.yaml" <<EOF
server:
  port: $PORT
  mode: release

database:
  path: $DATA_DIR/daidai.db

jwt:
  secret: ""
  access_token_expire: 480h
  refresh_token_expire: 1440h

data:
  dir: $DATA_DIR
  scripts_dir: $DATA_DIR/scripts
  log_dir: $DATA_DIR/logs

cors:
  origins:
    - http://localhost:$PORT
    - http://127.0.0.1:$PORT
EOF
cat >"/etc/systemd/system/daidai-panel.service" <<EOF
[Unit]
Description=WanOS Daidai Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/bin/daidai-panel
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now daidai-panel.service
sleep 3
if ! systemctl is-active daidai-panel.service >/dev/null 2>&1; then
  systemctl status daidai-panel.service --no-pager -l 2>&1 || true
  fatal "呆呆面板启动失败，请查看 $LOG_FILE"
fi
cp "$APP_DIR/config.yaml" "$DATA_DIR/config.yaml" 2>/dev/null || true
rm -rf "$TMP_DIR" "$APP_DIR/.extract"
log "安装完成。访问地址：http://设备IP:$PORT；首次进入请初始化管理员。"
