#!/bin/sh
set -eu
APP_ID="cups-print"
APP_VERSION="1.0.0-wanos.33"
APP_NAME="CUPS 打印服务"
CUPS_PORT="${CUPS_PORT:-631}"
WEB_PORT="${CUPS_WEB_PORT:-18631}"
PKG_URL="${CUPS_PKG_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/cups-print/cups-print_ubuntu20.04_armhf_offline.tar.gz}"
PKG_SHA256="${CUPS_PKG_SHA256:-16ea1f23ac1becd252557774c712e48dedcbc03f2b73601a37884bce5308aaf9}"
DRIVER_PKG_URL="${CUPS_DRIVER_PKG_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/cups-print/cups-print-driver-library_ubuntu20.04_armhf_v1.tar.gz}"
DRIVER_PKG_SHA256="${CUPS_DRIVER_PKG_SHA256:-d2ecd61b26483b7d10123ddec0146befea105853105ebfdf978e1e73816db57d}"
WEB_URL="${CUPS_WEB_URL:-https://wxqun988.vxjuejin.com/wanos/downloads/apps/cups-print/cups-web-linux-armv7-v33}"
WEB_FALLBACK_URL="${CUPS_WEB_FALLBACK_URL:-https://github.com/hanxi/cups-web/releases/download/v0.1.5/cups-web-linux-armv7}"
WEB_SHA256="${CUPS_WEB_SHA256:-65ebbfcdfd5cecec1886ca54e29968f18fcc1c47f114e4f57813fc4156f17c7f}"
ADMIN_USERNAME="${WANOS_APP_ADMIN_USERNAME:-${WANOS_APP_USERNAME:-${admin_username:-${username:-admin}}}}"
ADMIN_PASSWORD="${WANOS_APP_ADMIN_PASSWORD:-${WANOS_APP_PASSWORD:-${admin_password:-${password:-wanoscups123}}}}"
TMP_DIR="/tmp/wanos-cups-print-offline"
trap 'rm -rf "$TMP_DIR"' EXIT
APP_DIR="/opt/wanos/apps/cups-print"
DATA_DIR="/opt/wanos-data/apps/cups-print"
LOG_FILE="/var/log/wanos-cups-print-update.log"
log(){ printf '%s\n' "[CUPS] $*"; }
fatal(){ printf '%s\n' "[CUPS] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
sanitize_user(){ printf '%s' "$1" | tr -cd 'A-Za-z0-9_.-' | cut -c1-32; }
ensure_group(){ getent group "$1" >/dev/null 2>&1 || groupadd "$1" 2>/dev/null || true; }
download_file(){
  url="$1"; out="$2"
  log_tmp="$TMP_DIR/download.log"
  if has_cmd curl; then
    curl -fL --connect-timeout 20 --max-time 300 --retry 2 -o "$out" "$url" >"$log_tmp" 2>&1
  else
    wget -O "$out" "$url" >"$log_tmp" 2>&1
  fi
  rc=$?
  cat "$log_tmp" | tee -a "$LOG_FILE"
  return "$rc"
}
verify_sha(){
  file="$1"; want="$2"; name="$3"
  [ -n "$want" ] || return 0
  case "$want" in __*) return 0;; esac
  if has_cmd sha256sum; then got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || fatal "$name 校验失败：want $want got $got"; fi
}
sha256_matches(){
  file="$1"; want="$2"
  [ -n "$want" ] || return 0
  case "$want" in __*) return 0;; esac
  has_cmd sha256sum || return 0
  got="$(sha256sum "$file" | awk '{print $1}')"
  [ "$got" = "$want" ]
}
install_debs_from_dir(){
  deb_root="$1"; label="$2"; required_pkg="$3"
  DEB_LIST_FILE="$TMP_DIR/${label}-deb-list.txt"
  : >"$DEB_LIST_FILE"
  for deb_dir in "$deb_root" "$deb_root"/debs "$deb_root"/*/debs; do
    [ -d "$deb_dir" ] || continue
    for deb in "$deb_dir"/*.deb; do
      [ -f "$deb" ] || continue
      pkg="$(dpkg-deb -f "$deb" Package 2>/dev/null || true)"
      if [ -n "$pkg" ] && dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
        log "skip installed package: $pkg"
      else
        printf '%s\n' "$deb" >>"$DEB_LIST_FILE"
      fi
    done
  done
  if [ ! -s "$DEB_LIST_FILE" ]; then
    log "$label: all deb packages are already installed or package is empty"
    return 0
  fi
  set +e
  DEBIAN_FRONTEND=noninteractive xargs -r dpkg -i <"$DEB_LIST_FILE" 2>&1 | tee -a "$LOG_FILE"
  dpkg_status=$?
  set -e
  if [ "$dpkg_status" -ne 0 ]; then
    log "$label: dpkg returned $dpkg_status, configure pending packages"
    sleep 2
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a 2>&1 | tee -a "$LOG_FILE" || true
  fi
  if [ -n "$required_pkg" ] && ! dpkg-query -W -f='${Status}' "$required_pkg" 2>/dev/null | grep -q '^install ok installed$'; then
    return 1
  fi
  return 0
}
install_driver_package(){
  [ -n "$DRIVER_PKG_URL" ] || { log "CUPS driver package URL is empty, skip"; return 0; }
  DRIVER_ARCHIVE="$TMP_DIR/cups-driver-offline.tar.gz"
  DRIVER_DIR="$TMP_DIR/cups-drivers"
  rm -rf "$DRIVER_DIR"
  mkdir -p "$DRIVER_DIR"
  log "download CUPS common driver package: $DRIVER_PKG_URL"
  if ! download_file "$DRIVER_PKG_URL" "$DRIVER_ARCHIVE"; then
    [ "$DRIVER_PKG_STRICT" = "1" ] && fatal "CUPS driver package download failed"
    log "CUPS driver package download failed, continue with base CUPS"
    return 0
  fi
  if ! sha256_matches "$DRIVER_ARCHIVE" "$DRIVER_PKG_SHA256"; then
    [ "$DRIVER_PKG_STRICT" = "1" ] && fatal "CUPS driver package SHA256 verification failed"
    log "CUPS driver package SHA256 verification failed, continue with base CUPS"
    return 0
  fi
  log "extract CUPS common driver package"
  if ! tar -xzf "$DRIVER_ARCHIVE" -C "$DRIVER_DIR" 2>&1 | tee -a "$LOG_FILE"; then
    [ "$DRIVER_PKG_STRICT" = "1" ] && fatal "CUPS driver package extract failed"
    log "CUPS driver package extract failed, continue with base CUPS"
    return 0
  fi
  log "install CUPS common printer drivers"
  if ! install_debs_from_dir "$DRIVER_DIR" "cups-drivers" "printer-driver-hpcups"; then
    [ "$DRIVER_PKG_STRICT" = "1" ] && fatal "CUPS driver package install failed"
    log "CUPS driver package install incomplete, continue with base CUPS"
    return 0
  fi
  log "CUPS common printer drivers installed"
}

sync_cups_web_admin(){
  if ! has_cmd python3; then fatal "python3 is required to configure CUPS Web admin account"; fi
  DB_PATH="$DATA_DIR/cups-web.db" ADMIN_USERNAME="$ADMIN_USERNAME" ADMIN_PASSWORD="$ADMIN_PASSWORD" python3 - <<'PY'
import datetime, os, sqlite3, sys
try:
    import crypt
except Exception as exc:
    print('python crypt module missing: %s' % exc, file=sys.stderr)
    sys.exit(1)
db = os.environ.get('DB_PATH')
user = (os.environ.get('ADMIN_USERNAME') or 'admin')[:32]
pw = os.environ.get('ADMIN_PASSWORD') or ''
import time
for _ in range(30):
    if db and os.path.exists(db):
        try:
            con_probe = sqlite3.connect(db)
            ok = con_probe.execute("select name from sqlite_master where type='table' and name='users'").fetchone()
            con_probe.close()
            if ok:
                break
        except Exception:
            pass
    time.sleep(1)
else:
    print('CUPS Web database/users table not ready: %s' % db, file=sys.stderr)
    sys.exit(1)
if not user or not pw:
    print('missing CUPS Web admin username/password', file=sys.stderr)
    sys.exit(1)
import random
chars = './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
salt = '$2a$10$' + ''.join(random.choice(chars) for _ in range(22))
hash_value = crypt.crypt(pw, salt)
if not hash_value or not hash_value.startswith('$2'):
    print('failed to generate bcrypt password hash', file=sys.stderr)
    sys.exit(1)
now = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'
con = sqlite3.connect(db)
cur = con.cursor()
cur.execute("select name from sqlite_master where type='table' and name='users'")
if not cur.fetchone():
    print('CUPS Web users table not found', file=sys.stderr)
    sys.exit(1)
row = cur.execute('select id from users where username=?', (user,)).fetchone()
if row:
    cur.execute('update users set password_hash=?, role=?, protected=1, updated_at=? where username=?', (hash_value, 'admin', now, user))
else:
    cur.execute('insert into users(username,password_hash,role,protected,contact_name,phone,email,created_at,updated_at) values(?,?,?,?,?,?,?,?,?)', (user, hash_value, 'admin', 1, '', '', '', now, now))
con.commit()
print('CUPS Web admin account synced: %s' % user)
PY
}
[ "$(id -u)" = "0" ] || fatal "please update as root"
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd dpkg || fatal "本应用需要 dpkg。"
has_cmd tar || fatal "本应用需要 tar 解压离线包。"
if ! has_cmd curl && ! has_cmd wget; then fatal "本应用需要 curl 或 wget 下载文件。"; fi
ADMIN_USERNAME="$(sanitize_user "$ADMIN_USERNAME")"
[ -n "$ADMIN_USERNAME" ] || ADMIN_USERNAME="admin"
[ ${#ADMIN_PASSWORD} -ge 6 ] || fatal "CUPS admin password must be at least 6 characters"
CUPS_SYSTEM_USERNAME="$ADMIN_USERNAME"
case "$CUPS_SYSTEM_USERNAME" in
  [A-Za-z_]*)
    ;;
  *)
    CUPS_SYSTEM_USERNAME="cupsadmin"
    ;;
esac
: >"$LOG_FILE" 2>/dev/null || true
ensure_group lpadmin
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR" "$APP_DIR/bin" "$DATA_DIR/uploads"
if has_cmd cupsd && dpkg -s cups >/dev/null 2>&1 && dpkg -s cups-daemon >/dev/null 2>&1; then
  log "检测到 CUPS 已安装，跳过离线 deb 重装。"
else
  ARCHIVE="$TMP_DIR/cups-offline.tar.gz"
  log "下载 CUPS 离线包：$PKG_URL"
  download_file "$PKG_URL" "$ARCHIVE"
  verify_sha "$ARCHIVE" "$PKG_SHA256" "CUPS 离线包"
  log "解压 CUPS 离线包"
  tar -xzf "$ARCHIVE" -C "$TMP_DIR" 2>&1 | tee -a "$LOG_FILE" || fatal "离线包解压失败"
  log "install CUPS offline deb packages"
  install_debs_from_dir "$TMP_DIR" "cups-base" "cups" || true
  if ! dpkg-query -W -f='${Status}' cups 2>/dev/null | grep -q '^install ok installed$'; then
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a 2>&1 | tee -a "$LOG_FILE" || true
  fi
  dpkg-query -W -f='${Status}' cups 2>/dev/null | grep -q '^install ok installed$' || fatal "CUPS offline install failed. Log: $LOG_FILE"
fi
[ -d /etc/cups ] || fatal "CUPS 安装后仍缺少 /etc/cups，安装不完整。日志：$LOG_FILE"
has_cmd cupsd || fatal "CUPS 安装后仍找不到 cupsd，安装不完整。日志：$LOG_FILE"
log "配置 CUPS 后端服务"
cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.wanos.bak.$(date +%s) 2>/dev/null || true
cat >/etc/cups/cupsd.conf <<EOF
LogLevel warn
PageLogFormat
MaxLogSize 0
Port $CUPS_PORT
Listen /run/cups/cups.sock
Browsing On
BrowseLocalProtocols dnssd
DefaultAuthType Basic
WebInterface Yes
<Location />
  Order allow,deny
  Allow all
</Location>
<Location /admin>
  Order allow,deny
  Allow all
</Location>
<Location /admin/conf>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow all
</Location>
<Location /admin/log>
  AuthType Default
  Require user @SYSTEM
  Order allow,deny
  Allow all
</Location>
<Policy default>
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default
  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
EOF
cupsd -t 2>&1 | tee -a "$LOG_FILE" || fatal "CUPS 配置检查失败。日志：$LOG_FILE"
if has_cmd cupsctl; then cupsctl --remote-any --remote-admin --share-printers WebInterface=yes 2>&1 | tee -a "$LOG_FILE" || true; fi
log "configure CUPS system admin account: $CUPS_SYSTEM_USERNAME"
ensure_group "$CUPS_SYSTEM_USERNAME"
if ! id "$CUPS_SYSTEM_USERNAME" >/dev/null 2>&1; then
  useradd -M -g "$CUPS_SYSTEM_USERNAME" -s /usr/sbin/nologin "$CUPS_SYSTEM_USERNAME" 2>/dev/null || useradd -M -g "$CUPS_SYSTEM_USERNAME" -s /bin/false "$CUPS_SYSTEM_USERNAME" 2>/dev/null || useradd -M -s /usr/sbin/nologin "$CUPS_SYSTEM_USERNAME" 2>/dev/null || useradd -M -s /bin/false "$CUPS_SYSTEM_USERNAME" 2>/dev/null || fatal "create CUPS admin user failed: $CUPS_SYSTEM_USERNAME"
fi
printf '%s:%s\n' "$CUPS_SYSTEM_USERNAME" "$ADMIN_PASSWORD" | chpasswd 2>/dev/null || fatal "set CUPS admin password failed"
usermod -aG lpadmin "$CUPS_SYSTEM_USERNAME" 2>/dev/null || true
log "下载 CUPS Web armv7 面板：$WEB_URL"
WEB_BIN="$APP_DIR/bin/cups-web"
systemctl stop cups-web.service >/dev/null 2>&1 || true
rm -f "$WEB_BIN"
if ! download_file "$WEB_URL" "$WEB_BIN"; then
  log "默认下载失败，尝试备用地址：$WEB_FALLBACK_URL"
  download_file "$WEB_FALLBACK_URL" "$WEB_BIN"
fi
chmod 0755 "$WEB_BIN"
verify_sha "$WEB_BIN" "$WEB_SHA256" "CUPS Web 面板"
cat >"$APP_DIR/env" <<EOF
CUPS_HOST=127.0.0.1:$CUPS_PORT
DB_PATH=$DATA_DIR/cups-web.db
UPLOAD_DIR=$DATA_DIR/uploads
LISTEN_ADDR=:$WEB_PORT
EOF
cat >/etc/systemd/system/cups-web.service <<EOF
[Unit]
Description=WanOS CUPS Web Panel
After=network.target cups.service
Requires=cups.service

[Service]
Type=simple
EnvironmentFile=$APP_DIR/env
ExecStart=$WEB_BIN
Restart=always
RestartSec=3
WorkingDirectory=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF
if id wanos >/dev/null 2>&1; then usermod -aG lpadmin wanos 2>/dev/null || true; fi
usermod -aG lpadmin root 2>/dev/null || true
log "启动 CUPS 和 CUPS Web"
systemctl daemon-reload
systemctl enable --now cups.service 2>&1 | tee -a "$LOG_FILE" || fatal "CUPS 启动失败。"
systemctl enable --now cups-web.service 2>&1 | tee -a "$LOG_FILE" || { journalctl -u cups-web -n 100 --no-pager 2>/dev/null | tee -a "$LOG_FILE" || true; fatal "CUPS Web 启动失败。"; }
sleep 2
sync_cups_web_admin 2>&1 | tee -a "$LOG_FILE" || fatal "CUPS Web admin account configuration failed"
systemctl restart cups-web.service 2>&1 | tee -a "$LOG_FILE" || fatal "CUPS Web restart failed after admin account sync"
sleep 1
systemctl is-active --quiet cups.service || fatal "CUPS 服务未运行。"
systemctl is-active --quiet cups-web.service || fatal "CUPS Web 服务未运行。"
if has_cmd ss; then ss -lntup 2>/dev/null | grep -E ":$WEB_PORT\s" | tee -a "$LOG_FILE" || fatal "CUPS Web 已启动但 $WEB_PORT 端口没有监听。日志：$LOG_FILE"; fi
mkdir -p "$DATA_DIR"
printf '%s\n' "$APP_VERSION" >"$DATA_DIR/wanos-app-version"
rm -rf "$TMP_DIR"
log "更新完成。打开 CUPS Web 面板：http://设备IP:$WEB_PORT"
exit 0
