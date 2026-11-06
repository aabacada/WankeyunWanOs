#!/bin/sh
set -eu
APP_NAME="宝塔面板"
log(){ printf '%s
' "[$APP_NAME] $*"; }
[ "$(id -u)" = "0" ] || { echo "[$APP_NAME] 请使用 root 卸载" >&2; exit 1; }
systemctl stop bt-panel >/dev/null 2>&1 || true
systemctl disable bt-panel >/dev/null 2>&1 || true
/etc/init.d/bt stop >/dev/null 2>&1 || true
for pat in '/www/server/panel/main.py' '/www/server/panel/BT-Panel' '/www/server/panel/task.py' '/www/server/panel/BT-Task' '/www/server/mysql/bin/mysqld' 'mysqld_safe' '/www/server/php/72/sbin/php-fpm' '/www/server/nginx/sbin/nginx' '/www/server/pure-ftpd/sbin/pure-ftpd'; do
  pids=$(ps -ef | grep "$pat" | grep -v grep | awk '{print $2}')
  [ -z "$pids" ] || kill $pids 2>/dev/null || true
done
rm -f /etc/systemd/system/bt-panel.service /etc/ld.so.conf.d/wanos-bt-panel.conf
systemctl daemon-reload >/dev/null 2>&1 || true
backup="/opt/wanos/backup/bt-panel-uninstall.$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup"
[ ! -e /www/server ] || mv /www/server "$backup/server" 2>/dev/null || rm -rf /www/server
[ ! -e /www/wwwlogs ] || mv /www/wwwlogs "$backup/wwwlogs" 2>/dev/null || rm -rf /www/wwwlogs
rm -f /etc/init.d/bt /etc/init.d/nginx /etc/init.d/mysqld /etc/init.d/php-fpm-72 /etc/init.d/pure-ftpd
ldconfig >/dev/null 2>&1 || true
log "已卸载，原目录备份在: $backup"
