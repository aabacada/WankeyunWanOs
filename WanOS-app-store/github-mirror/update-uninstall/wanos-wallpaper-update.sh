#!/bin/sh
set -eu

APP_ID="wanos-wallpaper"
APP_NAME="WanOS 壁纸"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${WANOS_WALLPAPER_PORT:-18344}"
INDEX_URL="${WANOS_WALLPAPER_INDEX_URL:-https://wxqun988.vxjuejin.com/wanos/wallpapers/netbian/index.json}"
ICON_URL="${WANOS_WALLPAPER_ICON_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/icon-v3.png}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 900 --retry 3 --retry-delay 2 -o "$out" "$url";
  elif has_cmd wget; then wget -O "$out" "$url";
  else fatal "missing curl/wget"; fi
  [ -s "$out" ] || fatal "downloaded file is empty: $url"
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "missing sha256sum"; fi
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "systemd is required"

ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*|armhf|arm)
    PACKAGE_ARCH="linux-armv7"
    BIN_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/wanos-wallpaper-linux-armv7-v4"
    BIN_SHA256="090e697af5013fa9bf38f7b3d1e1a152005cd79b9a71aeb4b55867d4baa16cd6"
    ;;
  aarch64|arm64)
    PACKAGE_ARCH="linux-arm64"
    BIN_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/wanos-wallpaper-linux-arm64-v4"
    BIN_SHA256="56dce072a6f144b1228ad386ddccec7f598c36849bc5cdabaaa5c1a968845757"
    ;;
  x86_64|amd64)
    PACKAGE_ARCH="linux-amd64"
    BIN_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/wanos-wallpaper-linux-amd64-v4"
    BIN_SHA256="f9d40cc489e8237de1fcfcb5ebcc9949138d8a7762d4e10bb4e5d30c1f47a8a0"
    ;;
  *) fatal "unsupported architecture: $ARCH" ;;
esac

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
systemctl stop "$APP_ID" >/dev/null 2>&1 || true

log "download binary for $PACKAGE_ARCH: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/$APP_ID"
chmod 0755 "$BIN_DIR/$APP_ID"

if fetch "$ICON_URL" "$ASSET_DIR/icon.png" >/dev/null 2>&1; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
fi

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Wallpaper
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=WANOS_APP_PORT=$PORT
Environment=WANOS_APP_DATA=$DATA_DIR
Environment=WANOS_WALLPAPER_INDEX_URL=$INDEX_URL
ExecStart=$BIN_DIR/$APP_ID --addr 0.0.0.0:$PORT --data $DATA_DIR
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
sleep 2
systemctl is-active "$APP_ID" >/dev/null 2>&1 || fatal "service start failed"
log "install done: http://device-ip:$PORT"
