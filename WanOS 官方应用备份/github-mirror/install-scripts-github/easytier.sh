#!/bin/sh
set -eu

APP_ID="easytier"
APP_NAME="EasyTier"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
CORE_SERVICE="/etc/systemd/system/$APP_ID-node.service"
PORT="${EASYTIER_PORT:-11211}"
CONFIG_PORT="${EASYTIER_CONFIG_PORT:-22020}"
ICON_URL="${EASYTIER_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/easytier.png}"
TMP_PKG="$DATA_DIR/.tmp-$APP_ID.zip"
TMP_DIR="$DATA_DIR/.extract-$APP_ID"
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

extract_zip(){
  zip_file="$1"; out_dir="$2"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"
  if has_cmd unzip; then unzip -q "$zip_file" -d "$out_dir";
  elif has_cmd busybox; then busybox unzip -q "$zip_file" -d "$out_dir";
  elif has_cmd tar; then tar -xf "$zip_file" -C "$out_dir";
  else fatal "missing unzip/tar, cannot extract app package"; fi
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*|armhf|arm)
    PACKAGE_ARCH="armv7"
    PACKAGE_DIR="easytier-linux-armv7"
    DEFAULT_PKG_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/easytier-linux-armv7-v2.6.4.zip"
    DEFAULT_PKG_SHA256="93b1d2831e45db1fd3ca1d8d68c191b300bd69d331ca1858394a0cf884363cc3"
    ;;
  aarch64|arm64)
    PACKAGE_ARCH="arm64"
    PACKAGE_DIR="easytier-linux-aarch64"
    DEFAULT_PKG_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/easytier-linux-aarch64-v2.6.4.zip"
    DEFAULT_PKG_SHA256="f533ec25a7ea714e09f645615012200278058525795cc3bb690ff011aec1a70f"
    ;;
  x86_64|amd64)
    PACKAGE_ARCH="amd64"
    PACKAGE_DIR="easytier-linux-x86_64"
    DEFAULT_PKG_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/easytier-linux-x86_64-v2.6.4.zip"
    DEFAULT_PKG_SHA256="61b659eaedba658fa66fe47d17e1426cdd77e5d02fa15fed447bb4357c09dfd6"
    ;;
  *)
    fatal "unsupported architecture: $ARCH"
    ;;
esac
PKG_URL="${EASYTIER_PKG_URL:-$DEFAULT_PKG_URL}"
PKG_SHA256="${EASYTIER_PKG_SHA256:-$DEFAULT_PKG_SHA256}"
has_cmd systemctl || fatal "systemd is required"

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl stop "$APP_ID-node" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/easytier-web-embed" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/easytier-core" >/dev/null 2>&1 || true

log "download package for $PACKAGE_ARCH: $PKG_URL"
fetch "$PKG_URL" "$TMP_PKG" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_PKG")"
log "SHA256: $GOT"
[ "$GOT" = "$PKG_SHA256" ] || fatal "package SHA256 mismatch: want $PKG_SHA256 got $GOT"

extract_zip "$TMP_PKG" "$TMP_DIR"
[ -x "$TMP_DIR/$PACKAGE_DIR/easytier-web-embed" ] || fatal "easytier-web-embed not found in package"
rm -rf "$BIN_DIR"
mkdir -p "$BIN_DIR"
cp "$TMP_DIR/$PACKAGE_DIR/easytier-core" "$BIN_DIR/easytier-core"
cp "$TMP_DIR/$PACKAGE_DIR/easytier-cli" "$BIN_DIR/easytier-cli"
cp "$TMP_DIR/$PACKAGE_DIR/easytier-web" "$BIN_DIR/easytier-web"
cp "$TMP_DIR/$PACKAGE_DIR/easytier-web-embed" "$BIN_DIR/easytier-web-embed"
chmod 0755 "$BIN_DIR"/easytier-*
rm -rf "$TMP_DIR" "$TMP_PKG"

