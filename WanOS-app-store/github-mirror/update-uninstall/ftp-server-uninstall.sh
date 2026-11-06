#!/bin/sh
set -eu
APP_ID="ftp-server"
APP_DIR="/opt/wanos/apps/$APP_ID"
FTP_USER="${FTP_USER:-wanosftp}"
KEEP_DATA="${WANOS_KEEP_APP_DATA:-1}"
log(){ printf '%s
' "[FTP] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
systemctl stop ftp-server-panel.service >/dev/null 2>&1 || true
systemctl disable ftp-server-panel.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/ftp-server-panel.service
systemctl stop vsftpd.service >/dev/null 2>&1 || true
systemctl disable vsftpd.service >/dev/null 2>&1 || true
if [ -f /etc/vsftpd.conf.wanos.bak ]; then cp /etc/vsftpd.conf.wanos.bak /etc/vsftpd.conf; fi
rm -f /etc/vsftpd.wanos.userlist
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "$KEEP_DATA" = "0" ]; then rm -rf /opt/wanos-data/apps/$APP_ID; fi
log "已卸载 FTP 应用。vsftpd 软件包不会自动删除；数据默认保留在 /opt/wanos-data/apps/ftp-server。"
