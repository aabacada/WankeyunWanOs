#!/bin/sh
set -eu
APP_ID="openlist"
APP_NAME="OpenList"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
TMP_DIR="$DATA_DIR/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-openlist-install.log"
PORT="${OPENLIST_PORT:-5245}"
DEFAULT_ADMIN_USER="${OPENLIST_ADMIN_USER:-${WANOS_APP_ADMIN_USERNAME:-admin}}"
DEFAULT_ADMIN_PASSWORD="${OPENLIST_ADMIN_PASSWORD:-${WANOS_APP_ADMIN_PASSWORD:-admin}}"
PACKAGE_URL="${OPENLIST_PACKAGE_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/openlist-linux-musleabihf-armv7l.tar.gz}"
PACKAGE_SHA256="${OPENLIST_PACKAGE_SHA256:-2eaacd187512e94eca46039ee7e11a96ffe579b3f92fcf11f86ffc91cdd64604}"
log(){ printf '%s\n' "[OpenList] $*"; }
fatal(){ printf '%s\n' "[OpenList] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
download_file(){
  url="$1"; out="$2"; label="$3"
  log "下载 $label：$url"
  case "$url" in
    file://*) src="${url#file://}"; [ -s "$src" ] || fatal "$label 不存在：$src"; cp "$src" "$out" ;;
    *)
      if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$out" "$url";
      elif has_cmd wget; then wget -O "$out" "$url";
      else fatal "缺少 curl/wget"; fi
      ;;
  esac
  [ -s "$out" ] || fatal "$label 文件为空：$out"
}
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "仅支持 ARMv7 / armhf 设备" ;; esac
case "$PORT" in 8080) fatal "8080 是 WanOS 主服务端口，请改用 5245 或其他端口" ;; esac
mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$TMP_DIR"
if command -v systemctl >/dev/null 2>&1; then
  systemctl stop openlist >/dev/null 2>&1 || true
fi
pkill -f "$BIN_DIR/openlist" >/dev/null 2>&1 || true
sleep 1
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/openlist-linux-musleabihf-armv7l.tar.gz"
download_file "$PACKAGE_URL" "$ARCHIVE" "OpenList ARMv7 离线包"
if has_cmd sha256sum && [ -n "$PACKAGE_SHA256" ]; then
  got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  [ "$got" = "$PACKAGE_SHA256" ] || fatal "OpenList 离线包校验失败：want $PACKAGE_SHA256 got $got"
fi
rm -rf "$TMP_DIR/extract"
mkdir -p "$TMP_DIR/extract"
tar -xzf "$ARCHIVE" -C "$TMP_DIR/extract"
BIN="$(find "$TMP_DIR/extract" -type f \( -name openlist -o -name OpenList \) | head -n 1 || true)"
[ -n "$BIN" ] || fatal "离线包中未找到 openlist 二进制"
cp "$BIN" "$BIN_DIR/openlist.new"
chmod 0755 "$BIN_DIR/openlist.new"
mv -f "$BIN_DIR/openlist.new" "$BIN_DIR/openlist"
chmod 0755 "$BIN_DIR/openlist"
cat >"$APP_DIR/run.sh" <<'EOF'
#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/openlist}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/openlist}"
PORT="${OPENLIST_PORT:-5245}"
OPENLIST_DATA="$DATA_DIR/data"
mkdir -p "$OPENLIST_DATA"
CONFIG="$OPENLIST_DATA/config.json"
if [ ! -f "$CONFIG" ]; then
  cat >"$CONFIG" <<CFG
{
  "scheme": {
    "address": "0.0.0.0",
    "http_port": 5245,
    "https_port": -1,
    "force_https": false,
    "unix_file_perm": ""
  }
}
CFG
fi
if command -v sed >/dev/null 2>&1; then
  sed -i "s/\"http_port\"[[:space:]]*:[[:space:]]*[0-9][0-9]*/\"http_port\": ${PORT}/" "$CONFIG" 2>/dev/null || true
  sed -i "s/\"address\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"address\": \"0.0.0.0\"/" "$CONFIG" 2>/dev/null || true
fi
exec "$APP_DIR/bin/openlist" server --data "$OPENLIST_DATA"
EOF
chmod 0755 "$APP_DIR/run.sh"
OPENLIST_DATA="$DATA_DIR/data"
mkdir -p "$OPENLIST_DATA"
if [ ! -f "$OPENLIST_DATA/.wanos-admin-default-set" ]; then
  log "设置默认管理员账号：$DEFAULT_ADMIN_USER / $DEFAULT_ADMIN_PASSWORD"
  "$BIN_DIR/openlist" admin set "$DEFAULT_ADMIN_PASSWORD" --data "$OPENLIST_DATA" >/dev/null 2>&1 ||     "$BIN_DIR/openlist" --data "$OPENLIST_DATA" admin set "$DEFAULT_ADMIN_PASSWORD" >/dev/null 2>&1 ||     log "默认管理员密码设置失败，可安装后执行：$BIN_DIR/openlist admin set admin --data $OPENLIST_DATA"
  date +%s >"$OPENLIST_DATA/.wanos-admin-default-set" 2>/dev/null || true
fi
cat >/etc/systemd/system/openlist.service <<EOF
[Unit]
Description=OpenList for WanOS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment=WANOS_APP_INSTALL_ROOT=$APP_DIR
Environment=WANOS_APP_DATA_ROOT=$DATA_DIR
Environment=OPENLIST_PORT=$PORT
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable openlist >/dev/null 2>&1 || true
systemctl restart openlist
sleep 3
if systemctl is-active openlist >/dev/null 2>&1; then
  log "安装完成"
  log "访问地址：http://设备IP:$PORT"
  log "默认账号：admin"
  log "默认密码：admin"
  log "首次登录后请立即修改默认密码。"
else
  journalctl -u openlist --no-pager -n 80 || true
  fatal "OpenList 服务启动失败"
fi
