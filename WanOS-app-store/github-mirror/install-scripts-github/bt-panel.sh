#!/bin/sh
set -eu
APP_ID="bt-panel"
APP_NAME="宝塔面板"
PORT="${BT_PANEL_PORT:-8888}"
BT_SITE_PORT="${BT_PANEL_SITE_PORT:-8881}"
BT_FTP_PORT="${BT_PANEL_FTP_PORT:-2121}"
BT_ADMIN_PASSWORD="${BT_PANEL_ADMIN_PASSWORD:-${WANOS_APP_ADMIN_PASSWORD:-1234}}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
TMP_DIR="$DATA_DIR/.tmp-install"
LOG_FILE="/var/log/wanos-bt-panel-install.log"
PACKAGE_URL="${BT_PANEL_PACKAGE_URL:-}"
PACKAGE_SHA256="${BT_PANEL_PACKAGE_SHA256:-}"
log(){ printf '%s\n' "[$APP_NAME] $*" | tee -a "$LOG_FILE"; }
fatal(){ printf '%s\n' "[$APP_NAME] 错误: $*" | tee -a "$LOG_FILE" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "unsupported arch: $(uname -m)" ;; esac
has_cmd systemctl || fatal "systemd not found"
has_cmd tar || fatal "tar not found"
has_cmd sha256sum || fatal "sha256sum not found"
mkdir -p "$DATA_DIR" "$TMP_DIR" /opt/wanos/backup /var/log
: >"$LOG_FILE" 2>/dev/null || true
case "$PACKAGE_URL" in
  file://*) ARCHIVE="${PACKAGE_URL#file://}"; log "使用本地离线包: $ARCHIVE" ;;
  /*) ARCHIVE="$PACKAGE_URL"; log "使用本地离线包: $ARCHIVE" ;;
  "") fatal "请先在应用商店上传宝塔离线包，再点击导入并安装" ;;
  *) fatal "宝塔面板已改为本地上传安装，不再直接联网下载离线包" ;;
esac
[ -s "$ARCHIVE" ] || fatal "离线包不存在或为空: $ARCHIVE"
got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
log "离线包 SHA256: $got"
if [ -n "$PACKAGE_SHA256" ] && [ "$got" != "$PACKAGE_SHA256" ]; then fatal "离线包校验失败 want $PACKAGE_SHA256 got $got"; fi
stop_bt_processes(){
  log "停止旧宝塔服务和残留进程"
  systemctl stop bt-panel >/dev/null 2>&1 || true
  /etc/init.d/bt stop >/dev/null 2>&1 || true
  for pat in '/www/server/panel/main.py' '/www/server/panel/BT-Panel' '/www/server/panel/task.py' '/www/server/panel/BT-Task' '/www/server/mysql/bin/mysqld' 'mysqld_safe' '/www/server/php/72/sbin/php-fpm' '/www/server/nginx/sbin/nginx' '/www/server/pure-ftpd/sbin/pure-ftpd'; do
    pids=$(ps -ef | grep "$pat" | grep -v grep | awk '{print $2}')
    [ -z "$pids" ] || kill $pids 2>/dev/null || true
  done
  sleep 1
  for pat in '/www/server/panel/main.py' '/www/server/panel/BT-Panel' '/www/server/panel/task.py' '/www/server/panel/BT-Task' '/www/server/mysql/bin/mysqld' 'mysqld_safe' '/www/server/php/72/sbin/php-fpm' '/www/server/nginx/sbin/nginx' '/www/server/pure-ftpd/sbin/pure-ftpd'; do
    pids=$(ps -ef | grep "$pat" | grep -v grep | awk '{print $2}')
    [ -z "$pids" ] || kill -9 $pids 2>/dev/null || true
  done
}
clear_attrs(){
  p="$1"
  [ -e "$p" ] || return 0
  command -v chattr >/dev/null 2>&1 && chattr -R -i -a "$p" >/dev/null 2>&1 || true
  chmod -R u+rwX "$p" >/dev/null 2>&1 || true
  find "$p" -name '.user.ini' -exec sh -c 'chattr -i -a "$1" 2>/dev/null || true; chmod u+rw "$1" 2>/dev/null || true' sh {} \; 2>/dev/null || true
}
remove_path_strict(){
  p="$1"
  [ -e "$p" ] || return 0
  clear_attrs "$p"
  rm -rf "$p" 2>/dev/null || true
  if [ -e "$p" ]; then
    find "$p" -name '.user.ini' -exec sh -c 'chattr -i -a "$1" 2>/dev/null || true; chmod u+rw "$1" 2>/dev/null || true; rm -f "$1" 2>/dev/null || true' sh {} \; 2>/dev/null || true
    rm -rf "$p" 2>/dev/null || true
  fi
  [ ! -e "$p" ] || fatal "旧目录清理失败: $p. 可 SSH 执行: chattr -R -i -a $p && rm -rf $p 后重试"
}
backup_or_remove(){
  p="$1"; name="$2"
  [ -e "$p" ] || return 0
  clear_attrs "$p"
  if mv "$p" "$backup/$name" 2>/dev/null; then log "已备份旧目录: $p -> $backup/$name"; return 0; fi
  log "旧目录备份失败，改为强制清理: $p"
  remove_path_strict "$p"
}
prepare_clean_root(){
  mkdir -p "$backup" /www /etc/init.d /usr/bin /usr/lib/arm-linux-gnueabihf /usr/local
  backup_or_remove /www/server server
  backup_or_remove /www/wwwlogs wwwlogs
  backup_or_remove /www/wwwroot wwwroot
  [ ! -e /etc/my.cnf ] || cp -a /etc/my.cnf "$backup/my.cnf" 2>/dev/null || true
  rm -f /tmp/panelNum.pl /tmp/panelNime.pl /tmp/php-cgi-72.sock 2>/dev/null || true
}
stop_bt_processes
backup="/opt/wanos/backup/bt-panel.$(date +%Y%m%d%H%M%S)"
prepare_clean_root
log "解压原始宝塔完整运行环境"
if ! tar -xzf "$ARCHIVE" -C / >>"$LOG_FILE" 2>&1; then
  log "首次解压失败，执行二次清理后重试"
  stop_bt_processes
  backup="/opt/wanos/backup/bt-panel.retry.$(date +%Y%m%d%H%M%S)"
  prepare_clean_root
  tar -xzf "$ARCHIVE" -C / >>"$LOG_FILE" 2>&1 || fatal "离线包解压失败，请查看 $LOG_FILE"
fi
log "修复宝塔运行环境"
getent group www >/dev/null || groupadd -g 1001 www 2>/dev/null || groupadd www
getent passwd www >/dev/null || useradd -u 1001 -g www -M -s /usr/sbin/nologin www 2>/dev/null || useradd -g www -M -s /usr/sbin/nologin www
getent group mysql >/dev/null || groupadd -g 1002 mysql 2>/dev/null || groupadd mysql
getent passwd mysql >/dev/null || useradd -u 1002 -g mysql -M -s /usr/sbin/nologin mysql 2>/dev/null || useradd -g mysql -M -s /usr/sbin/nologin mysql
chmod 755 /usr/bin/python2.7 2>/dev/null || true
[ -x /usr/bin/python2.7 ] || fatal "离线包缺少 /usr/bin/python2.7"
ln -sfn /usr/bin/python2.7 /usr/bin/python
ln -sfn /usr/local/openssl/lib/libcrypto.so.1.0.0 /usr/lib/arm-linux-gnueabihf/libcrypto.so.1.0.0
ln -sfn /usr/local/openssl/lib/libssl.so.1.0.0 /usr/lib/arm-linux-gnueabihf/libssl.so.1.0.0
[ -e /usr/local/lib/libmcrypt.so.4.4.8 ] && ln -sfn /usr/local/lib/libmcrypt.so.4.4.8 /usr/lib/arm-linux-gnueabihf/libmcrypt.so.4 || true
[ -e /usr/local/lib/libmhash.so.2.0.1 ] && ln -sfn /usr/local/lib/libmhash.so.2.0.1 /usr/lib/arm-linux-gnueabihf/libmhash.so.2 || true
cat >/etc/ld.so.conf.d/wanos-bt-panel.conf <<'EOF'
/usr/local/openssl/lib
/usr/local/curl/lib
/usr/local/icu/lib
/usr/local/freetype/lib
/usr/local/libiconv/lib
/usr/local/lib
/www/server/mysql/lib
/www/server/php/72/lib
EOF
ldconfig >/dev/null 2>&1 || true
mkdir -p /www/wwwlogs /www/wwwroot /www/server/data /www/server/mysql/data /www/server/panel/data /www/server/panel/logs
[ -f /etc/init.d/mysqld ] && sed -i 's#datadir=/www/server/mysql/data#datadir=/www/server/data#g' /etc/init.d/mysqld 2>/dev/null || true
chmod 644 /etc/my.cnf 2>/dev/null || true
find /www/server/panel/vhost/nginx -type f -name '*.conf' -exec sed -i "s/listen[[:space:]]\+80;/listen $BT_SITE_PORT;/g" {} + 2>/dev/null || true
if [ -f /www/server/pure-ftpd/etc/pure-ftpd.conf ]; then
  grep -q '^Bind ' /www/server/pure-ftpd/etc/pure-ftpd.conf && sed -i "s/^Bind .*/Bind 0.0.0.0,$BT_FTP_PORT/" /www/server/pure-ftpd/etc/pure-ftpd.conf || printf '\nBind 0.0.0.0,%s\n' "$BT_FTP_PORT" >>/www/server/pure-ftpd/etc/pure-ftpd.conf
fi
printf '%s\n' "$PORT" >/www/server/panel/data/port.pl
rm -f /www/server/panel/data/*.login /www/server/panel/data/session/* /tmp/panelNum.pl /tmp/panelNime.pl /tmp/php-cgi-72.sock /www/server/php/72/var/run/php-fpm.pid /www/server/nginx/logs/nginx.pid 2>/dev/null || true
export BT_ADMIN_PASSWORD
python2.7 - <<'PY'
import sqlite3, hashlib, os
DB='/www/server/panel/data/default.db'
password=os.environ.get('BT_ADMIN_PASSWORD') or '1234'
if os.path.exists(DB):
    con=sqlite3.connect(DB)
    con.execute('update users set username=?, password=? where id=1', ('root', hashlib.md5(password).hexdigest()))
    con.commit()
PY
chown -R mysql:mysql /www/server/data /www/server/mysql 2>/dev/null || true
chown -R www:www /www/wwwlogs /www/wwwroot /www/server/php /www/server/nginx 2>/dev/null || true
chmod -R u+rwX,go+rX /www/server /www/wwwlogs /www/wwwroot /usr/local /usr/lib/python2.7 /usr/local/lib/python2.7 2>/dev/null || true
find /www/server -path '*/bin/*' -type f -exec chmod 755 {} + 2>/dev/null || true
find /www/server -path '*/sbin/*' -type f -exec chmod 755 {} + 2>/dev/null || true
find /www/server -type f -name '*.so' -exec chmod 755 {} + 2>/dev/null || true
find /www/server -type f -name '*.so.*' -exec chmod 755 {} + 2>/dev/null || true
find /usr/local -type f -name '*.so' -exec chmod 755 {} + 2>/dev/null || true
find /usr/local -type f -name '*.so.*' -exec chmod 755 {} + 2>/dev/null || true
find /www/server -type f -name '*.sh' -exec chmod 755 {} + 2>/dev/null || true
chmod 755 /etc/init.d/bt /etc/init.d/nginx /etc/init.d/mysqld /etc/init.d/php-fpm-72 /etc/init.d/pure-ftpd /www/server/panel/BT-Panel /www/server/panel/BT-Task /www/server/panel/init.sh 2>/dev/null || true
[ -d /www/server/phpmyadmin ] && chown -R root:root /www/server/phpmyadmin 2>/dev/null || true
cat >/etc/systemd/system/bt-panel.service <<'EOF'
[Unit]
Description=WanOS BaoTa Panel Original Runtime
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/etc/init.d/bt start
ExecStop=/etc/init.d/bt stop
ExecReload=/etc/init.d/bt reload
TimeoutStartSec=90
TimeoutStopSec=60
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable bt-panel >/dev/null 2>&1 || true
systemctl restart bt-panel >>"$LOG_FILE" 2>&1 || fatal "bt-panel 服务启动失败，请查看 $LOG_FILE"
sleep 3
ss -lnt 2>/dev/null | grep -q ":$PORT " || fatal "宝塔面板未监听 $PORT, 请查看 $LOG_FILE"
rm -rf "$TMP_DIR"
log "安装完成"
log "访问地址: http://设备IP:$PORT/"
log "默认账号: root"
log "默认密码: $BT_ADMIN_PASSWORD"
log "Nginx site port: $BT_SITE_PORT"
log "FTP port: $BT_FTP_PORT"
