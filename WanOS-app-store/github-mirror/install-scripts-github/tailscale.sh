#!/bin/sh
set -eu
APP_ID="tailscale"
APP_NAME="Tailscale 异地组网"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
LOG_FILE="/var/log/wanos-tailscale-install.log"
WORKER="$APP_DIR/install-worker.sh"
ARCHIVE_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/tailscale_1.98.4_arm.tgz"
ARCHIVE_SHA256="18d4568fe5c72ac31fdac4a8af233770a0357673e6a32f315d04eb0453f495bd"
PANEL_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/tailscale-panel.py"
PANEL="$APP_DIR/tailscale-panel.py"
PANEL_PORT="41642"
log(){ printf '%s
' "[Tailscale] $*"; }
fatal(){ printf '%s
' "[Tailscale] ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = "0" ] || fatal "请使用 root 用户安装。"
case "$(uname -m 2>/dev/null || true)" in armv7l|armv7*|armhf) ;; *) fatal "当前应用仅支持 ARMv7 / armhf。" ;; esac
[ -c /dev/net/tun ] || fatal "系统缺少 /dev/net/tun，无法运行 Tailscale。"
mkdir -p "$APP_DIR" "$BIN_DIR" "$DATA_DIR"
cat >"$WORKER" <<'WORKER_EOF'
#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/tailscale}"
BIN_DIR="$APP_DIR/bin"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/tailscale}"
LOG_FILE="/var/log/wanos-tailscale-install.log"
ARCHIVE_URL="__ARCHIVE_URL__"
ARCHIVE_SHA256="__ARCHIVE_SHA256__"
PANEL_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/tailscale-panel.py"
PANEL="$APP_DIR/tailscale-panel.py"
PANEL_PORT="41642"
LOCK_DIR="/tmp/wanos-tailscale-install.lock"
log(){ printf '%s %s
' "$(date '+%F %T')" "[Tailscale] $*"; }
fatal(){ log "ERROR: $*"; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
if ! mkdir "$LOCK_DIR" 2>/dev/null; then log "已有安装任务正在运行。"; exit 0; fi
trap 'rm -rf "$LOCK_DIR"' EXIT
mkdir -p "$APP_DIR" "$BIN_DIR" "$DATA_DIR"
download(){ url="$1"; out="$2"; if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$out" "$url"; elif has_cmd wget; then wget -O "$out" "$url"; else fatal "缺少 curl/wget。"; fi; }
check_sha(){ file="$1"; want="$2"; if has_cmd sha256sum; then got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || fatal "校验失败：$got"; fi; }
log "下载 Tailscale：$ARCHIVE_URL"
tmp="$(mktemp -d /tmp/wanos-tailscale.XXXXXX)"
trap 'rm -rf "$tmp" "$LOCK_DIR"' EXIT
archive="$tmp/tailscale.tgz"
download "$ARCHIVE_URL" "$archive"
check_sha "$archive" "$ARCHIVE_SHA256"
tar -xzf "$archive" -C "$tmp"
found="$(find "$tmp" -type f -name tailscale | head -n 1 || true)"
foundd="$(find "$tmp" -type f -name tailscaled | head -n 1 || true)"
[ -n "$found" ] && [ -n "$foundd" ] || fatal "压缩包内未找到 tailscale/tailscaled。"
cp "$found" "$BIN_DIR/tailscale"
cp "$foundd" "$BIN_DIR/tailscaled"
chmod 0755 "$BIN_DIR/tailscale" "$BIN_DIR/tailscaled"
ln -sf "$BIN_DIR/tailscale" /usr/local/bin/tailscale 2>/dev/null || true
ln -sf "$BIN_DIR/tailscaled" /usr/local/bin/tailscaled 2>/dev/null || true
log "下载 Web 面板。"
download "$PANEL_URL" "$PANEL"
chmod 0755 "$PANEL"
cat >/etc/systemd/system/tailscaled.service <<EOF
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=$BIN_DIR/tailscaled --state=$DATA_DIR/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=41641
ExecStopPost=$BIN_DIR/tailscaled --cleanup
Restart=on-failure
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
cat >/etc/systemd/system/tailscale-panel.service <<EOF
[Unit]
Description=WanOS Tailscale Web Panel
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment=TAILSCALE_PANEL_PORT=$PANEL_PORT
ExecStart=/usr/bin/python3 $PANEL
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now tailscaled >/dev/null 2>&1 || systemctl restart tailscaled
systemctl enable --now tailscale-panel >/dev/null 2>&1 || systemctl restart tailscale-panel
log "安装完成。面板：http://设备IP:$PANEL_PORT"
log "首次授权命令：tailscale up --accept-routes --accept-dns=false"
WORKER_EOF
sed -i "s#__ARCHIVE_URL__#$ARCHIVE_URL#g; s#__ARCHIVE_SHA256__#$ARCHIVE_SHA256#g" "$WORKER"
chmod 0755 "$WORKER"
if pgrep -f "$WORKER" >/dev/null 2>&1; then log "后台安装任务已在运行，请查看 $LOG_FILE"; exit 0; fi
: >"$LOG_FILE"
nohup sh "$WORKER" >>"$LOG_FILE" 2>&1 &
log "Tailscale 后台安装已开始。日志：$LOG_FILE。安装完成后打开 http://设备IP:$PANEL_PORT"
