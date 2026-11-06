#!/bin/sh
set -eu
APP_ID="sqlite-phpliteadmin"
APP_NAME="SQLite 数据库"
APP_DIR="${WANOS_APP_INSTALL_DIR:-${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}}"
DATA_DIR="${WANOS_APP_DATA_DIR:-${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
PKG_URL="${SQLITE_PHPLITEADMIN_PKG_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/sqlite-phpliteadmin-focal-armhf-offline-wanos.4.tar.gz}"
PKG_SHA256="${SQLITE_PHPLITEADMIN_PKG_SHA256:-c5e00c31f4e6d65e21394c5ac5435debe302a262eb5488d4544d9173e94be503}"
PANEL_PORT="${SQLITE_PHPLITEADMIN_PORT:-18087}"
LOG_FILE="/var/log/wanos-sqlite-phpliteadmin-install.log"
log(){ printf '%s\n' "[SQLite] $*"; }
fatal(){ printf '%s\n' "[SQLite] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
fetch(){ url="$1"; out="$2"; if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 900 --retry 3 --retry-delay 2 -o "$out" "$url"; elif has_cmd wget; then wget -O "$out" "$url"; else fatal "缺少 curl/wget，无法下载离线包"; fi; }
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
      if [ "$tries" -lt 61 ]; then log "dpkg 正在被其他安装任务占用，等待 10 秒后重试（$tries/60）"; sleep 10; continue; fi
      fatal "等待 dpkg 锁超时，请先结束其他安装/更新任务后重试。"
    fi
    log "dpkg 返回非零状态，继续校验 SQLite 必要组件；若组件可用则不受系统其它半配置包影响。"
    return 0
  done
}
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv6l|arm*) ;; *) fatal "当前架构不支持：$(uname -m)，本应用需要 ARMv7/armhf。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd dpkg || fatal "系统缺少 dpkg，无法安装离线包。"
has_cmd sha256sum || fatal "系统缺少 sha256sum。"
has_cmd tar || fatal "系统缺少 tar，无法解压离线包。"
mkdir -p "$APP_DIR" "$DATA_DIR" "$TMP_DIR" "$DATA_DIR/databases"
: >"$LOG_FILE" 2>/dev/null || true
ARCHIVE="$TMP_DIR/package.tar.gz"
log "下载 SQLite + phpLiteAdmin 完整离线包：$PKG_URL"
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
[ -f "$ASSET_DIR/phpLiteAdmin_v1-9-8-2.zip" ] || fatal "离线包格式错误：缺少 phpLiteAdmin"
[ -f "$ASSET_DIR/lang_cn.php" ] || fatal "离线包格式错误：缺少中文语言包"
if has_cmd php && php -m | grep -qi "^sqlite3$" && php -m | grep -qi "^pdo_sqlite$" && has_cmd sqlite3; then
  log "检测到 PHP SQLite 组件已可用，跳过离线 deb 安装。"
else
  log "安装 PHP CLI、SQLite 扩展和 sqlite3 工具离线 deb 包"
  export DEBIAN_FRONTEND=noninteractive
  run_dpkg_install
fi
has_cmd php || fatal "PHP CLI 安装后仍不可用"
php -m | grep -qi "^sqlite3$" || fatal "PHP sqlite3 扩展不可用"
php -m | grep -qi "^pdo_sqlite$" || fatal "PHP pdo_sqlite 扩展不可用"
rm -rf "$APP_DIR/www"
mkdir -p "$APP_DIR/www"
if has_cmd unzip; then
  unzip -q "$ASSET_DIR/phpLiteAdmin_v1-9-8-2.zip" -d "$TMP_DIR/phpliteadmin"
else
  python3 - "$ASSET_DIR/phpLiteAdmin_v1-9-8-2.zip" "$TMP_DIR/phpliteadmin" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
