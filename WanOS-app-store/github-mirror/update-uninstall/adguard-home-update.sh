#!/bin/sh
set -eu
APP_ID="adguard-home"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PKG_URL="${ADGUARD_HOME_PKG_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/adguard-home/AdGuardHome_linux_armv7_v0.107.76.tar.gz}"
PKG_SHA256="${ADGUARD_HOME_PKG_SHA256:-0c60e959fc9ef0c8a0a728961390e6f77cbc9fcd8f3de07646be52cefe68d988}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-update"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-adguard-home-update.log"
log(){ printf '%s\n' "[AdGuardHome] $*"; }
fatal(){ printf '%s\n' "[AdGuardHome] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please update as root"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "本应用仅支持 ARMv7 / armv7l / armhf 架构。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
if ! has_cmd curl && ! has_cmd wget; then fatal "本应用需要 curl 或 wget。"; fi
mkdir -p "$APP_DIR" "$DATA_DIR/work" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/adguardhome.tar.gz"
log "下载安装包：$PKG_URL"
if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 180 --retry 2 -o "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; else wget -O "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; fi
if has_cmd sha256sum; then got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"; [ "$got" = "$PKG_SHA256" ] || fatal "安装包校验失败：want $PKG_SHA256 got $got"; fi
rm -rf "$APP_DIR/AdGuardHome.new"
mkdir -p "$APP_DIR/AdGuardHome.new"
log "解压安装包"
tar -xzf "$ARCHIVE" -C "$APP_DIR/AdGuardHome.new" --strip-components=1
chmod +x "$APP_DIR/AdGuardHome.new/AdGuardHome" 2>/dev/null || true
if [ -d "$APP_DIR/AdGuardHome" ]; then rm -rf "$APP_DIR/AdGuardHome.old"; mv "$APP_DIR/AdGuardHome" "$APP_DIR/AdGuardHome.old"; fi
mv "$APP_DIR/AdGuardHome.new" "$APP_DIR/AdGuardHome"
cat >"/etc/systemd/system/adguard-home.service" <<EOF
[Unit]
Description=AdGuard Home DNS Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$DATA_DIR/work
ExecStart=$APP_DIR/AdGuardHome/AdGuardHome -w $DATA_DIR/work -c $DATA_DIR/AdGuardHome.yaml
Restart=always
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
log "启动 AdGuard Home 服务"
systemctl daemon-reload
systemctl enable adguard-home.service >/dev/null 2>&1 || true
if command -v timeout >/dev/null 2>&1; then
  timeout 20 systemctl restart adguard-home.service || { systemctl status adguard-home.service --no-pager -l || true; fatal "AdGuard Home 启动超时或失败，请查看端口 53/3000 是否被占用。"; }
else
  systemctl restart adguard-home.service || { systemctl status adguard-home.service --no-pager -l || true; fatal "AdGuard Home 启动失败，请查看端口 53/3000 是否被占用。"; }
fi
systemctl is-active adguard-home.service >/dev/null 2>&1 || { systemctl status adguard-home.service --no-pager -l || true; fatal "AdGuard Home 未能保持运行。"; }
rm -rf "$TMP_DIR"
log "更新完成。面板：http://设备IP:3000；DNS 端口：53"
