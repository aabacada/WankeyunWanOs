#!/bin/sh
set -eu
APP_ID="jiedianxiaobao"
IMAGE="ionewu/owjdxb_a32:latest"
CONTAINER="jiedianxiaobao"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PORT="${JIEDIANXIAOBAO_PORT:-9118}"
IMAGE_URL="${JIEDIANXIAOBAO_IMAGE_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/jiedianxiaobao/jiedianxiaobao_armv7.tar.gz}"
IMAGE_SHA256="${JIEDIANXIAOBAO_IMAGE_SHA256:-17354e719c1ee9c09afb3af0f1651af7731b3974f164f368b4eed46a7658c4c9}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-update"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-jiedianxiaobao-update.log"
log(){ printf '%s\n' "[节点小宝] $*"; }
fatal(){ printf '%s\n' "[节点小宝] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please update as root"
has_cmd docker || fatal "本应用依赖 Docker，请先安装 Docker 后再更新。"
DOCKER_BIN="$(command -v docker)"
mkdir -p "$APP_DIR" "$DATA_DIR/store" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/jiedianxiaobao_armv7.tar.gz"
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
Description=Jiedian Xiaobao Docker Container
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStartPre=-$DOCKER_BIN rm -f $CONTAINER
ExecStart=$DOCKER_BIN run --name $CONTAINER -p $PORT:9118 -v $DATA_DIR/store:/data/store -e TZ=Asia/Shanghai $IMAGE
ExecStop=$DOCKER_BIN stop $CONTAINER
ExecStopPost=-$DOCKER_BIN rm -f $CONTAINER

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$APP_ID.service"
rm -rf "$TMP_DIR"
log "updated. open panel: http://DEVICE_IP:${PORT}"