fi
PLA_FILE="$(find "$TMP_DIR/phpliteadmin" -type f -name 'phpliteadmin.php' | head -1)"
[ -n "$PLA_FILE" ] || fatal "压缩包内未找到 phpliteadmin.php"
cp "$PLA_FILE" "$APP_DIR/www/phpliteadmin.php"
cp "$ASSET_DIR/lang_cn.php" "$APP_DIR/www/lang_cn.php"
PASS_FILE="$DATA_DIR/admin-password.txt"
ADMIN_PASS="${WANOS_APP_ADMIN_PASSWORD:-${SQLITE_PHPLITEADMIN_ADMIN_PASSWORD:-admin}}"
echo "$ADMIN_PASS" >"$PASS_FILE"
chmod 600 "$PASS_FILE"
cat >"$APP_DIR/www/phpliteadmin.config.php" <<EOF
<?php
\$password = '$ADMIN_PASS';
\$directory = '$DATA_DIR/databases';
\$subdirectories = true;
\$rowsNum = 30;
\$language = 'cn';
EOF
cat >"$APP_DIR/www/index.php" <<'PHP'
<?php
$passwordFile = '__DATA_DIR__/admin-password.txt';
$password = is_file($passwordFile) ? trim(file_get_contents($passwordFile)) : '';
?>
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SQLite 数据库</title><style>body{font-family:Arial,"Microsoft YaHei",sans-serif;background:#f6f8fb;margin:0;color:#172033}.wrap{max-width:760px;margin:34px auto;padding:0 18px}.card{background:#fff;border:1px solid #e4e8f0;border-radius:8px;padding:22px;box-shadow:0 10px 28px rgba(20,35,60,.08)}h1{font-size:24px;margin:0 0 8px}.muted{color:#64748b}.grid{display:grid;grid-template-columns:130px 1fr;gap:10px 14px;margin:18px 0}.k{color:#64748b}.v{font-family:Consolas,monospace;background:#f1f5f9;border-radius:6px;padding:7px 9px;word-break:break-all}.btn{display:inline-block;background:#1f6feb;color:white;text-decoration:none;border-radius:6px;padding:10px 14px}.warn{background:#ecfeff;border:1px solid #99f6e4;color:#115e59;border-radius:6px;padding:10px 12px;margin-top:14px}</style></head><body><div class="wrap"><div class="card"><h1>SQLite 数据库</h1><p class="muted">轻量数据库管理器，无需常驻数据库服务，适合管理 .db/.sqlite 文件。</p><div class="grid"><div class="k">管理密码</div><div class="v"><?php echo htmlspecialchars($password); ?></div><div class="k">数据库目录</div><div class="v">__DATA_DIR__/databases</div><div class="k">服务端口</div><div class="v">18087</div></div><a class="btn" href="/phpliteadmin.php">打开 phpLiteAdmin</a><div class="warn">把 .db、.sqlite 文件放到数据库目录后即可在面板中管理，也可以在面板中新建数据库。</div></div></div></body></html>
PHP
sed -i "s#__DATA_DIR__#$DATA_DIR#g" "$APP_DIR/www/index.php"
chown -R root:root "$APP_DIR" "$DATA_DIR" 2>/dev/null || true
chmod 700 "$DATA_DIR" "$DATA_DIR/databases" 2>/dev/null || true
cat >/etc/systemd/system/sqlite-phpliteadmin.service <<EOF
[Unit]
Description=WanOS SQLite phpLiteAdmin Panel
After=network-online.target
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
echo "1.9.8.2-wanos.4" >"$APP_DIR/version"
systemctl daemon-reload
systemctl enable sqlite-phpliteadmin >/dev/null 2>&1 || true
systemctl restart sqlite-phpliteadmin
rm -rf "$TMP_DIR"
log "安装完成。phpLiteAdmin 面板端口：$PANEL_PORT；密码保存在 $PASS_FILE；数据库目录：$DATA_DIR/databases"
