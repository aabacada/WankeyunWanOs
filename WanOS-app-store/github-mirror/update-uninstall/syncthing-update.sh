#!/bin/sh
set -eu
APP_ID="syncthing"
APP_NAME="Syncthing 同步"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
PORT="${SYNCTHING_PORT:-8384}"
PKG_URL="${SYNCTHING_PKG_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/syncthing/syncthing-linux-arm-v2.1.0.tar.gz}"
PKG_SHA256="${SYNCTHING_PKG_SHA256:-dfcccf4855628d6b1de483a4a777c029121ee4e7cbc04ea76e26aee47dd20578}"
LOG_FILE="/var/log/wanos-syncthing-update.log"
log(){ printf '%s\n' "[Syncthing 同步] $*"; }
fatal(){ printf '%s\n' "[Syncthing 同步] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "请使用 root 用户更新。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "本应用仅支持 ARMv7 / armv7l / armhf 架构。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd tar || fatal "本应用需要 tar。"
if ! has_cmd curl && ! has_cmd wget; then fatal "本应用需要 curl 或 wget。"; fi
mkdir -p "$BIN_DIR" "$DATA_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/syncthing-linux-arm-v2.1.0.tar.gz"
log "下载安装包：$PKG_URL"
if has_cmd curl; then
  curl_opts="-fL --connect-timeout 20 --max-time 300 --retry 2"
    if ! curl $curl_opts -o "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; then
    fatal "下载安装包失败：$PKG_URL"
  fi
else
  if ! wget -O "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; then
    fatal "下载安装包失败：$PKG_URL"
  fi
fi
[ -s "$ARCHIVE" ] || fatal "安装包为空或不存在：$ARCHIVE"
if [ -n "$PKG_SHA256" ] && has_cmd sha256sum; then got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"; [ "$got" = "$PKG_SHA256" ] || fatal "安装包校验失败：want $PKG_SHA256 got $got"; fi
log "解压安装包"
rm -rf "$TMP_DIR/extract"; mkdir -p "$TMP_DIR/extract"
tar -xzf "$ARCHIVE" -C "$TMP_DIR/extract"
found="$(find "$TMP_DIR/extract" -type f -name syncthing -size +1M | head -n 1 || true)"
[ -n "$found" ] || fatal "压缩包内未找到 syncthing。"
cp "$found" "$BIN_DIR/syncthing"
chmod 0755 "$BIN_DIR/syncthing"
cat >"/etc/systemd/system/$APP_ID.service" <<EOF
[Unit]
Description=Syncthing 同步
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
ExecStart=$BIN_DIR/syncthing serve --home="$DATA_DIR" --no-browser --gui-address=0.0.0.0:$PORT --no-restart
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
cat >"$APP_DIR/README-WanOS.txt" <<EOF
Syncthing 同步 已安装。
Web 面板：http://设备IP:$PORT
数据目录：$DATA_DIR
EOF
systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 2
systemctl is-active --quiet "$APP_ID" || { systemctl status "$APP_ID" --no-pager -l || true; fatal "服务启动失败。"; }
rm -rf "$TMP_DIR"
log "更新完成，Web 面板：http://设备IP:$PORT"
