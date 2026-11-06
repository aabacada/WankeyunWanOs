#!/bin/sh
set -eu
LOG_FILE="/var/log/wanos-cups-print-uninstall.log"
log(){ printf '%s
' "[CUPS] $*"; }
[ "$(id -u)" = "0" ] || { echo "please uninstall as root" >&2; exit 1; }
: >"$LOG_FILE" 2>/dev/null || true
log "停止 CUPS Web 和 CUPS 服务"
systemctl stop cups-web.service cups.service cups.socket cups.path >/dev/null 2>&1 || true
systemctl disable cups-web.service cups.service cups.socket cups.path >/dev/null 2>&1 || true
rm -f /etc/systemd/system/cups-web.service
log "清理安装缓存，释放 dpkg 可写空间"
rm -rf /tmp/wanos-cups-print-offline /tmp/wanos-store-* 2>/dev/null || true
rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb 2>/dev/null || true
if command -v apt-get >/dev/null 2>&1; then apt-get clean >/dev/null 2>&1 || true; fi
if command -v journalctl >/dev/null 2>&1; then journalctl --vacuum-size=20M >/dev/null 2>&1 || true; fi
log "卸载 CUPS 应用包"
if command -v dpkg >/dev/null 2>&1; then
  dpkg --purge --force-depends cups cups-client cups-core-drivers cups-daemon cups-filters cups-filters-core-drivers cups-ipp-utils cups-ppdc cups-server-common ghostscript poppler-utils poppler-data libpoppler-cpp0v5 libpoppler97 libcupsfilters1 hplip hplip-data printer-driver-all printer-driver-hpcups printer-driver-hpijs hpijs-ppds hp-ppd printer-driver-gutenprint gutenprint-locales foomatic-db foomatic-db-engine foomatic-db-compressed-ppds foomatic-filters openprinting-ppds printer-driver-foo2zjs printer-driver-foo2zjs-common printer-driver-splix printer-driver-ptouch printer-driver-pxljr printer-driver-min12xxw printer-driver-pnm2ppa printer-driver-c2esp printer-driver-escpr printer-driver-brlaser printer-driver-cups-pdf smbclient samba-common-bin avahi-daemon libnss-mdns usbutils 2>&1 | tee -a "$LOG_FILE" || true
fi
rm -rf /opt/wanos/apps/cups-print /opt/wanos-data/apps/cups-print /etc/cups /var/cache/cups /var/spool/cups /var/log/cups 2>/dev/null || true
systemctl daemon-reload >/dev/null 2>&1 || true
log "已卸载 CUPS 打印服务和 CUPS Web 面板。"
