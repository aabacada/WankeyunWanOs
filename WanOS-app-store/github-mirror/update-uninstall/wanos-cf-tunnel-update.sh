#!/bin/sh
set -eu

APP_ID="wanos-cf-tunnel"
APP_NAME="WanOS Cloudflare Tunnel"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${WANOS_CF_TUNNEL_PORT:-41644}"
ADDR="${WANOS_CF_TUNNEL_LISTEN:-0.0.0.0:$PORT}"
BIN_URL="${WANOS_CF_TUNNEL_BIN_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-cf-tunnel/wanos-cf-tunnel-linux-armv7-v4}"
ICON_URL="${WANOS_CF_TUNNEL_ICON_URL:-https://wanos.xyz/downloads/apps/wanos-cf-tunnel/icon.png}"
BIN_SHA256="${WANOS_CF_TUNNEL_BIN_SHA256:-7e955a72c7f5e340763b8aadd8b2b4d55845705e755bc25c7182e4d0060490da}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"
PID_FILE="$DATA_DIR/$APP_ID.pid"
LOG_FILE="$DATA_DIR/$APP_ID.log"

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

stop_app(){
  if has_cmd systemctl; then
    systemctl stop "$APP_ID" >/dev/null 2>&1 || true
  fi
  if [ -s "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" >/dev/null 2>&1 || true
    rm -f "$PID_FILE"
  fi
  pkill -f "$BIN_DIR/wanos-cf-tunnel" >/dev/null 2>&1 || true
}

start_fallback(){
  stop_app
  nohup "$APP_DIR/run.sh" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 2
  if ! kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
    tail -n 80 "$LOG_FILE" 2>/dev/null || true
    fatal "background process start failed"
  fi
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "unsupported architecture, ARMv7/armhf required" ;; esac

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
stop_app

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/wanos-cf-tunnel"
chmod 0755 "$BIN_DIR/wanos-cf-tunnel"

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
export WANOS_CF_TUNNEL_APP="$APP_DIR"
export WANOS_CF_TUNNEL_DATA="$DATA_DIR"
export WANOS_CF_TUNNEL_LISTEN="$ADDR"
export TZ=Asia/Shanghai
cd "$DATA_DIR"
exec "$BIN_DIR/wanos-cf-tunnel"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$APP_DIR/README-WanOS.txt" <<EOF
WanOS Cloudflare Tunnel installed.
Panel: http://device-ip:$PORT
Service: $APP_ID
Data: $DATA_DIR
EOF

if has_cmd systemctl; then
  cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
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
  sleep 3
  systemctl is-active "$APP_ID" >/dev/null 2>&1 || fatal "systemd service start failed"
else
  start_fallback
  if [ -f /etc/rc.local ] && ! grep -q "$APP_DIR/run.sh" /etc/rc.local 2>/dev/null; then
    cp /etc/rc.local /etc/rc.local.wanos-cf-tunnel.bak 2>/dev/null || true
    sed -i '/^exit 0/i nohup '"$APP_DIR"'/run.sh >>'"$LOG_FILE"' 2>&1 &' /etc/rc.local 2>/dev/null || true
  fi
fi

log "install done: http://device-ip:$PORT"
