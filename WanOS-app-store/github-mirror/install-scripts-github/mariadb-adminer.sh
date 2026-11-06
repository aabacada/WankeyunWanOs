#!/bin/sh
set -eu
APP_ID="mariadb-adminer"
APP_NAME="MariaDB 数据库"
APP_DIR="${WANOS_APP_INSTALL_DIR:-${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}}"
DATA_DIR="${WANOS_APP_DATA_DIR:-${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_URL="${MARIADB_ADMINER_PKG_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/mariadb-adminer-focal-armhf-offline.tar.gz}"
PKG_SHA256="${MARIADB_ADMINER_PKG_SHA256:-fbdf55f261213aada9c62e04fd5777f245e064956f7ebdd05d915f76ed304f1b}"
PANEL_PORT="${MARIADB_ADMINER_PORT:-18086}"
DB_PORT="${MARIADB_PORT:-3306}"
LOG_FILE="/var/log/wanos-mariadb-adminer-install.log"
log(){ printf '%s\n' "[MariaDB] $*"; }
fatal(){ printf '%s\n' "[MariaDB] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
fetch(){ url="$1"; out="$2"; if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 1800 --retry 3 --retry-delay 2 -o "$out" "$url"; elif has_cmd wget; then wget -O "$out" "$url"; else fatal "缺少 curl/wget，无法下载离线包"; fi; }
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv6l|arm*) ;; *) fatal "当前架构不支持：$(uname -m)，本应用需要 ARMv7/armhf。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd dpkg || fatal "系统缺少 dpkg，无法安装离线包。"
has_cmd sha256sum || fatal "系统缺少 sha256sum。"
has_cmd tar || fatal "系统缺少 tar，无法解压离线包。"
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR" "$DATA_DIR/mysql"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/package.tar.gz"
log "下载 MariaDB + Adminer 完整离线包：$PKG_URL"
fetch "$PKG_URL" "$ARCHIVE" 2>&1 | tee -a "$LOG_FILE"
[ -s "$ARCHIVE" ] || fatal "离线包下载后为空"
got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
[ "$got" = "$PKG_SHA256" ] || fatal "离线包校验失败：want $PKG_SHA256 got $got"
rm -rf "$TMP_DIR/extract"
mkdir -p "$TMP_DIR/extract"
tar -xzf "$ARCHIVE" -C "$TMP_DIR/extract" || fatal "离线包解压失败"
DEB_DIR="$TMP_DIR/extract/offline/debs"
ASSET_DIR="$TMP_DIR/extract/offline/assets"
[ -d "$DEB_DIR" ] || fatal "离线包格式错误：缺少 debs 目录"
[ -f "$ASSET_DIR/adminer.php" ] || fatal "离线包格式错误：缺少 Adminer"
log "安装 MariaDB、PHP CLI、PHP MySQL 扩展离线 deb 包"
export DEBIAN_FRONTEND=noninteractive
run_dpkg_install(){
  tries=0
  while :; do
    tries=$((tries + 1))
    set +e
    dpkg -i "$DEB_DIR"/*.deb >"$TMP_DIR/dpkg-run.log" 2>&1
    rc=$?
    set -e
    cat "$TMP_DIR/dpkg-run.log" | tee -a "$LOG_FILE"
    if [ "$rc" = "0" ]; then return 0; fi
    if grep -qi "lock is locked\|Could not get lock\|frontend lock" "$TMP_DIR/dpkg-run.log"; then
      if [ "$tries" -lt 61 ]; then
        log "dpkg 正在被其他安装任务占用，等待 10 秒后重试（$tries/60）"
        sleep 10
        continue
      fi
      fatal "等待 dpkg 锁超时，请先结束其他安装/更新任务后重试。"
    fi
    log "dpkg 返回非零状态，继续按 MariaDB 必要组件进行校验，避免被系统其它半安装包拖死。"
    return 0
  done
}
find_db_service(){
  if systemctl list-unit-files | grep -q "^mariadb.service"; then echo "mariadb"; return 0; fi
  if systemctl list-unit-files | grep -q "^mysql.service"; then echo "mysql"; return 0; fi
  return 1
}
run_dpkg_install
run_dpkg_install
has_cmd mysql || fatal "mysql 客户端未安装成功，请查看 $LOG_FILE"
has_cmd php || fatal "PHP CLI 安装后仍不可用"
php -m | grep -qi "^mysqli$" || fatal "PHP mysqli 扩展不可用"
php -m | grep -qi "^pdo_mysql$" || fatal "PHP pdo_mysql 扩展不可用"
DB_SERVICE="$(find_db_service)" || fatal "MariaDB/MySQL 服务未安装成功，请查看 $LOG_FILE"
systemctl stop "$DB_SERVICE" 2>/dev/null || true
if [ ! -L /var/lib/mysql ]; then
  if [ -d /var/lib/mysql ] && [ -z "$(find "$DATA_DIR/mysql" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]; then
    cp -a /var/lib/mysql/. "$DATA_DIR/mysql"/ 2>/dev/null || true
  fi
  if [ -d /var/lib/mysql ]; then mv /var/lib/mysql "/var/lib/mysql.wanos.bak.$(date +%Y%m%d%H%M%S)"; fi
  ln -s "$DATA_DIR/mysql" /var/lib/mysql
fi
chown -R mysql:mysql "$DATA_DIR/mysql" 2>/dev/null || true
mkdir -p /etc/mysql/mariadb.conf.d
cat >/etc/mysql/mariadb.conf.d/99-wanos.cnf <<EOF
[mysqld]
bind-address=0.0.0.0
port=3306
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

[client]
default-character-set=utf8mb4
EOF
systemctl daemon-reload
systemctl enable "$DB_SERVICE" >/dev/null 2>&1 || true
systemctl restart "$DB_SERVICE"
sleep 5
PASS_FILE="$DATA_DIR/root-password.txt"
if [ -n "${WANOS_APP_ADMIN_PASSWORD:-}" ]; then DB_PASS="$WANOS_APP_ADMIN_PASSWORD"; echo "$DB_PASS" >"$PASS_FILE"; chmod 600 "$PASS_FILE"; elif [ -n "${MARIADB_ADMINER_ADMIN_PASSWORD:-}" ]; then DB_PASS="$MARIADB_ADMINER_ADMIN_PASSWORD"; echo "$DB_PASS" >"$PASS_FILE"; chmod 600 "$PASS_FILE"; elif [ -s "$PASS_FILE" ]; then DB_PASS="$(cat "$PASS_FILE")"; else DB_PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)"; echo "$DB_PASS" >"$PASS_FILE"; chmod 600 "$PASS_FILE"; fi
SQL_FILE="$TMP_DIR/setup.sql"
cat >"$SQL_FILE" <<EOF
CREATE USER IF NOT EXISTS 'wanos'@'%' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS 'wanos'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON *.* TO 'wanos'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'wanos'@'localhost' WITH GRANT OPTION;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';
FLUSH PRIVILEGES;
EOF
mysql --protocol=socket -uroot <"$SQL_FILE" 2>&1 | tee -a "$LOG_FILE" || mysql --protocol=socket -uroot -p"$DB_PASS" <"$SQL_FILE" 2>&1 | tee -a "$LOG_FILE" || fatal "数据库账号初始化失败"
mkdir -p "$APP_DIR/www"
cp "$ASSET_DIR/adminer.php" "$APP_DIR/www/adminer.php"
cat >"$APP_DIR/www/index.php" <<'PHP'
<?php
$passwordFile = '__DATA_DIR__/root-password.txt';
$password = is_file($passwordFile) ? trim(file_get_contents($passwordFile)) : '';
$host = $_SERVER['SERVER_NAME'] ?? '127.0.0.1';
?>
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MariaDB 数据库</title><style>body{font-family:Arial,"Microsoft YaHei",sans-serif;background:#f6f8fb;margin:0;color:#172033}.wrap{max-width:760px;margin:34px auto;padding:0 18px}.card{background:#fff;border:1px solid #e4e8f0;border-radius:8px;padding:22px;box-shadow:0 10px 28px rgba(20,35,60,.08)}h1{font-size:24px;margin:0 0 8px}.muted{color:#64748b}.grid{display:grid;grid-template-columns:130px 1fr;gap:10px 14px;margin:18px 0}.k{color:#64748b}.v{font-family:Consolas,monospace;background:#f1f5f9;border-radius:6px;padding:7px 9px;word-break:break-all}.btn{display:inline-block;background:#1f6feb;color:white;text-decoration:none;border-radius:6px;padding:10px 14px;margin-right:10px}.warn{background:#fff7ed;border:1px solid #fed7aa;color:#9a3412;border-radius:6px;padding:10px 12px;margin-top:14px}</style></head><body><div class="wrap"><div class="card"><h1>MariaDB 数据库</h1><p class="muted">兼容 MySQL，已集成 Adminer 网页管理面板，支持 SQL 导入和导出。</p><div class="grid"><div class="k">数据库地址</div><div class="v"><?php echo htmlspecialchars($host); ?>:3306</div><div class="k">本机地址</div><div class="v">127.0.0.1:3306</div><div class="k">管理账号</div><div class="v">wanos</div><div class="k">管理密码</div><div class="v"><?php echo htmlspecialchars($password); ?></div><div class="k">数据目录</div><div class="v">__DATA_DIR__/mysql</div></div><a class="btn" href="/adminer.php?server=127.0.0.1&username=wanos">打开 Adminer</a><div class="warn">请首次使用后保存好密码。卸载应用默认保留数据库数据。</div></div></div></body></html>
PHP
sed -i "s#__DATA_DIR__#$DATA_DIR#g" "$APP_DIR/www/index.php"
cat >/etc/systemd/system/mariadb-adminer.service <<EOF
[Unit]
Description=WanOS MariaDB Adminer Panel
After=network-online.target mariadb.service mysql.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR/www
ExecStart=/usr/bin/php -S 0.0.0.0:$PANEL_PORT -t $APP_DIR/www
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "1.0.0-wanos.1" >"$APP_DIR/version"
systemctl daemon-reload
systemctl enable mariadb-adminer >/dev/null 2>&1 || true
systemctl restart mariadb-adminer
rm -rf "$TMP_DIR"
log "安装完成。Adminer 面板端口：$PANEL_PORT；数据库端口：$DB_PORT；账号 wanos；密码保存在 $PASS_FILE"
