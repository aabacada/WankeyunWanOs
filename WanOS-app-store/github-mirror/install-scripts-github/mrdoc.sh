#!/bin/sh
set -eu
APP_ID="mrdoc"
APP_NAME="MrDoc"
APP_DIR="${WANOS_APP_INSTALL_DIR:-${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/mrdoc}}"
DATA_DIR="${WANOS_APP_DATA_DIR:-${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/mrdoc}}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
MRDOC_NGINX_LOG_DIR="/var/log/wanos/apps/mrdoc"
PKG_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/mrdoc-armhf.tar.gz"
PKG_SHA="6117115e192e623816486b9b2683bc0cbc74d39f9abf789015cbddccd323bb6d"
PORT="${MRDOC_PORT:-10888}"
log(){ echo "[MrDoc] $*"; }
fatal(){ echo "[MrDoc] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
sha_check(){ file="$1"; want="$2"; got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || fatal "package sha256 mismatch: want $want got $got"; }
fetch(){ url="$1"; out="$2"; if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 900 --retry 2 "$url" -o "$out"; elif has_cmd wget; then wget -O "$out" "$url"; else fatal "missing curl/wget"; fi; }
[ "$(id -u)" = "0" ] || fatal "root is required"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "ARMv7/armhf is required" ;; esac
has_cmd sha256sum || fatal "missing sha256sum"
has_cmd awk || fatal "missing awk"
has_cmd tar || fatal "missing tar"
if ! has_cmd nginx; then fatal "missing nginx; please update WanOS base system first"; fi
if ! has_cmd uwsgi; then
  log "uwsgi not found, installing uwsgi-plugin-python3 and python3.8-venv"
  has_cmd apt-get || fatal "missing uwsgi and apt-get is unavailable"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y uwsgi-plugin-python3 python3.8-venv
fi
has_cmd uwsgi || fatal "uwsgi install failed"
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR" "$MRDOC_NGINX_LOG_DIR"
ARCHIVE="$TMP_DIR/mrdoc-armhf.tar.gz"
log "download package: $PKG_URL"
fetch "$PKG_URL" "$ARCHIVE"
sha_check "$ARCHIVE" "$PKG_SHA"
rm -rf "$TMP_DIR/extract" "$APP_DIR/MrDoc" "$APP_DIR/mrdoc_env" "$APP_DIR/mrdoc_deploy"
mkdir -p "$TMP_DIR/extract"
tar -xzf "$ARCHIVE" -C "$TMP_DIR/extract"
[ -d "$TMP_DIR/extract/MrDoc" ] || fatal "MrDoc directory not found in package"
cp -a "$TMP_DIR/extract/MrDoc" "$APP_DIR/MrDoc"
cp -a "$TMP_DIR/extract/mrdoc_env" "$APP_DIR/mrdoc_env"
cp -a "$TMP_DIR/extract/mrdoc_deploy" "$APP_DIR/mrdoc_deploy"
mkdir -p "$DATA_DIR/media" "$DATA_DIR/log" "$DATA_DIR/db"
if [ ! -f "$DATA_DIR/db/db.sqlite3" ] && [ -f "$APP_DIR/MrDoc/config/db.sqlite3" ]; then cp "$APP_DIR/MrDoc/config/db.sqlite3" "$DATA_DIR/db/db.sqlite3"; fi
rm -f "$APP_DIR/MrDoc/config/db.sqlite3"
ln -sfn "$DATA_DIR/db/db.sqlite3" "$APP_DIR/MrDoc/config/db.sqlite3"
rm -rf "$APP_DIR/MrDoc/media"
ln -sfn "$DATA_DIR/media" "$APP_DIR/MrDoc/media"
cat >"$APP_DIR/mrdoc_deploy/mrdoc_uwsgi.ini" <<EOF
[uwsgi]
socket = 127.0.0.1:8008
chdir = $APP_DIR/MrDoc
virtualenv = $APP_DIR/mrdoc_env
module = MrDoc.wsgi:application
wsgi-file = MrDoc/wsgi.py
master = true
processes = 1
threads = 1
plugins = python3
vacuum = true
pidfile = /run/mrdoc-wanos.pid
EOF
cat >"/etc/systemd/system/mrdoc.service" <<EOF
[Unit]
Description=WanOS MrDoc
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR/MrDoc
ExecStart=/usr/bin/uwsgi --ini $APP_DIR/mrdoc_deploy/mrdoc_uwsgi.ini
ExecStop=/usr/bin/uwsgi --stop /run/mrdoc-wanos.pid
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/nginx/sites-available/mrdoc-wanos.conf" <<EOF
server {
    listen $PORT;
    charset UTF-8;
    client_max_body_size 75M;
    access_log $MRDOC_NGINX_LOG_DIR/nginx_access.log;
    error_log $MRDOC_NGINX_LOG_DIR/nginx_error.log;
    gzip on;
    gzip_min_length 1k;
    gzip_comp_level 5;
    gzip_types text/plain application/javascript application/x-javascript text/javascript text/xml text/css;
    gzip_vary on;
    location / {
        include $APP_DIR/mrdoc_deploy/uwsgi_params;
        uwsgi_pass 127.0.0.1:8008;
        uwsgi_read_timeout 60;
    }
    location /static {
        expires 30d;
        autoindex on;
        add_header Cache-Control private;
        alias $APP_DIR/MrDoc/static;
    }
    location /media {
        alias $DATA_DIR/media;
    }
}
EOF
rm -f /etc/nginx/sites-enabled/mrdoc_nginx.conf /etc/nginx/sites-enabled/mrdoc-wanos.conf
ln -s /etc/nginx/sites-available/mrdoc-wanos.conf /etc/nginx/sites-enabled/mrdoc-wanos.conf
nginx -t || fatal "nginx config test failed"
echo "1.0.0-wanos.1" > "$APP_DIR/version"
systemctl daemon-reload
systemctl enable mrdoc >/dev/null 2>&1 || true
systemctl restart nginx
systemctl restart mrdoc
sleep 3
systemctl is-active --quiet mrdoc || { systemctl status mrdoc --no-pager -l || true; fatal "service start failed"; }
rm -rf "$TMP_DIR"
log "installed; web port: $PORT"
