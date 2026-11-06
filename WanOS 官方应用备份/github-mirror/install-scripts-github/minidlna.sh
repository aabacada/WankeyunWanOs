#!/bin/sh
set -eu
APP_ID="minidlna"
APP_NAME="MiniDLNA 局域网媒体广播"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_URL="${MINIDLNA_PKG_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/minidlna-focal-armhf-offline.tar.gz}"
PKG_SHA256="${MINIDLNA_PKG_SHA256:-368819818ffe77d578c05cd3d83fd4948dcbefa2921c662f9397309391ad0fba}"
PANEL_URL="${MINIDLNA_PANEL_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/minidlna-panel.py}"
PANEL_PORT="${MINIDLNA_PANEL_PORT:-18200}"
DLNA_PORT="${MINIDLNA_PORT:-8200}"
LOG_FILE="/var/log/wanos-minidlna-install.log"
log(){ printf '%s\n' "[MiniDLNA] $*"; }
fatal(){ printf '%s\n' "[MiniDLNA] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
fetch(){ url="$1"; out="$2"; if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 1800 --retry 3 --retry-delay 2 -o "$out" "$url"; elif has_cmd wget; then wget -O "$out" "$url"; else fatal "缺少 curl/wget，无法下载离线包"; fi; }
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv6l|arm*) ;; *) fatal "当前架构不支持：$(uname -m)，本应用需要 ARMv7/armhf。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3 用于中文 Web 面板。"
has_cmd dpkg || fatal "系统缺少 dpkg，无法安装离线 deb 包。"
has_cmd sha256sum || fatal "系统缺少 sha256sum。"
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR" "$DATA_DIR/media" "$DATA_DIR/db" "$DATA_DIR/log"
: >"$LOG_FILE" 2>/dev/null || true
if ! has_cmd minidlnad; then
  log "下载 MiniDLNA 离线包：$PKG_URL"
  fetch "$PKG_URL" "$TMP_DIR/package.tar.gz" 2>&1 | tee -a "$LOG_FILE"
  [ -s "$TMP_DIR/package.tar.gz" ] || fatal "离线包下载后为空"
  got="$(sha256sum "$TMP_DIR/package.tar.gz" | awk '{print $1}')"
  [ "$got" = "$PKG_SHA256" ] || fatal "离线包校验失败：want $PKG_SHA256 got $got"
  rm -rf "$TMP_DIR/extract"
  mkdir -p "$TMP_DIR/extract"
  tar -xzf "$TMP_DIR/package.tar.gz" -C "$TMP_DIR/extract" 2>&1 | tee -a "$LOG_FILE" || fatal "离线包解压失败"
  DEB_DIR="$TMP_DIR/extract/debs"
  [ -d "$DEB_DIR" ] || fatal "离线包格式错误：缺少 debs 目录"
  log "安装 MiniDLNA 离线 deb 包"
  DEBIAN_FRONTEND=noninteractive dpkg -i "$DEB_DIR"/*.deb 2>&1 | tee -a "$LOG_FILE" || DEBIAN_FRONTEND=noninteractive dpkg -i "$DEB_DIR"/*.deb 2>&1 | tee -a "$LOG_FILE" || fatal "MiniDLNA 离线 deb 安装失败"
  DEBIAN_FRONTEND=noninteractive dpkg --configure -a 2>&1 | tee -a "$LOG_FILE" || fatal "MiniDLNA 依赖包配置失败"
else
  DEBIAN_FRONTEND=noninteractive dpkg --configure -a 2>&1 | tee -a "$LOG_FILE" || true
fi
fetch "$PANEL_URL" "$APP_DIR/minidlna-panel.py" 2>&1 | tee -a "$LOG_FILE"
chmod 0755 "$APP_DIR/minidlna-panel.py"
if [ ! -f "$DATA_DIR/settings.json" ]; then
cat >"$DATA_DIR/settings.json" <<EOF
{
  "friendly_name": "WanOS DLNA",
  "media_dir": "$DATA_DIR/media"
}
EOF
fi
if [ ! -f "$DATA_DIR/minidlna.conf" ]; then
cat >"$DATA_DIR/minidlna.conf" <<EOF
port=$DLNA_PORT
user=root
friendly_name=WanOS DLNA
media_dir=$DATA_DIR/media
db_dir=$DATA_DIR/db
log_dir=$DATA_DIR/log
inotify=yes
wide_links=yes
notify_interval=900
root_container=B
album_art_names=Cover.jpg/cover.jpg/AlbumArtSmall.jpg/albumartsmall.jpg
EOF
fi
if grep -q '^user=' "$DATA_DIR/minidlna.conf"; then
  sed -i 's/^user=.*/user=root/' "$DATA_DIR/minidlna.conf"
else
  tmp_conf="$DATA_DIR/minidlna.conf.tmp"
  { printf '%s\n' 'user=root'; cat "$DATA_DIR/minidlna.conf"; } >"$tmp_conf"
  mv "$tmp_conf" "$DATA_DIR/minidlna.conf"
fi
chmod 777 "$DATA_DIR/media" 2>/dev/null || true
current_media_dir="$(awk -F= '/^media_dir=/{print substr($0,index($0,"=")+1); exit}' "$DATA_DIR/minidlna.conf" 2>/dev/null | sed 's/^[AVP],//')"
if [ -n "$current_media_dir" ] && [ -d "$current_media_dir" ]; then
  chmod -R a+rX "$current_media_dir" 2>/dev/null || true
fi
cat >/etc/systemd/system/wanos-minidlna.service <<EOF
[Unit]
Description=WanOS MiniDLNA Media Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/minidlnad -S -f $DATA_DIR/minidlna.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat >/etc/systemd/system/wanos-minidlna-panel.service <<EOF
[Unit]
Description=WanOS MiniDLNA Config Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=MINIDLNA_DATA_DIR=$DATA_DIR
Environment=MINIDLNA_PANEL_PORT=$PANEL_PORT
Environment=MINIDLNA_PORT=$DLNA_PORT
ExecStart=/usr/bin/python3 $APP_DIR/minidlna-panel.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "0.1.0-wanos.1" > "$APP_DIR/version"
systemctl daemon-reload
systemctl enable wanos-minidlna wanos-minidlna-panel >/dev/null 2>&1 || true
systemctl restart wanos-minidlna-panel
systemctl stop wanos-minidlna 2>/dev/null || true
pkill -f '/usr/sbin/minidlnad' 2>/dev/null || true
systemctl restart wanos-minidlna
rm -rf "$TMP_DIR"
log "安装完成。配置面板：http://设备IP:$PANEL_PORT；DLNA 端口：$DLNA_PORT。"
