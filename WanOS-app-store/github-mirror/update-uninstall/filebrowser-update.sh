#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_DIR:-/opt/wanos/apps/filebrowser}"
DATA_DIR="${WANOS_APP_DATA_DIR:-/opt/wanos-data/apps/filebrowser}"
ROOT_DIR="/"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
ADMIN_USER="${FILEBROWSER_ADMIN_USERNAME:-${WANOS_APP_ADMIN_USERNAME:-${WANOS_APP_USERNAME:-admin}}}"
ADMIN_PASS="${FILEBROWSER_ADMIN_PASSWORD:-${WANOS_APP_ADMIN_PASSWORD:-${WANOS_APP_PASSWORD:-wanosfile123}}}"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/filebrowser/linux-armv7-filebrowser-v2.63.10.tar.gz"
PKG_SHA="abd2f3ee4d72bff5d550a14a8c681c1f84ba91df4745381568a640e7d8708671"
log(){ echo "[Filebrowser] $*"; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { log "ERROR: 缺少命令 $1"; exit 1; }; }
sha_check(){ file="$1"; want="$2"; got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || { log "ERROR: 校验失败：want $want got $got"; exit 1; }; }
fetch(){ url="$1"; out="$2"; if command -v curl >/dev/null 2>&1; then curl -fL --connect-timeout 20 --retry 2 "$url" -o "$out"; elif command -v wget >/dev/null 2>&1; then wget -O "$out" "$url"; else log "ERROR: 缺少 curl/wget"; exit 1; fi; }
case "$(uname -m)" in armv7l|armv6l|arm*) ;; *) log "ERROR: 当前架构 $(uname -m) 暂不支持，本应用需要 ARMv7/armhf"; exit 1 ;; esac
need_cmd sha256sum
need_cmd awk
need_cmd tar
[ "${#ADMIN_PASS}" -ge 12 ] || { log "ERROR: Filebrowser 登录密码不能低于 12 位"; exit 1; }
mkdir -p "$APP_DIR/bin" "$DATA_DIR" "$TMP_DIR"
log "下载安装包：$PKG_URL"
fetch "$PKG_URL" "$TMP_DIR/filebrowser.tar.gz"
sha_check "$TMP_DIR/filebrowser.tar.gz" "$PKG_SHA"
tar -zxf "$TMP_DIR/filebrowser.tar.gz" -C "$TMP_DIR" filebrowser
cp "$TMP_DIR/filebrowser" "$APP_DIR/bin/filebrowser"
chmod 755 "$APP_DIR/bin/filebrowser"
if [ ! -s "$DATA_DIR/filebrowser.db" ]; then
  "$APP_DIR/bin/filebrowser" config init -d "$DATA_DIR/filebrowser.db" >/dev/null
fi
"$APP_DIR/bin/filebrowser" config set -d "$DATA_DIR/filebrowser.db" --root "$ROOT_DIR" --address 0.0.0.0 --port 8082 --minimumPasswordLength 12 >/dev/null
if ! "$APP_DIR/bin/filebrowser" users update "$ADMIN_USER" --password "$ADMIN_PASS" --perm.admin -d "$DATA_DIR/filebrowser.db" >/dev/null 2>&1; then
  "$APP_DIR/bin/filebrowser" users add "$ADMIN_USER" "$ADMIN_PASS" --perm.admin -d "$DATA_DIR/filebrowser.db" >/dev/null
fi
if [ "$ADMIN_USER" != "admin" ]; then
  "$APP_DIR/bin/filebrowser" users update admin --password "$ADMIN_PASS" -d "$DATA_DIR/filebrowser.db" >/dev/null 2>&1 || true
fi
cat >/etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=WanOS Filebrowser
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${DATA_DIR}
ExecStart=${APP_DIR}/bin/filebrowser -a 0.0.0.0 -p 8082 -r / -d ${DATA_DIR}/filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "2.63.10-wanos.1" > "$APP_DIR/version"
systemctl daemon-reload
systemctl enable filebrowser >/dev/null 2>&1 || true
systemctl restart filebrowser
rm -rf "$TMP_DIR"
log "更新完成。Web 面板端口：8082；账号 $ADMIN_USER，密码 $ADMIN_PASS，请首次登录后立即修改。"
