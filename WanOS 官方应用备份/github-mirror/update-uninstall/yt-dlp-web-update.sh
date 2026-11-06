#!/bin/sh
set -eu
APP_ID="yt-dlp-web"
APP_NAME="YT-DLP Web"
APP_DIR="${WANOS_APP_INSTALL_DIR:-${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/yt-dlp-web}}"
DATA_DIR="${WANOS_APP_DATA_DIR:-${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/yt-dlp-web}}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/yt-dlp-web/yt-dlp-web-armhf-wanos.tar.gz"
PKG_SHA="8d93f83e640d108b93a6003ea3d1652152b9187036cb7fc6ed3cfac44c3e0cff"
PORT="${YTDLP_WEB_PORT:-50000}"
log(){ echo "[YT-DLP] $*"; }
fatal(){ echo "[YT-DLP] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
sha_check(){ file="$1"; want="$2"; got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || fatal "package sha256 mismatch: want $want got $got"; }
fetch(){ url="$1"; out="$2"; if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 900 --retry 2 "$url" -o "$out"; elif has_cmd wget; then wget -O "$out" "$url"; else fatal "missing curl/wget"; fi; }
[ "$(id -u)" = "0" ] || fatal "root is required"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "ARMv7/armhf is required" ;; esac
has_cmd sha256sum || fatal "missing sha256sum"
has_cmd awk || fatal "missing awk"
has_cmd tar || fatal "missing tar"
if ! has_cmd ffmpeg; then log "ffmpeg not found; merge/transcode features may be unavailable"; fi
mkdir -p "$APP_DIR" "$DATA_DIR/downloads" "$TMP_DIR"
ARCHIVE="$TMP_DIR/yt-dlp-web-armhf-wanos.tar.gz"
log "download package: $PKG_URL"
fetch "$PKG_URL" "$ARCHIVE"
sha_check "$ARCHIVE" "$PKG_SHA"
rm -rf "$TMP_DIR/extract"
mkdir -p "$TMP_DIR/extract"
tar -xzf "$ARCHIVE" -C "$TMP_DIR/extract"
[ -d "$TMP_DIR/extract/yt-dlp-web" ] || fatal "yt-dlp-web directory not found in package"
rm -rf "$APP_DIR/app" "$APP_DIR/bin"
cp -a "$TMP_DIR/extract/yt-dlp-web/app" "$APP_DIR/app"
cp -a "$TMP_DIR/extract/yt-dlp-web/bin" "$APP_DIR/bin"
chmod 755 "$APP_DIR/app/dlp" "$APP_DIR/bin/yt-dlp"
cat >"/etc/systemd/system/yt-dlp-web.service" <<EOF
[Unit]
Description=WanOS YT-DLP Web
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR/app
Environment=PATH=$APP_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=HOME=$DATA_DIR
Environment=YTDLP_DOWNLOAD_DIR=$DATA_DIR/downloads
ExecStart=$APP_DIR/app/dlp
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
echo "1.0.0-wanos.1" > "$APP_DIR/version"
systemctl daemon-reload
systemctl enable yt-dlp-web >/dev/null 2>&1 || true
systemctl restart yt-dlp-web
sleep 3
systemctl is-active --quiet yt-dlp-web || { systemctl status yt-dlp-web --no-pager -l || true; fatal "service start failed"; }
rm -rf "$TMP_DIR"
log "installed; web port: $PORT; download dir: $DATA_DIR/downloads"
