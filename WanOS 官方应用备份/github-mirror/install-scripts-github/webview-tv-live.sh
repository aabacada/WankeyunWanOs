#!/bin/sh
set -eu

APP_ID="webview-tv-live"
APP_NAME="IPTV电视直播"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${WEBVIEW_TV_LIVE_PORT:-8090}"
ADDR="${WEBVIEW_TV_LIVE_ADDRESS:-0.0.0.0:$PORT}"
ICON_URL="${WEBVIEW_TV_LIVE_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/webview-tv-live.png}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"
LOG_FILE="/var/log/wanos-$APP_ID-install.log"

log(){ printf '%s
' "[$APP_NAME] $*"; }
fatal(){ printf '%s
' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

runtime_arch(){
  case "$(uname -m 2>/dev/null || echo unknown)" in
    armv7l|armv7*|armhf|arm*) printf '%s' linux-armv7 ;;
    aarch64|arm64) printf '%s' linux-arm64 ;;
    x86_64|amd64) printf '%s' linux-amd64 ;;
    *) printf '%s' unknown ;;
  esac
}

select_package(){
  arch="$(runtime_arch)"
  case "$arch" in
    linux-armv7)
      BIN_URL="${WEBVIEW_TV_LIVE_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/webview-tv-live-linux-armv7-v2}"
      BIN_SHA256="${WEBVIEW_TV_LIVE_BIN_SHA256:-061762fd791a50068466d339001f6630cb5b5ed374de0651e39a38d8ae342697}"
      ;;
    linux-arm64)
      BIN_URL="${WEBVIEW_TV_LIVE_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/webview-tv-live-linux-arm64-v2}"
      BIN_SHA256="${WEBVIEW_TV_LIVE_BIN_SHA256:-7b77d0904df2796e3a6f63330fbe2707e91994de1cec4693a7c58b02cb7c8db6}"
      ;;
    linux-amd64)
      BIN_URL="${WEBVIEW_TV_LIVE_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/webview-tv-live-linux-amd64-v2}"
      BIN_SHA256="${WEBVIEW_TV_LIVE_BIN_SHA256:-0db9e29091453f84d94e76ca2f10a312fb9cea2cd81c8db0c9d91e489f01e840}"
      ;;
    *) fatal "unsupported architecture: $(uname -m 2>/dev/null || echo unknown)" ;;
  esac
  export BIN_URL BIN_SHA256
}

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
select_package
has_cmd systemctl || fatal "systemd is required"
mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/webview-tv-live" >/dev/null 2>&1 || true
log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/webview-tv-live"
chmod 0755 "$BIN_DIR/webview-tv-live"
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
ADDR="\${WEBVIEW_TV_LIVE_ADDRESS:-$ADDR}"
cd "$DATA_DIR"
if [ -n "\${WEBVIEW_TV_LIVE_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/webview-tv-live" \${WEBVIEW_TV_LIVE_ARGS}
fi
exec "$APP_DIR/bin/webview-tv-live" --addr "$ADDR"
EOF
chmod 0755 "$APP_DIR/run.sh"
cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS IPTV电视直播
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=WEBVIEW_TV_LIVE_PORT=$PORT
Environment=WEBVIEW_TV_LIVE_ADDRESS=$ADDR
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
IPTV电视直播 installed.
URL: http://device-ip:$PORT
Service: $APP_ID
Data: $DATA_DIR
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
