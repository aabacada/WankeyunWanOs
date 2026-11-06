#!/bin/sh
set -eu

APP_ID="xiaozhi-server"
APP_NAME="小智AI服务端"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${XIAOZHI_SERVER_PORT:-18081}"
ADDR="${XIAOZHI_SERVER_ADDRESS:-0.0.0.0:$PORT}"
BIN_URL="${XIAOZHI_SERVER_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/xiaozhi-server-linux-armv7-v2}"
ICON_URL="${XIAOZHI_SERVER_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/xiaozhi-server.png}"
BIN_SHA256="${XIAOZHI_SERVER_BIN_SHA256:-2cb33a4998070502de77a5c35fa8aa8b46f9fa09ac55ce1c439e4e33365f25bc}"
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
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "unsupported architecture, ARMv7/armhf required" ;; esac
has_cmd systemctl || fatal "systemd is required"

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/xiaozhi-server" >/dev/null 2>&1 || true

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/xiaozhi-server"
chmod 0755 "$BIN_DIR/xiaozhi-server"

if fetch "$ICON_URL" "$ASSET_DIR/icon.png" >/dev/null 2>&1; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  log "icon installed"
else
  log "icon download failed, service install continues"
fi


mkdir -p "$DATA_DIR/logs" "$DATA_DIR/data" "$DATA_DIR/storage/speakers" "$DATA_DIR/data/chat_history/audio"
if [ ! -s "$DATA_DIR/config.yaml" ]; then
cat >"$DATA_DIR/config.yaml" <<'WANOS_XIAOZHI_CONFIG'
server:
  pprof:
    enable: false
    port: 6060

auth:
  enable: false

chat:
  max_idle_duration: 30000
  chat_max_silence_duration: 400
  speak_request_reuse_window_ms: 60000
  realtime_mode: 4

chat_hooks:
  enabled: true
  async:
    queue_size: 1024
    worker_count: 1
    drop_when_full: false
    timeout_ms: 200
  plugins:
    statistic_plugin:
      enabled: true
      priority: 100

config_provider:
  type: "manager"
  enable_periodic_update: true
  update_interval: "5m"

manager:
  backend_url: "http://127.0.0.1:18081"
  auth_token: "xiaozhi_admin_secret_key"
  endpoint_auth_token: "xiaozhi_mcp_openclaw_secret_key"
  history_timeout: 5s

system_prompt: "????AI???"

log:
  path: "logs/"
  file: "server.log"
  level: "info"
  max_age: 3
  rotation_time: 10
  stdout: true

redis:
  host: "127.0.0.1"
  port: 6379
  password: ""
  db: 0
  key_prefix: "xiaozhi"

websocket:
  host: "0.0.0.0"
  port: 8989

mqtt:
  enable: true
  broker: "127.0.0.1"
  type: "tcp"
  port: 2883
  client_id: "xiaozhi_server"
  username: "admin"
  password: "test!@#"

mqtt_server:
  enable: true
  listen_host: "0.0.0.0"
  listen_port: 2883
  client_id: "xiaozhi_server"
  username: "admin"
  password: "test!@#"
  signature_key: "wanos_xiaozhi_ota_signature_key"
  enable_auth: false
  tls:
    enable: false
    port: 8883
    pem: "config/server.pem"
    key: "config/server.key"

udp:
  external_host: "127.0.0.1"
  external_port: 8990
  listen_host: "0.0.0.0"
  listen_port: 8990

resource_pools:
  max_size: 1000
  min_size: 1
  max_idle: 50
  acquire_timeout: 5s
  idle_timeout: 10m
  validate_on_borrow: true
  validate_on_return: true

vad:
  provider: "webrtc_vad"
  webrtc_vad:
    pool_min_size: 5
    pool_max_size: 1000
    pool_max_idle: 100
    vad_sample_rate: 16000
    vad_mode: 2

asr:
  provider: "doubao"
  doubao:
    appid: ""
    access_token: ""
    ws_url: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_nostream"
    model_name: "bigmodel"
    end_window_size: 800
    enable_punc: true
    enable_itn: true
    enable_ddc: false
    timeout: 30

tts:
  provider: "doubao_ws"
  doubao_ws:
    appid: ""
    access_token: ""
    model: "seed-tts-1.1"
    resource_id: ""
    voice: ""
    ws_url: "wss://openspeech.bytedance.com/api/v3/tts/unidirectional/stream"

llm:
  provider: "openai"
  openai:
    api_key: ""
    base_url: "https://api.openai.com/v1"
    model: "gpt-4o-mini"

mcp:
  enabled: false

local_mcp:
  enabled: false

ota:
  websocket:
    url: "ws://127.0.0.1:8989/xiaozhi/v1/"
  mqtt:
    enable: false
    endpoint: "127.0.0.1:2883"

WANOS_XIAOZHI_CONFIG
fi
if [ ! -s "$DATA_DIR/manager.json" ]; then
cat >"$DATA_DIR/manager.json" <<'WANOS_XIAOZHI_MANAGER'
{
  "server": {
    "port": "18081",
    "mode": "release"
  },
  "database": {
    "type": "sqlite",
    "mysql": {
      "host": "127.0.0.1",
      "port": 3306,
      "username": "root",
      "password": "",
      "database": "xiaozhi"
    },
    "sqlite": {
      "file_path": "./data/xiaozhi.db"
    }
  },
  "jwt": {
    "secret": "xiaozhi_admin_secret_key",
    "expire_hour": 24
  },
  "internal_auth_token": "xiaozhi_admin_secret_key",
  "endpoint_auth_token": "xiaozhi_mcp_openclaw_secret_key",
  "speaker_service": {
    "url": "http://127.0.0.1:9000"
  },
  "storage": {
    "speaker_audio_path": "storage/speakers",
    "max_file_size": 10485760
  },
  "history": {
    "enabled": true,
    "audio_base_path": "./data/chat_history/audio",
    "max_file_size": 10485760
  }
}
WANOS_XIAOZHI_MANAGER
fi

cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
APP_DIR="$APP_DIR"
DATA_DIR="$DATA_DIR"
ADDR="\${XIAOZHI_SERVER_ADDRESS:-$ADDR}"
cd "$DATA_DIR"
if [ -n "\${XIAOZHI_SERVER_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/xiaozhi-server" \${XIAOZHI_SERVER_ARGS}
fi
exec "$APP_DIR/bin/xiaozhi-server" -c "$DATA_DIR/config.yaml" -manager-enable -manager-config "$DATA_DIR/manager.json"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS 小智AI服务端
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=XIAOZHI_SERVER_PORT=$PORT
Environment=XIAOZHI_SERVER_ADDRESS=$ADDR
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
小智AI服务端 installed.
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
