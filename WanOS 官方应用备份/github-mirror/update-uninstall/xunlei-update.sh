#!/bin/sh
set -eu

APP_ID="xunlei"
APP_NAME="Xunlei"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${XUNLEI_PORT:-2345}"
DASHBOARD_IP="${XUNLEI_DASHBOARD_IP:-0.0.0.0}"
ROOT_DIR="${XUNLEI_ROOT_DIR:-$DATA_DIR/rootfs}"
STORAGE_ROOT="${WANOS_STORAGE_ROOT:-/mnt/storage/mybox}"
HOST_DOWNLOAD_DIR="${XUNLEI_DOWNLOAD_DIR:-$STORAGE_ROOT/downloads/xunlei}"
OLD_DOWNLOAD_DIR="$ROOT_DIR/downloads"
DOWNLOAD_DIR="$ROOT_DIR/downloads"
DRIVE_DIR="${XUNLEI_DRIVE_DIR:-$ROOT_DIR/data}"
SPK_CACHE_DIR="${XUNLEI_SPK_CACHE_DIR:-$ROOT_DIR/spk-cache}"
ICON_URL="${XUNLEI_ICON_URL:-https://wanos.xyz/downloads/apps/xunlei/icon.png}"
ARM64_URL="${XUNLEI_ARM64_BIN_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/xunlei/xunlei-linux-arm64-v2}"
AMD64_URL="${XUNLEI_AMD64_BIN_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/xunlei/xunlei-linux-amd64-v2}"
ARM64_SHA256="${XUNLEI_ARM64_BIN_SHA256:-121b80eea1364e7b336fca0823f2611c081afea8be90512914750db161a7e4af}"
AMD64_SHA256="${XUNLEI_AMD64_BIN_SHA256:-c19aa2f3b8761ecf80e9546b015c5794265ed52f8294b627ae1b45b1452bd0be}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"
LOG_FILE="/var/log/wanos-$APP_ID-install.log"

log(){ printf '%s
' "[$APP_NAME] $*"; }
fatal(){ printf '%s
' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
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

select_binary(){
  arch="$(uname -m 2>/dev/null || echo unknown)"
  case "$arch" in
    aarch64|arm64) BIN_URL="$ARM64_URL"; BIN_SHA256="$ARM64_SHA256" ;;
    x86_64|amd64) BIN_URL="$AMD64_URL"; BIN_SHA256="$AMD64_SHA256" ;;
    *) fatal "unsupported architecture: $arch. This app supports linux-arm64 and linux-amd64 only." ;;
  esac
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "systemd is required"
select_binary

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR" "$HOST_DOWNLOAD_DIR" "$DOWNLOAD_DIR" "$ROOT_DIR" "$DRIVE_DIR" "$SPK_CACHE_DIR"
if [ "$OLD_DOWNLOAD_DIR" != "$HOST_DOWNLOAD_DIR" ] && [ -d "$OLD_DOWNLOAD_DIR" ] && ! mountpoint -q "$OLD_DOWNLOAD_DIR" 2>/dev/null; then
  log "migrate old downloads: $OLD_DOWNLOAD_DIR -> $HOST_DOWNLOAD_DIR"
  mkdir -p "$HOST_DOWNLOAD_DIR"
  find "$OLD_DOWNLOAD_DIR" -mindepth 1 -maxdepth 1 -exec mv -f {} "$HOST_DOWNLOAD_DIR"/ \; 2>/dev/null || true
fi
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/xunlei" >/dev/null 2>&1 || true

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/xunlei"
chmod 0755 "$BIN_DIR/xunlei"

if fetch "$ICON_URL" "$ASSET_DIR/icon.png" >/dev/null 2>&1; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
fi

cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
APP_DIR="$APP_DIR"
DATA_DIR="$DATA_DIR"
HOST_DOWNLOAD_DIR="$HOST_DOWNLOAD_DIR"
DOWNLOAD_DIR="$DOWNLOAD_DIR"
cd "$DATA_DIR"
mkdir -p "$HOST_DOWNLOAD_DIR" "$DOWNLOAD_DIR"
if ! mountpoint -q "$DOWNLOAD_DIR" 2>/dev/null; then
  mount --bind "$HOST_DOWNLOAD_DIR" "$DOWNLOAD_DIR"
fi
if [ -n "\${XUNLEI_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/xunlei" \${XUNLEI_ARGS}
fi
exec "$APP_DIR/bin/xunlei" \
  --dashboard_port "$PORT" \
  --dashboard_ip "$DASHBOARD_IP" \
  --dir_download "$DOWNLOAD_DIR" \
  --dir_data "$DRIVE_DIR" \
  --root "$ROOT_DIR" \
  --uid 0 \
  --gid 0
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Xunlei Remote Download
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=TZ=Asia/Shanghai
Environment=XUNLEI_PORT=$PORT
Environment=XUNLEI_DASHBOARD_IP=$DASHBOARD_IP
Environment=XUNLEI_DOWNLOAD_DIR=$DOWNLOAD_DIR
Environment=XUNLEI_HOST_DOWNLOAD_DIR=$HOST_DOWNLOAD_DIR
Environment=XUNLEI_ROOT_DIR=$ROOT_DIR
Environment=XUNLEI_DRIVE_DIR=$DRIVE_DIR
Environment=XUNLEI_SPK_CACHE_DIR=$SPK_CACHE_DIR
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
Xunlei installed without Docker.
URL: http://device-ip:$PORT
Service: $APP_ID
Data: $DATA_DIR
Downloads: $HOST_DOWNLOAD_DIR
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 6
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  journalctl -u "$APP_ID" -n 160 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "service start failed, check: journalctl -u $APP_ID -n 160 --no-pager"
fi
log "install done: http://device-ip:$PORT"
