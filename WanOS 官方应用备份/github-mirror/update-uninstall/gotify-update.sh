#!/bin/sh
set -eu

APP_ID="gotify"
APP_NAME="Gotify 通知服务"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${GOTIFY_PORT:-2587}"
ADDR="${GOTIFY_ADDRESS:-0.0.0.0:$PORT}"
BIN_URL="${GOTIFY_BIN_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/gotify/gotify-linux-armv7-v2.9.1}"
ICON_URL="${GOTIFY_ICON_URL:-https://wanos.xyz/downloads/apps/gotify/icon.png}"
BIN_SHA256="${GOTIFY_BIN_SHA256:-6d409753889bfb47c90503818e1cca430b728fca8ab03c814a45ec07d8ce16bc}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"
LOG_FILE="/var/log/wanos-$APP_ID-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
has_systemd(){ has_cmd systemctl && [ -d /run/systemd/system ]; }

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
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "unsupported architecture, ARMv7/armhf required" ;; esac

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
: >"$LOG_FILE" 2>/dev/null || true
if has_systemd; then
  systemctl stop "$APP_ID" >/dev/null 2>&1 || true
fi
[ -f "$DATA_DIR/$APP_ID.pid" ] && kill "$(cat "$DATA_DIR/$APP_ID.pid" 2>/dev/null)" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/gotify" >/dev/null 2>&1 || true

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/gotify"
chmod 0755 "$BIN_DIR/gotify"

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
ADDR="\${GOTIFY_ADDRESS:-$ADDR}"
cd "$DATA_DIR"
export GOTIFY_SERVER_PORT="\${GOTIFY_SERVER_PORT:-$PORT}"
export GOTIFY_SERVER_LISTENADDR="\${GOTIFY_SERVER_LISTENADDR:-0.0.0.0}"
export GOTIFY_DATABASE_DIALECT="\${GOTIFY_DATABASE_DIALECT:-sqlite3}"
export GOTIFY_DATABASE_CONNECTION="\${GOTIFY_DATABASE_CONNECTION:-data/gotify.db}"
if [ -n "\${GOTIFY_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/gotify" \${GOTIFY_ARGS}
fi
exec "$APP_DIR/bin/gotify"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Gotify 通知服务
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=GOTIFY_PORT=$PORT
Environment=GOTIFY_ADDRESS=$ADDR
Environment=TZ=Asia/Shanghai
Environment=GOTIFY_SERVER_PORT=2587
Environment=GOTIFY_SERVER_LISTENADDR=0.0.0.0
Environment=GOTIFY_DATABASE_DIALECT=sqlite3
Environment=GOTIFY_DATABASE_CONNECTION=data/gotify.db
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
Gotify 通知服务 installed.
URL: http://device-ip:$PORT
Service: $APP_ID
Data: $DATA_DIR
EOF

if has_systemd; then
  systemctl daemon-reload
  systemctl enable "$APP_ID" >/dev/null 2>&1 || true
  systemctl restart "$APP_ID"
  sleep 4
  if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
    systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
    journalctl -u "$APP_ID" -n 120 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
    fatal "service start failed, check: journalctl -u $APP_ID -n 120 --no-pager"
  fi
else
  log "systemd not detected, start with background process"
  nohup "$APP_DIR/run.sh" >>"$DATA_DIR/$APP_ID.log" 2>&1 &
  echo "$!" >"$DATA_DIR/$APP_ID.pid"
  sleep 4
  if ! kill -0 "$(cat "$DATA_DIR/$APP_ID.pid" 2>/dev/null)" >/dev/null 2>&1; then
    tail -n 120 "$DATA_DIR/$APP_ID.log" 2>/dev/null | tee -a "$LOG_FILE" || true
    fatal "service start failed, check: $DATA_DIR/$APP_ID.log"
  fi
fi
log "install done: http://device-ip:$PORT"
