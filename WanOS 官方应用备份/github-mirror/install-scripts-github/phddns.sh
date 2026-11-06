#!/bin/sh
set -eu
APP_ID="phddns"
APP_NAME="花生壳"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PORT="${PHDDNS_PANEL_PORT:-16063}"
PKG_URL="${PHDDNS_PKG_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/phddns_armv7_5.1.0-wanos.2.tar.gz}"
PKG_SHA256="${PHDDNS_PKG_SHA256:-21a929b82b32c0d5c16123df2abcf4e01f5361902291a74f45dd66eb08b92f29}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-phddns-install.log"
log(){ printf '%s\n' "[Phddns] $*"; }
fatal(){ printf '%s\n' "[Phddns] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please install as root"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "本应用仅支持 ARMv7 / armv7l / armhf 架构。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3 用于本地 Web 面板。"
if ! has_cmd wget && ! has_cmd curl; then fatal "本应用需要 wget 或 curl 下载离线包。"; fi
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR" /var/log/phddns
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/phddns_armv7.tar.gz"
log "下载安装包：$PKG_URL"
if has_cmd curl; then
  curl -fL --connect-timeout 20 --retry 2 -o "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"
else
  wget -O "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"
fi
if has_cmd sha256sum; then
  got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  [ "$got" = "$PKG_SHA256" ] || fatal "安装包校验失败：want $PKG_SHA256 got $got"
fi
log "释放文件到：$APP_DIR"
tar -xzf "$ARCHIVE" -C "$APP_DIR"
chmod +x "$APP_DIR/bin/phtunnel" "$APP_DIR/bin/phddns" "$APP_DIR/panel/phddns-panel.py" 2>/dev/null || true
cat >"/etc/systemd/system/phtunnel.service" <<EOF
[Unit]
Description=Oray PeanutHull Phtunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$APP_DIR/bin/phtunnel -l /var/log/phddns/phtunnel.log -c $DATA_DIR/phtunnel.json -r -i 11431 -k 9bb2a2e255c5fd80 -e "client-ua:HSKEMD/5.1.0/Raspi/20060501;vendor:Oray"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/phddns-panel.service" <<EOF
[Unit]
Description=WanOS Phddns Panel
After=phtunnel.service network-online.target
Wants=phtunnel.service network-online.target

[Service]
Type=simple
Environment=PHDDNS_PANEL_PORT=$PORT
Environment=PHDDNS_APP_DIR=$APP_DIR
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/panel/phddns-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
ln -sf "$APP_DIR/bin/phddns" /usr/local/bin/phddns 2>/dev/null || true
systemctl daemon-reload
systemctl enable --now phtunnel.service
systemctl enable --now phddns-panel.service
rm -rf "$TMP_DIR"
log "安装完成。打开面板：http://设备IP:$PORT"
