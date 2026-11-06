#!/bin/sh
set -eu
APP_ID="v2ray-proxy"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PANEL_PORT="${V2RAY_PANEL_PORT:-10810}"
PKG_URL="${V2RAY_PROXY_PKG_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/v2ray-proxy/v2ray-proxy_v5.6.0_armv7_wanos.1.tar.gz}"
PKG_SHA256="${V2RAY_PROXY_PKG_SHA256:-609d2c9ddccf9e1bf0577fe70c9e6d214e3645f2ef9bd776de709fb4fd599041}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-update"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-v2ray-proxy-update.log"
log(){ printf '%s\n' "[V2Ray] $*"; }
fatal(){ printf '%s\n' "[V2Ray] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please update as root"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "本应用仅支持 ARMv7 / armv7l / armhf 架构。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3 用于 Web 面板。"
if ! has_cmd curl && ! has_cmd wget; then fatal "本应用需要 curl 或 wget。"; fi
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/$APP_ID.tar.gz"
log "下载安装包：$PKG_URL"
if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; else wget -O "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; fi
if has_cmd sha256sum; then got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"; [ "$got" = "$PKG_SHA256" ] || fatal "安装包校验失败：want $PKG_SHA256 got $got"; fi
tar -xzf "$ARCHIVE" -C "$APP_DIR"
chmod +x "$APP_DIR/bin/v2ray" "$APP_DIR/panel/v2ray-panel.py" 2>/dev/null || true
if [ ! -f "$DATA_DIR/config.json" ]; then cp "$APP_DIR/share/default-config.json" "$DATA_DIR/config.json"; fi
cat >"/etc/systemd/system/v2ray-proxy.service" <<EOF
[Unit]
Description=WanOS V2Ray Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/bin/v2ray run -config $DATA_DIR/config.json
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/v2ray-proxy-panel.service" <<EOF
[Unit]
Description=WanOS V2Ray Proxy Panel
After=v2ray-proxy.service network-online.target
Wants=v2ray-proxy.service network-online.target

[Service]
Type=simple
Environment=V2RAY_PANEL_PORT=$PANEL_PORT
Environment=V2RAY_APP_DIR=$APP_DIR
Environment=V2RAY_DATA_DIR=$DATA_DIR
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/panel/v2ray-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable v2ray-proxy.service >/dev/null 2>&1 || true
systemctl enable v2ray-proxy-panel.service >/dev/null 2>&1 || true
systemctl restart v2ray-proxy.service
systemctl restart v2ray-proxy-panel.service
rm -rf "$TMP_DIR"
log "更新完成。面板：http://设备IP:$PANEL_PORT；SOCKS5：设备IP:10808；HTTP：设备IP:10809"
