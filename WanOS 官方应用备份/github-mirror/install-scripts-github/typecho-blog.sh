#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_DIR:-${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/typecho-blog}}"
DATA_DIR="${WANOS_APP_DATA_DIR:-${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/typecho-blog}}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/typecho-v1.3.0.zip"
PKG_SHA="c34cd65b2f944f464bcaa8f43b10f665f1dae13158c694546b22c35ddc296668"
log(){ echo "[Typecho] $*"; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { log "ERROR: 缺少命令 $1"; exit 1; }; }
sha_check(){ file="$1"; want="$2"; got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || { log "ERROR: 校验失败：want $want got $got"; exit 1; }; }
fetch(){ url="$1"; out="$2"; if command -v curl >/dev/null 2>&1; then curl -fL --connect-timeout 20 --retry 2 "$url" -o "$out"; elif command -v wget >/dev/null 2>&1; then wget -O "$out" "$url"; else log "ERROR: 缺少 curl/wget"; exit 1; fi; }
need_cmd sha256sum
need_cmd awk
need_cmd unzip
need_cmd php
install_php_ext(){
  ext="$1"
  pkg="$2"
  if php -m | grep -qi "^${ext}$"; then return 0; fi
  log "检测到 PHP 缺少 ${ext} 扩展，正在安装 ${pkg}"
  need_cmd apt-get
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y "$pkg"
  php -m | grep -qi "^${ext}$" || { log "ERROR: PHP 扩展 ${ext} 安装后仍不可用"; exit 1; }
}
install_php_ext "pdo_sqlite" "php-sqlite3"
install_php_ext "sqlite3" "php-sqlite3"
install_php_ext "mbstring" "php-mbstring"
mkdir -p "$APP_DIR/www" "$DATA_DIR" "$TMP_DIR"
log "下载 Typecho：$PKG_URL"
fetch "$PKG_URL" "$TMP_DIR/typecho.zip"
sha_check "$TMP_DIR/typecho.zip" "$PKG_SHA"
rm -rf "$APP_DIR/www"
mkdir -p "$APP_DIR/www"
unzip -q "$TMP_DIR/typecho.zip" -d "$TMP_DIR/typecho"
SRC_DIR="$(find "$TMP_DIR/typecho" -maxdepth 3 -type f -name install.php -exec dirname {} \; | head -1)"
[ -n "$SRC_DIR" ] || { log "ERROR: 压缩包内未找到 Typecho install.php"; exit 1; }
[ -f "$SRC_DIR/index.php" ] || { log "ERROR: Typecho 根目录缺少 index.php"; exit 1; }
[ -d "$SRC_DIR/var" ] || { log "ERROR: Typecho 根目录缺少 var 目录"; exit 1; }
cp -a "$SRC_DIR"/. "$APP_DIR/www"/
mkdir -p "$DATA_DIR/uploads"
ln -sfn "$DATA_DIR/uploads" "$APP_DIR/www/usr/uploads" 2>/dev/null || true
chown -R root:root "$APP_DIR" "$DATA_DIR" 2>/dev/null || true
cat >/etc/systemd/system/typecho-blog.service <<EOF
[Unit]
Description=WanOS Typecho Blog
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}/www
ExecStart=/usr/bin/php -S 0.0.0.0:8088 -t ${APP_DIR}/www
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "1.3.0-wanos.1" > "$APP_DIR/version"
systemctl daemon-reload
systemctl enable typecho-blog >/dev/null 2>&1 || true
systemctl restart typecho-blog
rm -rf "$TMP_DIR"
log "安装完成。Web 面板端口：8088；首次打开按 Typecho 页面选择 SQLite 初始化。"
