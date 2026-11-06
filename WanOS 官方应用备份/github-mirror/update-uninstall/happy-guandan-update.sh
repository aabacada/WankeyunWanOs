#!/bin/sh
set -eu

APP_ID="happy-guandan"
APP_NAME="happy-guandan"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${HAPPY_GUANDAN_PORT:-8095}"
HOST="${HAPPY_GUANDAN_HOST:-0.0.0.0}"
ICON_URL="${HAPPY_GUANDAN_ICON_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/happy-guandan/icon.png}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"
LOG_FILE="/var/log/wanos-$APP_ID-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
fetch(){
  url="$1"
  out="$2"
  if has_cmd curl; then
    curl -fL --connect-timeout 20 --max-time 1800 --retry 3 --retry-delay 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -O "$out" "$url"
  else
    fatal "missing curl/wget"
  fi
  [ -s "$out" ] || fatal "downloaded file is empty: $out"
}
sha256_file(){
  if has_cmd sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  elif has_cmd busybox; then
    busybox sha256sum "$1" | awk '{print $1}'
  else
    fatal "missing sha256sum"
  fi
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*|armhf|arm) PACKAGE_ARCH="armv7"; DEFAULT_BIN_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/happy-guandan/happy-guandan-linux-armv7-v3"; DEFAULT_BIN_SHA256="9b1d82d01324a4c0ef7112e3cc6b546855d5d00c76bec79114c6df6d6628903c" ;;
  aarch64|arm64) PACKAGE_ARCH="arm64"; DEFAULT_BIN_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/happy-guandan/happy-guandan-linux-arm64-v3"; DEFAULT_BIN_SHA256="996980c35aaf269c88e39dbe277a675a07cb888569a0e79a1a5e148cb1504f49" ;;
  x86_64|amd64) PACKAGE_ARCH="amd64"; DEFAULT_BIN_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/happy-guandan/happy-guandan-linux-amd64-v3"; DEFAULT_BIN_SHA256="3c02ced7060423a6b1bcbf79e0ef4eeeb777dbe5d3955e3e4b0111fc00e111fe" ;;
  *) fatal "unsupported architecture: $ARCH" ;;
esac

BIN_URL="${HAPPY_GUANDAN_BIN_URL:-$DEFAULT_BIN_URL}"
BIN_SHA256="${HAPPY_GUANDAN_BIN_SHA256:-$DEFAULT_BIN_SHA256}"
has_cmd systemctl || fatal "systemd is required"

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/happy-guandan" >/dev/null 2>&1 || true

log "download binary for $PACKAGE_ARCH: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/happy-guandan"
chmod 0755 "$BIN_DIR/happy-guandan"

if has_cmd curl; then
  curl -fL --connect-timeout 5 --max-time 20 --retry 1 -o "$ASSET_DIR/icon.png" "$ICON_URL" >/dev/null 2>&1 || true
elif has_cmd wget; then
  wget -T 20 -O "$ASSET_DIR/icon.png" "$ICON_URL" >/dev/null 2>&1 || true
fi
if [ -s "$ASSET_DIR/icon.png" ]; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  log "icon installed"
fi

cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
APP_DIR="$APP_DIR"
DATA_DIR="$DATA_DIR"
HOST="${HAPPY_GUANDAN_HOST:-$HOST}"
PORT="${HAPPY_GUANDAN_PORT:-$PORT}"
cd "\$DATA_DIR"
if [ -n "\${HAPPY_GUANDAN_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "\$APP_DIR/bin/happy-guandan" \${HAPPY_GUANDAN_ARGS}
fi
exec "\$APP_DIR/bin/happy-guandan" -host "\$HOST" -port "\$PORT" -no-open
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Happy Guandan
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=HAPPY_GUANDAN_PORT=$PORT
Environment=HAPPY_GUANDAN_HOST=$HOST
Environment=TZ=Asia/Shanghai
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 4
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  journalctl -u "$APP_ID" -n 120 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "service start failed"
fi
log "install done: http://device-ip:$PORT"
