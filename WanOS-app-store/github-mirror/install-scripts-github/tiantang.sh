#!/bin/sh
set -eu

APP_ID="tiantang"
APP_NAME="甜糖边缘节点"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
CACHE_DIR="${TIANTANG_CACHE_DIR:-$DATA_DIR/cache}"
LOG_DIR="$DATA_DIR/logs"
BIN="$APP_DIR/ttmanager_arm32"
RUNNER="$APP_DIR/ttrun.sh"
SERVICE_RUNNER="$APP_DIR/wanos-service-run.sh"
NODE_TYPE="${TIANTANG_NODE_TYPE:-edsnodex}"
SERVICE="/etc/systemd/system/$APP_ID.service"
BIN_URL="${TIANTANG_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/ttmanager_arm32}"
BIN_SHA256="8b58b2bf3db031d901dfb4b977648fa6efa73d78a2cb69eb19fba229311cc181"

log() { printf '%s\n' "[甜糖] $*"; }
fatal() { printf '%s\n' "[甜糖] ERROR: $*" >&2; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }
sha256_file() {
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "缺少 sha256sum，无法校验甜糖二进制。"; fi
}

register_desktop_icon() {
  log "注册桌面入口。"
  APP_NAV_JSON='{"id":"tiantang","name":"甜糖边缘节点","icon":"https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/tiantang.png","port":1024,"path":"/","description":"甜糖边缘节点管理面板"}'
  if command -v node >/dev/null 2>&1; then
    APP_NAV_JSON="$APP_NAV_JSON" node <<'NODE'
const fs = require("fs");
const path = require("path");
const item = JSON.parse(process.env.APP_NAV_JSON || "{}");
const paths = [
  process.env.MYBOX_DATA ? process.env.MYBOX_DATA + "/config.json" : "",
  "/opt/wanos-data/config.json",
  "/opt/mybox/data/config.json"
].filter(Boolean);
let wrote = false;
for (const file of paths) {
  try {
    let cfg = {};
    if (fs.existsSync(file)) cfg = JSON.parse(fs.readFileSync(file, "utf8") || "{}");
    else fs.mkdirSync(path.dirname(file), { recursive: true });
    const apps = Array.isArray(cfg.apps) ? cfg.apps.filter(app => app && app.id !== item.id) : [];
    apps.push(item);
    cfg.apps = apps;
    fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
    wrote = true;
    break;
  } catch (err) {}
}
process.exit(wrote ? 0 : 1);
NODE
    if [ $? -eq 0 ]; then
      if command -v systemctl >/dev/null 2>&1; then systemctl restart alist 2>/dev/null || systemctl restart mybox 2>/dev/null || true; fi
      return 0
    fi
  fi
  log "桌面入口注册失败，可在应用导航中手动添加：http://设备IP:1024"
}

install_runtime_deps() {
  log "检查甜糖二进制运行环境。"
  missing=""
  for cmd in ss; do
    if ! command -v "$cmd" >/dev/null 2>&1; then missing="$missing $cmd"; fi
  done
  if [ -n "$missing" ]; then
    if command -v apt-get >/dev/null 2>&1; then
      log "正在补齐基础网络检测工具。"
      apt-get update >/dev/null 2>&1 || true
      DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2 >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
      log "正在补齐基础网络检测工具。"
      yum install -y iproute >/dev/null 2>&1 || true
    fi
  fi
  if ! command -v ss >/dev/null 2>&1; then
    log "未找到 ss 命令，仅跳过 1024 端口自动检测，不影响甜糖二进制启动。"
  fi
}

[ "$(id -u)" = "0" ] || fatal "请使用 root 用户安装。"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
case "$ARCH" in
  armv7l|armv7*) ;;
  *) fatal "当前甜糖安装包只支持 ARMv7/arm32，检测到：$ARCH。" ;;
esac

install_runtime_deps
mkdir -p "$APP_DIR" "$DATA_DIR" "$CACHE_DIR" "$LOG_DIR"
log "正在安装甜糖 ARM32 二进制包。"
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f 'ttmanager_arm32|ttnode|ttrun.sh' >/dev/null 2>&1 || true

TMP="$APP_DIR/.ttmanager_arm32.tmp"
rm -f "$TMP"
if has_cmd curl; then
  curl -kfsSL --connect-timeout 20 --retry 2 "$BIN_URL" -o "$TMP"
elif has_cmd wget; then
  wget --no-check-certificate -O "$TMP" "$BIN_URL"
else
  fatal "缺少 curl/wget，无法下载甜糖二进制。"
fi
GOT="$(sha256_file "$TMP")"
[ "$GOT" = "$BIN_SHA256" ] || fatal "甜糖二进制校验失败：want $BIN_SHA256 got $GOT"
mv "$TMP" "$BIN"
chmod 0755 "$BIN"

# 让甜糖官方程序生成保活脚本；失败时使用 WanOS 自带保活脚本兜底。
(
  cd "$APP_DIR"
  "$BIN" -g >/dev/null 2>&1 || true
)
if [ ! -s "$RUNNER" ]; then
  cat >"$RUNNER" <<EOF
#!/bin/sh
set -eu
cd "$APP_DIR"
exec "$BIN" "$@"
EOF
  chmod 0755 "$RUNNER"
fi
chmod 0755 "$RUNNER" || true

cat >"$SERVICE_RUNNER" <<EOF
#!/bin/sh
set -eu
mkdir -p "$LOG_DIR" "$CACHE_DIR"
cd "$APP_DIR"
echo "[WanOS] start tiantang: cache=$CACHE_DIR node=$NODE_TYPE" >>"$LOG_DIR/ttnode.log"
exec "$RUNNER" -c "$CACHE_DIR" -t "$NODE_TYPE" >>"$LOG_DIR/ttnode.log" 2>&1
EOF
chmod 0755 "$SERVICE_RUNNER"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS Tiantang Edge Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=/bin/sh $SERVICE_RUNNER
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
register_desktop_icon
sleep 5
if command -v ss >/dev/null 2>&1; then
  if ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:|\])1024$'; then
    log "甜糖 1024 管理端口已启动。"
  else
    log "甜糖服务已提交启动，但暂未监听 1024；请查看日志：journalctl -u $APP_ID -n 120 --no-pager 或 $LOG_DIR/ttnode.log"
  fi
fi
sleep 2
UUID="$(journalctl -u "$APP_ID" -n 120 --no-pager 2>/dev/null | grep -Eo '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | tail -n 1 || true)"
if [ -n "$UUID" ]; then
  log "安装完成，设备 UUID：$UUID，请用甜糖 APP 绑定。"
else
  log "安装完成，请查看日志绑定设备：journalctl -u $APP_ID -n 120 --no-pager"
fi
cat >"$APP_DIR/README-WanOS.txt" <<EOF
甜糖边缘节点已安装。

程序：$BIN
缓存目录：$CACHE_DIR
运行日志：$LOG_DIR/ttnode.log
服务：systemctl status $APP_ID --no-pager
管理地址：http://设备IP:1024/
默认节点：$NODE_TYPE

绑定方式：
1. 打开甜糖 APP。
2. 查看运行日志中的 UUID/二维码并绑定设备：journalctl -u $APP_ID -n 120 --no-pager
3. 打开 http://设备IP:1024/ 进入管理界面，默认会尝试启动 $NODE_TYPE 节点。

说明：PCDN 会占用上传带宽和磁盘缓存，请确认宽带运营商规则后使用。

任何的规则和收益结算所有权归甜糖科技，与WanOS无任何关联。
重要提醒，此类业务归属PCDN边缘计算，你自己衡量宽带是否合法。
EOF
