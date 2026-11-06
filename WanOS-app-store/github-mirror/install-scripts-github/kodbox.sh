#!/bin/sh
set -eu
APP_ID="kodbox"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PORT="${KODBOX_PORT:-8181}"
PKG_URL="${KODBOX_PKG_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/kodbox-main_20260604.zip}"
PKG_SHA256="${KODBOX_PKG_SHA256:-a737f0e8a88efed6f97a2adec30cc92463995b1c7442abbd5c10f4dd2492907e}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-kodbox-install.log"
log(){ printf '%s\n' "[KodBox] $*"; }
fatal(){ printf '%s\n' "[KodBox] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3 解压源码包。"
if ! has_cmd curl && ! has_cmd wget; then fatal "本应用需要 curl 或 wget。"; fi
ensure_php_deps(){
  missing=""
  if ! has_cmd php; then missing="$missing php-cli"; fi
  if has_cmd php; then
    for ext in sqlite3 mbstring gd xml curl zip json session pdo pdo_sqlite; do
      php -m 2>/dev/null | grep -qi "^$ext$" || missing="$missing php-$ext"
    done
  fi
  if [ -n "$missing" ]; then
    if has_cmd apt-get; then
      log "安装/补齐 PHP 运行依赖：$missing"
      apt-get update 2>&1 | tee -a "$LOG_FILE" || true
      DEBIAN_FRONTEND=noninteractive apt-get install -y php-cli php-sqlite3 php-mbstring php-gd php-xml php-curl php-zip php-json 2>&1 | tee -a "$LOG_FILE" || fatal "PHP 依赖安装失败"
    else
      fatal "PHP 运行依赖不完整，并且系统没有 apt-get，无法运行可道云。缺少：$missing"
    fi
  fi
  php -m 2>/dev/null | tee -a "$LOG_FILE" >/dev/null || true
}
ensure_php_deps
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/kodbox.zip"
log "下载可道云源码包：$PKG_URL"
if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; else wget -O "$ARCHIVE" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE"; fi
if has_cmd sha256sum; then got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"; [ "$got" = "$PKG_SHA256" ] || fatal "源码包校验失败：want $PKG_SHA256 got $got"; fi
rm -rf "$APP_DIR/www.new"
mkdir -p "$APP_DIR/www.new"
python3 - "$ARCHIVE" "$APP_DIR/www.new" <<'PY'
import os, sys, zipfile
archive, dest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(archive) as z:
    names = z.namelist()
    prefix = names[0].split('/')[0] + '/'
    for item in z.infolist():
        name = item.filename
        if not name.startswith(prefix):
            continue
        rel = name[len(prefix):]
        if not rel:
            continue
        target = os.path.abspath(os.path.join(dest, rel))
        if not target.startswith(os.path.abspath(dest) + os.sep):
            continue
        if item.is_dir():
            os.makedirs(target, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(item) as src, open(target, 'wb') as out:
                out.write(src.read())
PY
cat >"$APP_DIR/www.new/router.php" <<'PHP'
<?php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$file = __DIR__ . $path;
if ($path !== '/' && is_file($file)) { return false; }
require __DIR__ . '/index.php';

PHP
mkdir -p "$DATA_DIR/data/system" "$DATA_DIR/data/temp/files" "$DATA_DIR/data/temp/log" "$DATA_DIR/data/temp/thumb"
chmod -R u+rwX,go+rwX "$DATA_DIR/data" 2>/dev/null || true
rm -rf "$APP_DIR/www.new/data"
ln -s "$DATA_DIR/data" "$APP_DIR/www.new/data"
# KodBox 的 config 目录包含核心引导文件，必须保留源码自带目录，不能替换为空的数据目录。
# SQLite 初始化会在 DATA_PATH/system 下创建数据库文件，必须提前创建并授权。
if [ -d "$APP_DIR/www" ]; then rm -rf "$APP_DIR/www.old"; mv "$APP_DIR/www" "$APP_DIR/www.old"; fi
mv "$APP_DIR/www.new" "$APP_DIR/www"
chmod -R u+rwX,go+rwX "$APP_DIR/www" "$DATA_DIR" 2>/dev/null || true
cat >"/etc/systemd/system/kodbox.service" <<EOF
[Unit]
Description=WanOS KodBox Cloud Drive
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR/www
Environment=PHP_CLI_SERVER_WORKERS=1
ExecStart=/usr/bin/php -d display_errors=stderr -d log_errors=On -d error_log=$DATA_DIR/kodbox-php-error.log -S 0.0.0.0:$PORT router.php
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now kodbox.service
sleep 1
if ! systemctl is-active --quiet kodbox.service; then
  journalctl -u kodbox -n 80 --no-pager 2>/dev/null | tee -a "$LOG_FILE" || true
  fatal "KodBox 服务启动失败，请查看 $LOG_FILE 和 $DATA_DIR/kodbox-php-error.log"
fi
rm -rf "$TMP_DIR"
log "安装完成。打开可道云：http://设备IP:$PORT"
