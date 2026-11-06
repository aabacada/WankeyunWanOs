#!/bin/sh
set -eu

APP_ID="quark-auto-save"
APP_NAME="Quark Auto Save"
IMAGE="${QUARK_AUTO_SAVE_IMAGE:-cp0204/quark-auto-save:latest}"
CONTAINER="${QUARK_AUTO_SAVE_CONTAINER:-wanos-quark-auto-save}"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
CONFIG_DIR="$DATA_DIR/config"
MEDIA_DIR="$DATA_DIR/media"
PORT="${QUARK_AUTO_SAVE_PORT:-5005}"
first_nonempty(){
  for value in "$@"; do
    [ -n "$value" ] && { printf '%s' "$value"; return 0; }
  done
}
WEBUI_USERNAME="$(first_nonempty "${WEBUI_USERNAME:-}" "${QUARK_AUTO_SAVE_WEBUI_USERNAME:-}" "${QUARK_AUTO_SAVE_USERNAME:-}" "${QUARK_AUTO_SAVE_ADMIN_USERNAME:-}" "${WANOS_APP_WEBUI_USERNAME:-}" "${WANOS_APP_USERNAME:-}" "${WANOS_APP_ADMIN_USERNAME:-}" "${username:-}" "${admin_username:-}" "admin")"
WEBUI_PASSWORD="$(first_nonempty "${WEBUI_PASSWORD:-}" "${QUARK_AUTO_SAVE_WEBUI_PASSWORD:-}" "${QUARK_AUTO_SAVE_PASSWORD:-}" "${QUARK_AUTO_SAVE_ADMIN_PASSWORD:-}" "${WANOS_APP_WEBUI_PASSWORD:-}" "${WANOS_APP_PASSWORD:-}" "${WANOS_APP_ADMIN_PASSWORD:-}" "${password:-}" "${admin_password:-}" "admin123")"
PLUGIN_FLAGS="${PLUGIN_FLAGS:-}"
TASK_TIMEOUT="${TASK_TIMEOUT:-1800}"
PKG_URL="${QUARK_AUTO_SAVE_IMAGE_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/quark-auto-save/quark-auto-save-linux-armv7-docker-image-v1.tar.gz}"
PKG_SHA256="${QUARK_AUTO_SAVE_IMAGE_SHA256:-4823254169b0a975e2d67adf9b6f0e3e5c67cc366ed596e40c9ec2a4d03fc29e}"
TMP_DIR="$DATA_DIR/.tmp-install"
ARCHIVE="$TMP_DIR/quark-auto-save-image.tar.gz"
LOG_FILE="/var/log/wanos-quark-auto-save-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  case "$url" in
    file://*) src="${url#file://}"; [ -s "$src" ] || fatal "local offline package not found: $src"; cp "$src" "$out" ;;
    *)
      if has_cmd curl; then
        curl -fL --connect-timeout 20 --max-time 3600 --retry 3 --retry-delay 2 -o "$out" "$url"
      elif has_cmd wget; then
        wget -O "$out" "$url"
      else
        fatal "missing curl/wget, cannot download offline image package"
      fi
      ;;
  esac
  [ -s "$out" ] || fatal "downloaded file is empty: $out"
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "missing sha256sum, cannot verify package"; fi
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "unsupported architecture: $(uname -m), ARMv7/armhf required" ;; esac
has_cmd docker || fatal "Docker is required. Install WanOS Docker component first."
has_cmd systemctl || fatal "systemd is required"
has_cmd tar || fatal "tar is required"

DOCKER_BIN="$(command -v docker)"
mkdir -p "$APP_DIR" "$CONFIG_DIR" "$MEDIA_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true

log "install start"
log "download offline docker image: $PKG_URL"
fetch "$PKG_URL" "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"
got="$(sha256_file "$ARCHIVE")"
log "offline package SHA256: $got"
[ "$got" = "$PKG_SHA256" ] || fatal "package SHA256 mismatch: want $PKG_SHA256 got $got"

if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
  log "Docker service is not running, starting docker"
  systemctl start docker >/dev/null 2>&1 || true
  i=0
  while [ "$i" -lt 30 ]; do
    if "$DOCKER_BIN" info >/dev/null 2>&1; then break; fi
    i=$((i + 1))
    sleep 1
  done
fi
if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
  systemctl status docker --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "Docker service is not ready. Install or repair WanOS Docker component first."
fi

log "load docker image"
LOAD_LOG="$TMP_DIR/docker-load.log"
if "$DOCKER_BIN" load -i "$ARCHIVE" >"$LOAD_LOG" 2>&1; then
  cat "$LOAD_LOG"
else
  cat "$LOAD_LOG" || true
  fatal "docker image load failed"
fi

if ! "$DOCKER_BIN" image inspect "$IMAGE" >/dev/null 2>&1; then
  loaded_image="$("$DOCKER_BIN" images --format '{{.Repository}}:{{.Tag}}' | grep -E '(^|/)quark-auto-save:latest$' | head -n 1 || true)"
  if [ -n "$loaded_image" ]; then
    "$DOCKER_BIN" tag "$loaded_image" "$IMAGE" >/dev/null 2>&1 || true
  fi
fi
if ! "$DOCKER_BIN" image inspect "$IMAGE" >/dev/null 2>&1; then
  image_id="$("$DOCKER_BIN" images --format '{{.ID}} {{.Repository}}:{{.Tag}}' | awk '$2 ~ /quark-auto-save/ {print $1; exit}')"
  [ -n "$image_id" ] || fatal "quark-auto-save image not found after load"
  "$DOCKER_BIN" tag "$image_id" "$IMAGE"
fi

cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
exec "$DOCKER_BIN" run --name "$CONTAINER" --rm \
  --network bridge \
  -p "$PORT:5005" \
  -e TZ=Asia/Shanghai \
  -e WEBUI_USERNAME="$WEBUI_USERNAME" \
  -e WEBUI_PASSWORD="$WEBUI_PASSWORD" \
  -e PORT=5005 \
  -e PLUGIN_FLAGS="$PLUGIN_FLAGS" \
  -e TASK_TIMEOUT="$TASK_TIMEOUT" \
  -v "$CONFIG_DIR:/app/config" \
  -v "$MEDIA_DIR:/media" \
  "$IMAGE"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"/etc/systemd/system/$APP_ID.service" <<EOF
[Unit]
Description=WanOS Quark Auto Save
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=simple
Restart=always
RestartSec=8
ExecStartPre=-$DOCKER_BIN rm -f $CONTAINER
ExecStart=$APP_DIR/run.sh
ExecStop=$DOCKER_BIN stop $CONTAINER
ExecStopPost=-$DOCKER_BIN rm -f $CONTAINER

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
Quark Auto Save installed.

URL: http://device-ip:$PORT
Username: $WEBUI_USERNAME
Password: the password configured before installation
Config: $CONFIG_DIR
Media: $MEDIA_DIR
Image: $IMAGE
EOF

systemctl daemon-reload
systemctl enable --now "$APP_ID.service"
sleep 6
if ! systemctl is-active "$APP_ID.service" >/dev/null 2>&1; then
  systemctl status "$APP_ID.service" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  journalctl -u "$APP_ID.service" -n 120 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "service start failed, check: journalctl -u $APP_ID -n 120 --no-pager"
fi
rm -rf "$TMP_DIR"
log "install done: http://device-ip:$PORT username=$WEBUI_USERNAME"
