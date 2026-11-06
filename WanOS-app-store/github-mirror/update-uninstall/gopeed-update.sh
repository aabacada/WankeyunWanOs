#!/bin/sh
set -eu
APP_ID="gopeed"
IMAGE="liwei2633/gopeed:latest"
CONTAINER="gopeed"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PORT="${GOPEED_PORT:-9999}"
IMAGE_URL="${GOPEED_IMAGE_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/gopeed/gopeed_armv7.tar.gz}"
IMAGE_SHA256="${GOPEED_IMAGE_SHA256:-963dbce2dc7c11c6488e5d70e7ae8ee2e09a32f333e8454d72d8ce193370a1d0}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-update"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-gopeed-update.log"
log(){ printf '%s\n' "[Gopeed] $*"; }
fatal(){ printf '%s\n' "[Gopeed] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please update as root"
has_cmd docker || fatal "本应用依赖 Docker，请先安装 Docker 后再更新。"
DOCKER_BIN="$(command -v docker)"
mkdir -p "$APP_DIR" "$DATA_DIR/downloads" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/gopeed_armv7.tar.gz"
log "download image archive: $IMAGE_URL"
if has_cmd curl; then
  curl -fL --connect-timeout 20 --retry 2 -o "$ARCHIVE" "$IMAGE_URL" 2>&1 | tee -a "$LOG_FILE"
elif has_cmd wget; then
  wget -O "$ARCHIVE" "$IMAGE_URL" 2>&1 | tee -a "$LOG_FILE"
else
  fatal "curl/wget not found"
fi
if has_cmd sha256sum; then
  got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  [ "$got" = "$IMAGE_SHA256" ] || fatal "sha256 mismatch: want $IMAGE_SHA256 got $got"
fi
log "load docker image"
if has_cmd gzip; then
  gzip -dc "$ARCHIVE" | "$DOCKER_BIN" load 2>&1 | tee -a "$LOG_FILE"
else
  "$DOCKER_BIN" load -i "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"
fi
systemctl stop "$APP_ID.service" >/dev/null 2>&1 || true
"$DOCKER_BIN" rm -f "$CONTAINER" >/dev/null 2>&1 || true
cat >"/etc/systemd/system/$APP_ID.service" <<EOF
[Unit]
Description=Gopeed Download Manager Docker Container
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStartPre=-$DOCKER_BIN rm -f $CONTAINER
ExecStart=$DOCKER_BIN run --name $CONTAINER -p $PORT:9999 -v $DATA_DIR/downloads:/app/Download -e TZ=Asia/Shanghai $IMAGE
ExecStop=$DOCKER_BIN stop $CONTAINER
ExecStopPost=-$DOCKER_BIN rm -f $CONTAINER

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$APP_ID.service"
rm -rf "$TMP_DIR"
log "updated. open panel: http://DEVICE_IP:${PORT}"
