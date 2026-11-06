#!/bin/sh
set -eu

APP_ID="lucky"
APP_NAME="Lucky万吉"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${LUCKY_PORT:-16601}"
PACKAGE_URL="${LUCKY_PACKAGE_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/lucky/lucky_2.27.2_Linux_armv7.tar.gz}"
PACKAGE_SHA256="${LUCKY_PACKAGE_SHA256:-a69964e74d5daf01ee13ea7c127a3614883de3ce80b6a568ddabbe6252b0cebd}"
ICON_URL="${LUCKY_ICON_URL:-https://wanos.xyz/downloads/apps/lucky/icon.png}"
TMP_DIR="$DATA_DIR/.tmp-install"
LOG_FILE="/var/log/wanos-lucky-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  case "$url" in
    file://*) src="${url#file://}"; [ -s "$src" ] || fatal "本地文件不存在：$src"; cp "$src" "$out" ;;
    *)
      if has_cmd curl; then
        curl -fL --connect-timeout 20 --max-time 900 --retry 3 --retry-delay 2 -o "$out" "$url"
      elif has_cmd wget; then
        wget -O "$out" "$url"
      else
        fatal "缺少 curl/wget，无法下载应用文件。"
      fi
      ;;
  esac
  [ -s "$out" ] || fatal "下载文件为空：$out"
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "系统缺少 sha256sum，无法校验安装包。"; fi
}

[ "$(id -u)" = "0" ] || fatal "请使用 root 用户安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "本应用仅支持 ARMv7 / armhf 设备。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd tar || fatal "本应用需要 tar。"

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/lucky" >/dev/null 2>&1 || true

ARCHIVE="$TMP_DIR/lucky_2.27.2_Linux_armv7.tar.gz"
log "下载安装包：$PACKAGE_URL"
fetch "$PACKAGE_URL" "$ARCHIVE" 2>&1
if [ -n "$PACKAGE_SHA256" ]; then
  got="$(sha256_file "$ARCHIVE")"
  [ "$got" = "$PACKAGE_SHA256" ] || fatal "安装包校验失败：want $PACKAGE_SHA256 got $got"
fi

rm -rf "$TMP_DIR/extract"
mkdir -p "$TMP_DIR/extract"
tar -xzf "$ARCHIVE" -C "$TMP_DIR/extract"
BIN="$(find "$TMP_DIR/extract" -type f -name lucky | head -n 1 || true)"
[ -n "$BIN" ] || fatal "安装包中未找到 lucky 二进制。"
cp "$BIN" "$BIN_DIR/lucky.new"
chmod 0755 "$BIN_DIR/lucky.new"
mv -f "$BIN_DIR/lucky.new" "$BIN_DIR/lucky"
chmod 0755 "$BIN_DIR/lucky"

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
mkdir -p "$DATA_DIR"
exec "$APP_DIR/bin/lucky" -cd "$DATA_DIR"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Lucky
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=LUCKY_PORT=$PORT
Environment=WANOS_APP_INSTALL_ROOT=$APP_DIR
Environment=WANOS_APP_DATA_ROOT=$DATA_DIR
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
LimitNOFILE=999999
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
Lucky万吉 已安装。

访问地址：http://设备IP:$PORT
默认账号：666
默认密码：666
服务名：lucky
数据目录：$DATA_DIR
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 3
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "服务启动失败，请查看：journalctl -u lucky -n 120 --no-pager"
fi
rm -rf "$TMP_DIR"
log "安装完成，访问地址：http://设备IP:$PORT，默认账号/密码：666 / 666。"
