#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_DIR:-/opt/wanos/apps/gitea}"
DATA_DIR="${WANOS_APP_DATA_DIR:-/opt/wanos-data/apps/gitea}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/gitea-1.26.2-linux-arm-6.xz"
PKG_SHA="1857b14b287fac4fb40822f099aa36b099d8efd40e79aca5185f9a649ae73758"
log(){ echo "[Gitea] $*"; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { log "ERROR: 缺少命令 $1"; exit 1; }; }
sha_check(){ file="$1"; want="$2"; got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || { log "ERROR: 校验失败：want $want got $got"; exit 1; }; }
fetch(){ url="$1"; out="$2"; if command -v curl >/dev/null 2>&1; then curl -fL --connect-timeout 20 --retry 2 "$url" -o "$out"; elif command -v wget >/dev/null 2>&1; then wget -O "$out" "$url"; else log "ERROR: 缺少 curl/wget"; exit 1; fi; }
case "$(uname -m)" in armv7l|armv6l|arm*) ;; *) log "ERROR: 当前架构 $(uname -m) 暂不支持，本应用需要 ARMv7/armhf"; exit 1 ;; esac
need_cmd sha256sum
need_cmd awk
need_cmd xz
mkdir -p "$APP_DIR/bin" "$DATA_DIR/custom/conf" "$DATA_DIR/data" "$DATA_DIR/log" "$DATA_DIR/repos" "$TMP_DIR"
if ! id gitea >/dev/null 2>&1; then
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --home "$DATA_DIR" --shell /usr/sbin/nologin gitea
  elif command -v adduser >/dev/null 2>&1; then
    adduser --system --home "$DATA_DIR" --shell /usr/sbin/nologin --no-create-home gitea
  else
    log "ERROR: missing useradd/adduser; cannot create gitea runtime user"
    exit 1
  fi
fi
log "下载安装包：$PKG_URL"
fetch "$PKG_URL" "$TMP_DIR/gitea.xz"
sha_check "$TMP_DIR/gitea.xz" "$PKG_SHA"
xz -dc "$TMP_DIR/gitea.xz" > "$APP_DIR/bin/gitea"
chmod 755 "$APP_DIR/bin/gitea"
chown -R gitea:gitea "$APP_DIR" "$DATA_DIR"
cat >"$DATA_DIR/custom/conf/app.ini" <<EOF
APP_NAME = WanOS Gitea
RUN_USER = gitea
RUN_MODE = prod
WORK_PATH = ${DATA_DIR}

[database]
DB_TYPE = sqlite3
PATH = ${DATA_DIR}/data/gitea.db

[repository]
ROOT = ${DATA_DIR}/repos

[server]
DOMAIN = localhost
HTTP_ADDR = 0.0.0.0
HTTP_PORT = 3000
ROOT_URL = http://localhost:3000/
DISABLE_SSH = true
APP_DATA_PATH = ${DATA_DIR}/data
LFS_START_SERVER = true
LFS_JWT_SECRET = wanos-gitea-lfs-secret

[security]
INSTALL_LOCK = false
SECRET_KEY = wanos-gitea-secret-key-change-after-setup

[log]
MODE = file
LEVEL = Info
ROOT_PATH = ${DATA_DIR}/log
EOF
cat >/etc/systemd/system/gitea.service <<EOF
[Unit]
Description=WanOS Gitea Git Service
After=network-online.target
Wants=network-online.target

[Service]
User=gitea
Group=gitea
Type=simple
WorkingDirectory=${DATA_DIR}
ExecStart=${APP_DIR}/bin/gitea web --config ${DATA_DIR}/custom/conf/app.ini
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "1.26.2-wanos.2" > "$APP_DIR/version"
systemctl daemon-reload
systemctl enable gitea >/dev/null 2>&1 || true
systemctl restart gitea
rm -rf "$TMP_DIR"
log "安装完成。Web 面板端口：3000；首次打开按页面提示完成初始化。"
