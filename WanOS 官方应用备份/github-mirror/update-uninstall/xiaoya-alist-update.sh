#!/bin/sh
set -eu
APP_ID="xiaoya-alist"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PANEL_PORT="${XIAOYA_PANEL_PORT:-5678}"
IMAGE_URL="${XIAOYA_ALIST_IMAGE_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/xiaoya-alist/xiaoya-alist_armv7.tar.gz}"
IMAGE_SHA256="${XIAOYA_ALIST_IMAGE_SHA256:-6566864ffc09cc3f7b7976ea5539097fb1a9a24674bb990d6b0d00d4f5dc15dd}"
PANEL_URL="https://wanos.xyz/downloads/apps/xiaoya-alist/xiaoya-panel.py"
CLEANUP_URL="https://wanos.xyz/downloads/apps/xiaoya-alist/xiaoya-cleanup.sh"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-update"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-xiaoya-alist-update.log"
log(){ printf '%s\n' "[Xiaoya Alist] $*"; }
fatal(){ printf '%s\n' "[Xiaoya Alist] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please update as root"
has_cmd docker || fatal "Docker is not installed"
has_cmd python3 || fatal "python3 is required"
DOCKER_BIN="$(command -v docker)"
PYTHON_BIN="$(command -v python3)"
mkdir -p "$APP_DIR" "$DATA_DIR/data" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/xiaoya-alist_armv7.tar.gz"
log "download image archive"
if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$ARCHIVE" "$IMAGE_URL" 2>&1 | tee -a "$LOG_FILE"; elif has_cmd wget; then wget -O "$ARCHIVE" "$IMAGE_URL" 2>&1 | tee -a "$LOG_FILE"; else fatal "curl/wget not found"; fi
if has_cmd sha256sum; then got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"; [ "$got" = "$IMAGE_SHA256" ] || fatal "sha256 mismatch: want $IMAGE_SHA256 got $got"; fi
log "load docker image"
if has_cmd gzip; then gzip -dc "$ARCHIVE" | "$DOCKER_BIN" load 2>&1 | tee -a "$LOG_FILE"; else "$DOCKER_BIN" load -i "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"; fi
log "download config panel"
if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$APP_DIR/xiaoya-panel.py" "$PANEL_URL"; elif has_cmd wget; then wget -O "$APP_DIR/xiaoya-panel.py" "$PANEL_URL"; fi
chmod 0755 "$APP_DIR/xiaoya-panel.py"
log "download cleanup helper"
if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$APP_DIR/xiaoya-cleanup.sh" "$CLEANUP_URL"; elif has_cmd wget; then wget -O "$APP_DIR/xiaoya-cleanup.sh" "$CLEANUP_URL"; fi
chmod 0755 "$APP_DIR/xiaoya-cleanup.sh"
systemctl stop "$APP_ID-panel.service" >/dev/null 2>&1 || true
systemctl stop "$APP_ID.service" >/dev/null 2>&1 || true
docker rm -f xiaoya-alist >/dev/null 2>&1 || true
cat >"/etc/systemd/system/$APP_ID.service" <<EOF
[Unit]
Description=Xiaoya Alist Docker Container
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStartPre=-$DOCKER_BIN rm -f xiaoya-alist
ExecStart=$DOCKER_BIN run --name xiaoya-alist -p 5233:5233 -v /opt/wanos-data/apps/xiaoya-alist/data:/data -e TZ=Asia/Shanghai xiaoyaliu/alist:hostmode
ExecStop=$DOCKER_BIN stop xiaoya-alist
ExecStopPost=-$DOCKER_BIN rm -f xiaoya-alist

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/$APP_ID-panel.service" <<EOF
[Unit]
Description=WanOS Xiaoya Alist Config Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=XIAOYA_PANEL_PORT=$PANEL_PORT
Environment=XIAOYA_DATA_DIR=/opt/wanos-data/apps/xiaoya-alist/data
Environment=XIAOYA_PROXY_PORT=10011
WorkingDirectory=$APP_DIR
ExecStart=$PYTHON_BIN $APP_DIR/xiaoya-panel.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/$APP_ID-cleanup.service" <<EOF
[Unit]
Description=WanOS Xiaoya Alist Cleanup
After=$APP_ID.service
Wants=$APP_ID.service

[Service]
Type=oneshot
ExecStart=$APP_DIR/xiaoya-cleanup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$APP_ID.service"
systemctl enable --now "$APP_ID-panel.service"
systemctl enable --now "$APP_ID-cleanup.service" || true
rm -rf "$TMP_DIR"
log "updated. open config panel: http://DEVICE_IP:${PANEL_PORT}"
