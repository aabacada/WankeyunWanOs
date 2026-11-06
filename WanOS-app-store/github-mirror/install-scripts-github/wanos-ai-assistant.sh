#!/bin/sh
set -eu

APP_ID="wanos-ai-assistant"
APP_NAME="WanOS 智能助手"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN="$APP_DIR/$APP_ID"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${WANOS_AI_PORT:-18330}"
BASE_URL="${WANOS_AI_BASE_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106}"
BIN_BASE_URL="${WANOS_AI_BIN_BASE_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106}"
ICON_URL="${WANOS_AI_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/wanos-ai-assistant.png}"
DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-}"
TMP_BIN="$DATA_DIR/.download-$APP_ID"

ARMV7_URL="${WANOS_AI_ARMV7_URL:-$BIN_BASE_URL/wanos-ai-assistant-linux-armv7-v6}"
ARM64_URL="${WANOS_AI_ARM64_URL:-$BIN_BASE_URL/wanos-ai-assistant-linux-arm64-v6}"
AMD64_URL="${WANOS_AI_AMD64_URL:-$BIN_BASE_URL/wanos-ai-assistant-linux-amd64-v6}"
ARMV7_SHA256="${WANOS_AI_ARMV7_SHA256:-a7b2adf16b644e5943f887c5769d7399974feee55f646a9aa07826bee2cf29ce}"
ARM64_SHA256="${WANOS_AI_ARM64_SHA256:-e08282cd917e9ad93303f924be2468c8832505fb7794bbe1affb5637d4b46aed}"
AMD64_SHA256="${WANOS_AI_AMD64_SHA256:-b35b8dcb8087cf5291fdb018020fee5c41ce0ee24381b736149db81fe1202788}"

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

select_binary(){
  machine="$(uname -m 2>/dev/null || echo unknown)"
  case "$machine" in
    armv7l|armv7*|armhf) BIN_URL="$ARMV7_URL"; BIN_SHA256="$ARMV7_SHA256" ;;
    aarch64|arm64) BIN_URL="$ARM64_URL"; BIN_SHA256="$ARM64_SHA256" ;;
    x86_64|amd64) BIN_URL="$AMD64_URL"; BIN_SHA256="$AMD64_SHA256" ;;
    *) fatal "unsupported architecture: $machine" ;;
  esac
}

write_nginx_proxy(){
  log "skip nginx proxy config; assistant listens on port $PORT"
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "systemd is required"
select_binary

mkdir -p "$APP_DIR/assets" "$DATA_DIR/assets"

if [ ! -f "$DATA_DIR/token" ]; then
  if has_cmd openssl; then openssl rand -hex 16 >"$DATA_DIR/token";
  else tr -dc 'a-f0-9' </dev/urandom | head -c 32 >"$DATA_DIR/token"; printf '\n' >>"$DATA_DIR/token"; fi
  chmod 0600 "$DATA_DIR/token"
fi

if [ ! -f "$DATA_DIR/config.env" ]; then
  cat >"$DATA_DIR/config.env" <<EOF
DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY
DEEPSEEK_MODEL=deepseek-chat
WANOS_AI_TOKEN=$(cat "$DATA_DIR/token")
EOF
  chmod 0600 "$DATA_DIR/config.env"
elif [ -n "$DEEPSEEK_API_KEY" ] && ! grep -q '^DEEPSEEK_API_KEY=.' "$DATA_DIR/config.env" 2>/dev/null; then
  sed -i "s|^DEEPSEEK_API_KEY=.*|DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY|" "$DATA_DIR/config.env" 2>/dev/null || true
fi

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN"
got="$(sha256_file "$TMP_BIN")"
log "SHA256: $got"
[ "$got" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $got"
mv -f "$TMP_BIN" "$BIN"
chmod 0755 "$BIN"

if fetch "$ICON_URL" "$APP_DIR/assets/icon.png" >/dev/null 2>&1; then
  cp "$APP_DIR/assets/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$APP_DIR/assets/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
fi

cat >"$SERVICE" <<EOF
[Unit]
Description=$APP_NAME
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
EnvironmentFile=-$DATA_DIR/config.env
Environment=WANOS_AI_PORT=$PORT
Environment=WANOS_AI_DATA_DIR=$DATA_DIR
ExecStart=$BIN
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

write_nginx_proxy
systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"

log "install done: http://device-ip:$PORT"
log "token: $(cat "$DATA_DIR/token")"