if fetch "$ICON_URL" "$ASSET_DIR/icon.png" >/dev/null 2>&1; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  log "icon installed"
else
  log "icon download failed, service install continues"
fi

cat >"$APP_DIR/run.sh" <<'EOF'
#!/bin/sh
set -eu
APP_DIR="${APP_DIR:-/opt/wanos/apps/easytier}"
DATA_DIR="${DATA_DIR:-/opt/wanos-data/apps/easytier}"
PORT="${EASYTIER_PORT:-11211}"
CONFIG_PORT="${EASYTIER_CONFIG_PORT:-22020}"
CONFIG_PROTO="${EASYTIER_CONFIG_PROTO:-udp}"
API_HOST="${EASYTIER_API_HOST:-}"
if [ -z "$API_HOST" ]; then
  IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -n "$IP" ] || IP="127.0.0.1"
  API_HOST="http://$IP:$PORT"
fi
mkdir -p "$DATA_DIR"
cd "$DATA_DIR"
exec "$APP_DIR/bin/easytier-web-embed" \
  --db "$DATA_DIR/et.db" \
  --api-server-port "$PORT" \
  --api-host "$API_HOST" \
  --config-server-port "$CONFIG_PORT" \
  --config-server-protocol "$CONFIG_PROTO"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$APP_DIR/run-core.sh" <<'EOF'
#!/bin/sh
set -eu
APP_DIR="${APP_DIR:-/opt/wanos/apps/easytier}"
DATA_DIR="${DATA_DIR:-/opt/wanos-data/apps/easytier}"
CONFIG_SERVER="${EASYTIER_CONFIG_SERVER:-udp://127.0.0.1:22020/admin}"
HOSTNAME_VALUE="${EASYTIER_HOSTNAME:-WanOS-$(hostname 2>/dev/null || echo device)}"
mkdir -p "$DATA_DIR/core"
cd "$DATA_DIR/core"
exec "$APP_DIR/bin/easytier-core" --hostname "$HOSTNAME_VALUE" -w "$CONFIG_SERVER"
EOF
chmod 0755 "$APP_DIR/run-core.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS EasyTier Web Console
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=APP_DIR=$APP_DIR
Environment=DATA_DIR=$DATA_DIR
Environment=EASYTIER_PORT=$PORT
Environment=EASYTIER_CONFIG_PORT=$CONFIG_PORT
Environment=EASYTIER_CONFIG_PROTO=udp
Environment=TZ=Asia/Shanghai
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$CORE_SERVICE" <<EOF
[Unit]
Description=WanOS EasyTier Local Node
After=network-online.target $APP_ID.service
Wants=network-online.target $APP_ID.service

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=APP_DIR=$APP_DIR
Environment=DATA_DIR=$DATA_DIR
Environment=EASYTIER_CONFIG_SERVER=udp://127.0.0.1:$CONFIG_PORT/admin
Environment=TZ=Asia/Shanghai
ExecStartPre=/bin/sleep 3
ExecStart=$APP_DIR/run-core.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
EasyTier installed.
Web console: http://device-ip:$PORT
Default accounts: admin/admin or user/user
Config delivery: udp://device-ip:$CONFIG_PORT
Local node service: $APP_ID-node
Service: $APP_ID
Data: $DATA_DIR
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl enable "$APP_ID-node" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
systemctl restart "$APP_ID-node"
sleep 4
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  journalctl -u "$APP_ID" -n 120 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "service start failed, check: journalctl -u $APP_ID -n 120 --no-pager"
fi
if ! systemctl is-active "$APP_ID-node" >/dev/null 2>&1; then
  systemctl status "$APP_ID-node" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  journalctl -u "$APP_ID-node" -n 120 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  log "local node service is not active yet, web console is available; check: journalctl -u $APP_ID-node -n 120 --no-pager"
fi
log "install done: http://device-ip:$PORT"
