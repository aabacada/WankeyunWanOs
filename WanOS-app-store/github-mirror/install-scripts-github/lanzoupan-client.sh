#!/bin/sh
set -eu

APP_ID="lanzoupan-client"
APP_NAME="蓝奏云盘"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${LANZOUPAN_CLIENT_PORT:-8741}"
ADDR="${LANZOUPAN_CLIENT_ADDRESS:-0.0.0.0:$PORT}"
ICON_URL="${LANZOUPAN_CLIENT_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/lanzoupan-client.png}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"
LOG_FILE="/var/log/wanos-$APP_ID-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  case "$url" in
    file://*) src="${url#file://}"; [ -s "$src" ] || fatal "local file not found: $src"; cp "$src" "$out" ;;
    *)
      if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 1800 --retry 3 --retry-delay 2 -o "$out" "$url";
      elif has_cmd wget; then wget -O "$out" "$url";
      else fatal "missing curl/wget, cannot download app file"; fi
      ;;
  esac
  [ -s "$out" ] || fatal "downloaded file is empty: $out"
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "missing sha256sum, cannot verify app file"; fi
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*|armhf|arm)
    PACKAGE_ARCH="armv7"
    DEFAULT_BIN_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/lanzoupan-client-linux-armv7-v1"
    DEFAULT_BIN_SHA256="f4957c8a0574721176ac3f4b1e2442d7bba75caedc5674f620657ef96b119587"
    ;;
  aarch64|arm64)
    PACKAGE_ARCH="arm64"
    DEFAULT_BIN_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/lanzoupan-client-linux-arm64-v1"
    DEFAULT_BIN_SHA256="befba42c2699f0f16438a982ca828606928ab30b6c87b6394530a6fa9d75e680"
    ;;
  x86_64|amd64)
    PACKAGE_ARCH="amd64"
    DEFAULT_BIN_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/lanzoupan-client-linux-amd64-v1"
    DEFAULT_BIN_SHA256="82092602f4abfa3ba5a1f2fef7c9acc504bde9ebc3861e16cb2bab3bafed33e3"
    ;;
  *)
    fatal "unsupported architecture: $ARCH"
    ;;
esac
BIN_URL="${LANZOUPAN_CLIENT_BIN_URL:-$DEFAULT_BIN_URL}"
BIN_SHA256="${LANZOUPAN_CLIENT_BIN_SHA256:-$DEFAULT_BIN_SHA256}"
has_cmd systemctl || fatal "systemd is required"

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/lanzoupan-client" >/dev/null 2>&1 || true

log "download binary for $PACKAGE_ARCH: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/lanzoupan-client"
chmod 0755 "$BIN_DIR/lanzoupan-client"

if fetch "$ICON_URL" "$ASSET_DIR/icon.png" >/dev/null 2>&1; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  log "icon installed"
else
  log "icon download failed, service install continues"
fi

cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
APP_DIR="$APP_DIR"
DATA_DIR="$DATA_DIR"
ADDR="\${LANZOUPAN_CLIENT_ADDRESS:-$ADDR}"
cd "$DATA_DIR"
EXTRA_ARGS="\${LANZOUPAN_CLIENT_ARGS:-}"
if [ -n "\$EXTRA_ARGS" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/lanzoupan-client" \$EXTRA_ARGS
fi
exec "$APP_DIR/bin/lanzoupan-client" -listen "\$ADDR"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Lanzou Cloud Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=LANZOUPAN_CLIENT_PORT=$PORT
Environment=LANZOUPAN_CLIENT_ADDRESS=$ADDR
Environment=TZ=Asia/Shanghai
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
蓝奏云盘 installed.
URL: http://device-ip:$PORT
Service: $APP_ID
Data: $DATA_DIR
Config: $DATA_DIR/lanzoupan-config.json
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 4
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  journalctl -u "$APP_ID" -n 120 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "service start failed, check: journalctl -u $APP_ID -n 120 --no-pager"
fi
log "install done: http://device-ip:$PORT"
