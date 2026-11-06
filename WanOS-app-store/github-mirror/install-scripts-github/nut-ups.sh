#!/bin/sh
set -eu
APP_ID="nut-ups"
APP_NAME="UPS 电源管理"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
LOG_FILE="/var/log/wanos-nut-ups-install.log"
WORKER="$APP_DIR/install-worker.sh"
OFFLINE_SHA256="50a9d045f73553abbd80cd65fe263bdc2491818ac3e533988666052d0aa7b86c"
PANEL_SHA256="8dca6b1df13fd28375d5380e062e980a4b663e09c1b8d53609b101edba1da8b8"
PORT="3494"
log() { printf '%s
' "[NUT] $*"; }
fatal() { printf '%s
' "[NUT] ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = "0" ] || fatal "请使用 root 用户安装。"
case "$(uname -m 2>/dev/null || true)" in armv7l|armv7*|armhf) ;; *) fatal "当前离线包仅支持 ARMv7 / armhf，当前架构：$(uname -m 2>/dev/null || echo unknown)" ;; esac
mkdir -p "$APP_DIR" "$DATA_DIR"
cat >"$WORKER" <<'WORKER_EOF'
#!/bin/sh
set -eu
APP_ID="nut-ups"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PANEL="$APP_DIR/nut-panel.py"
OFFLINE_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/nut-ups-offline-armhf-ubuntu20.04.tar.gz"
OFFLINE_SHA256="__OFFLINE_SHA256__"
PANEL_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/nut-panel.py"
PANEL_SHA256="__PANEL_SHA256__"
SERVICE="/etc/systemd/system/nut-web-panel.service"
PORT="3494"
LOCK_DIR="/tmp/wanos-nut-ups-install.lock"
log() { printf '%s %s
' "$(date '+%F %T')" "[NUT] $*"; }
fatal() { log "ERROR: $*"; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }
if ! mkdir "$LOCK_DIR" 2>/dev/null; then log "已有 UPS 安装任务正在运行。"; exit 0; fi
trap 'rm -rf "$LOCK_DIR"' EXIT
download_file() { url="$1"; out="$2"; if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$out" "$url"; elif has_cmd wget; then wget -O "$out" "$url"; else fatal "缺少 curl/wget。"; fi; }
sha256_check() { file="$1"; want="$2"; if has_cmd sha256sum; then got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || fatal "文件校验失败：$got"; fi; }
install_offline_debs() {
  has_cmd dpkg || fatal "系统缺少 dpkg。"
  has_cmd tar || fatal "系统缺少 tar。"
  tmp="$(mktemp -d /tmp/wanos-nut.XXXXXX)"
  trap 'rm -rf "$tmp" "$LOCK_DIR"' EXIT
  bundle="$tmp/nut-ups-offline.tar.gz"
  log "下载 NUT 离线包：$OFFLINE_URL"
  download_file "$OFFLINE_URL" "$bundle"
  sha256_check "$bundle" "$OFFLINE_SHA256"
  tar -xzf "$bundle" -C "$tmp" || fatal "离线包解压失败。"
  [ -d "$tmp/debs" ] || fatal "离线包缺少 debs 目录。"
  [ -f "$tmp/nut-panel.py" ] && cp "$tmp/nut-panel.py" "$PANEL"
  need=""
  for pkg in nut nut-server nut-client usbutils; do dpkg-query -W "$pkg" >/dev/null 2>&1 || need="1"; done
  if [ -z "$need" ]; then log "检测到 NUT 依赖已安装，跳过 deb 安装。"; return 0; fi
  log "安装 NUT 离线依赖，详细日志：/tmp/wanos-nut-dpkg.log"
  dpkg -i "$tmp"/debs/*.deb >/tmp/wanos-nut-dpkg.log 2>&1 || true
  dpkg --configure -a >>/tmp/wanos-nut-dpkg.log 2>&1 || true
  dpkg -i "$tmp"/debs/*.deb >>/tmp/wanos-nut-dpkg.log 2>&1 || fatal "离线依赖安装失败，请查看 /tmp/wanos-nut-dpkg.log"
}
log "开始安装 UPS 电源管理。"
mkdir -p "$APP_DIR" "$DATA_DIR" /etc/nut
if ! has_cmd upsd || ! has_cmd upsdrvctl || ! has_cmd upsc; then install_offline_debs; else log "检测到 NUT 已安装。"; fi
if [ ! -f "$PANEL" ]; then log "下载 NUT Web 面板：$PANEL_URL"; download_file "$PANEL_URL" "$PANEL"; sha256_check "$PANEL" "$PANEL_SHA256"; fi
chmod 0755 "$PANEL"
has_cmd python3 || fatal "系统缺少 python3。"
backup_file() { f="$1"; if [ -f "$f" ] && [ ! -f "$f.wanos.bak" ]; then cp "$f" "$f.wanos.bak"; fi; }
backup_file /etc/nut/nut.conf; backup_file /etc/nut/ups.conf; backup_file /etc/nut/upsd.conf; backup_file /etc/nut/upsd.users; backup_file /etc/nut/upsmon.conf
cat >/etc/nut/nut.conf <<EOF
MODE=netserver
EOF
if ! grep -q "^\[wanosups\]" /etc/nut/ups.conf 2>/dev/null; then cat >>/etc/nut/ups.conf <<EOF

[wanosups]
    driver = usbhid-ups
    port = auto
    desc = "WanOS UPS"
EOF
fi
cat >/etc/nut/upsd.conf <<EOF
LISTEN 127.0.0.1 3493
LISTEN 0.0.0.0 3493
EOF
cat >/etc/nut/upsd.users <<EOF
[wanosmon]
    password = wanos
    upsmon master
EOF
if ! grep -q "^MONITOR wanosups@localhost" /etc/nut/upsmon.conf 2>/dev/null; then cat >>/etc/nut/upsmon.conf <<EOF

MONITOR wanosups@localhost 1 wanosmon wanos master
MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h +0"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower
EOF
fi
chown -R root:nut /etc/nut 2>/dev/null || true
chmod 0640 /etc/nut/*.conf /etc/nut/upsd.users 2>/dev/null || true
cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS NUT UPS Web Panel
After=network-online.target nut-server.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment=NUT_PANEL_PORT=$PORT
ExecStart=/usr/bin/python3 $PANEL
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable nut-server >/dev/null 2>&1 || true
systemctl enable nut-monitor >/dev/null 2>&1 || true
systemctl restart nut-server >/dev/null 2>&1 || true
systemctl restart nut-monitor >/dev/null 2>&1 || true
systemctl enable nut-web-panel >/dev/null 2>&1 || true
systemctl restart nut-web-panel
cat >"$APP_DIR/README-WanOS.txt" <<EOF
UPS 电源管理已安装。

Web 面板：
http://设备IP:$PORT

默认 NUT UPS 名称：wanosups
默认 NUT 监听端口：3493
默认监控用户：wanosmon / wanos
EOF
log "安装完成，Web 面板：http://设备IP:$PORT"
WORKER_EOF
sed -i "s/__OFFLINE_SHA256__/$OFFLINE_SHA256/g; s/__PANEL_SHA256__/$PANEL_SHA256/g" "$WORKER"
chmod 0755 "$WORKER"
if pgrep -f "$WORKER" >/dev/null 2>&1; then log "UPS 后台安装任务已在运行，请稍后查看 $LOG_FILE"; exit 0; fi
: >"$LOG_FILE"
nohup sh "$WORKER" >>"$LOG_FILE" 2>&1 &
log "UPS 后台安装已开始。日志：$LOG_FILE。安装完成后访问 http://设备IP:$PORT"
exit 0
