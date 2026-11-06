#!/bin/sh
set -eu

APP_ID="baidupan-client"
APP_NAME="BaiduPan WanOS"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${BAIDUPAN_PORT:-8732}"
ADDR="${BAIDUPAN_ADDR:-0.0.0.0:$PORT}"
CONFIG_FILE="${BAIDUPAN_CONFIG:-$DATA_DIR/baidupan-config.json}"
BIN_URL="${BAIDUPAN_BIN_URL:-}"
ICON_URL="${BAIDUPAN_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/baidupan-client.png}"
BIN_SHA256="${BAIDUPAN_BIN_SHA256:-}"
TMP_BIN="$DATA_DIR/.tmp-baidupan-client"
LOG_FILE="/var/log/wanos-baidupan-client-install.log"
CDN_BASE="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  if has_cmd curl; then
    curl -fL --connect-timeout 20 --max-time 1200 --retry 3 --retry-delay 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -O "$out" "$url"
  else
    fatal "missing curl/wget"
  fi
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "missing sha256sum"; fi
}

install_icon(){
  mkdir -p "$ASSET_DIR" "$DATA_DIR/assets"
  if fetch "$ICON_URL" "$DATA_DIR/assets/icon.png" >/dev/null 2>&1; then
    cp "$DATA_DIR/assets/icon.png" "$ASSET_DIR/icon.png" 2>/dev/null || true
    chmod 0644 "$DATA_DIR/assets/icon.png" "$ASSET_DIR/icon.png" 2>/dev/null || true
    log "icon installed"
  else
    log "icon download failed; continue"
  fi
}

ensure_config(){
  if [ -s "$CONFIG_FILE" ]; then
    return 0
  fi
  umask 077
  cat >"$CONFIG_FILE" <<'EOF'
{
  "client_id": "zpvUaXkBrX8Jo1MTGaWvBKeS9W6c5Teu",
  "client_secret": "FGzhboFbZQKN9igMnSWUNdd7ZyQMf4MG",
  "redirect_uri": "",
  "token": {
    "access_token": "",
    "refresh_token": "",
    "scope": "",
    "expires_in": 0,
    "expires_at": "0001-01-01T00:00:00Z"
  }
}
EOF
  chmod 0600 "$CONFIG_FILE" 2>/dev/null || true
  log "config initialized: $CONFIG_FILE"
}

write_service(){
  cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS BaiduPan Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=PORT=$PORT
Environment=BAIDUPAN_PORT=$PORT
Environment=BAIDUPAN_ADDR=$ADDR
Environment=BAIDUPAN_LISTEN=$ADDR
Environment=BAIDUPAN_CONFIG=$CONFIG_FILE
Environment=DATA_DIR=$DATA_DIR
Environment=APP_DATA=$DATA_DIR
ExecStart=$BIN_DIR/baidupan-client -listen $ADDR -config $CONFIG_FILE
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

dump_diagnostics(){
  log "service start diagnostics:"
  systemctl status "$APP_ID" --no-pager -l 2>&1 || true
  journalctl -u "$APP_ID" -n 120 --no-pager -l 2>&1 || true
  log "manual run diagnostics:"
  if has_cmd timeout; then
    timeout 5 "$BIN_DIR/baidupan-client" -listen "$ADDR" -config "$CONFIG_FILE" 2>&1 || true
  else
    "$BIN_DIR/baidupan-client" -listen "$ADDR" -config "$CONFIG_FILE" 2>&1 || true
  fi
}

start_service(){
  write_service
  systemctl daemon-reload
  systemctl restart "$APP_ID"
  sleep 3
  systemctl is-active "$APP_ID" >/dev/null 2>&1
}

[ "$(id -u)" = "0" ] || fatal "please run as root"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*|armhf|arm*)
    DEFAULT_BIN_URL="$CDN_BASE/baidupan-client-linux-armv7-v8"
    DEFAULT_BIN_SHA256="680b421fc5dec8ff644e85391212f206235f45f08889c2b556c42cdc1b754899"
    ;;
  aarch64|arm64)
    DEFAULT_BIN_URL="$CDN_BASE/baidupan-client-linux-arm64-v8"
    DEFAULT_BIN_SHA256="5fa4572b953734845d1fa86020317748e7407ffda7cf228f21504791ed9551dc"
    ;;
  x86_64|amd64)
    DEFAULT_BIN_URL="$CDN_BASE/baidupan-client-linux-amd64-v8"
    DEFAULT_BIN_SHA256="0e3cb8a7342fc7bfa78280f8bc22f48ad3eb49dd382ffa63cd6d545ae00b5828"
    ;;
  *) fatal "unsupported arch: $ARCH, need armv7/arm64/amd64" ;;
esac
BIN_URL="${BIN_URL:-$DEFAULT_BIN_URL}"
BIN_SHA256="${BIN_SHA256:-$DEFAULT_BIN_SHA256}"
has_cmd systemctl || fatal "systemd is required"

mkdir -p "$BIN_DIR" "$DATA_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
[ -s "$TMP_BIN" ] || fatal "empty binary"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary checksum mismatch"

mv "$TMP_BIN" "$BIN_DIR/baidupan-client"
chmod 0755 "$BIN_DIR/baidupan-client"
install_icon
ensure_config

cat >"$APP_DIR/README-WanOS.txt" <<EOF
BaiduPan WanOS installed.

URL:
http://DEVICE_IP:$PORT

Data:
$DATA_DIR

Config:
$CONFIG_FILE

Service:
systemctl status $APP_ID --no-pager
journalctl -u $APP_ID -n 120 --no-pager
EOF

systemctl enable "$APP_ID" >/dev/null 2>&1 || true
if start_service; then
  log "started with -listen $ADDR"
else
  dump_diagnostics
  fatal "service start failed"
fi

log "install done: http://DEVICE_IP:$PORT"
