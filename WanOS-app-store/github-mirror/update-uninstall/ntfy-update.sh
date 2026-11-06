#!/bin/sh
set -eu

APP_ID="ntfy"
APP_NAME="ntfy 通知服务"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${NTFY_PORT:-2586}"
ADDR="${NTFY_ADDRESS:-0.0.0.0:$PORT}"
BASE_URL="${NTFY_BASE_URL:-}"
BIN_URL="${NTFY_BIN_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/ntfy/ntfy-linux-armv7-v2.25.0}"
ICON_URL="${NTFY_ICON_URL:-https://wanos.xyz/downloads/apps/ntfy/icon.png}"
BIN_SHA256="${NTFY_BIN_SHA256:-144708ad2c1da4bae80d7467fb670b99b9166f3c7eb5d23fb9dcf668cc67e58c}"
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
pkill -f "$BIN_DIR/ntfy" >/dev/null 2>&1 || true

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/ntfy"
chmod 0755 "$BIN_DIR/ntfy"

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
ADDR="\${NTFY_ADDRESS:-$ADDR}"
BASE_URL="\${NTFY_BASE_URL:-$BASE_URL}"
cd "$DATA_DIR"
mkdir -p "$DATA_DIR/attachments"
if [ -z "\$BASE_URL" ]; then
  ip="\$(hostname -I 2>/dev/null | awk '{print \$1}')"
  [ -n "\$ip" ] || ip="127.0.0.1"
  BASE_URL="http://\$ip:$PORT"
fi
if [ -n "\${NTFY_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/ntfy" \${NTFY_ARGS}
fi
exec "$APP_DIR/bin/ntfy" serve --listen-http "\$ADDR" --base-url "\$BASE_URL" --cache-file "$DATA_DIR/cache.db" --attachment-cache-dir "$DATA_DIR/attachments"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS ntfy 通知服务
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=NTFY_PORT=$PORT
Environment=NTFY_ADDRESS=$ADDR
Environment=NTFY_BASE_URL=$BASE_URL
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
ntfy 通知服务 installed.
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
