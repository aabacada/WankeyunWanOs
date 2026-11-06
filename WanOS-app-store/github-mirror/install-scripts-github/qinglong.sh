#!/bin/sh
set -eu
APP_ID="qinglong"
APP_NAME="青龙面板"
IMAGE="${QINGLONG_IMAGE:-whyour/qinglong:2.17.7-linuxarmv7}"
CONTAINER="${QINGLONG_CONTAINER:-wanos-qinglong}"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
QL_DATA_DIR="$DATA_DIR/data"
PORT="${QINGLONG_PORT:-5700}"
PKG_URL="${QINGLONG_IMAGE_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/qinglong_2.17.7_linux_armv7_docker_image.tar.gz}"
PKG_SHA256="${QINGLONG_IMAGE_SHA256:-dbacbfae0ead6410c720cd7283d50e6065d770bd55c065018bdc804235dd1c6d}"
TMP_DIR="$DATA_DIR/.tmp-install"
LOG_FILE="/var/log/wanos-qinglong-install.log"
log(){ printf '%s
' "[青龙面板] $*"; }
fatal(){ printf '%s
' "[青龙面板] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
fetch(){
  url="$1"; out="$2"
  if has_cmd curl; then
    curl -fL --connect-timeout 20 --max-time 3600 --retry 3 --retry-delay 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -O "$out" "$url"
  else
    fatal "缺少 curl/wget，无法下载离线镜像包"
  fi
}
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装。"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "当前架构不支持：$(uname -m)，本应用需要 ARMv7/armhf。" ;; esac
has_cmd docker || fatal "本应用依赖 Docker，请先安装 WanOS Docker 组件后再安装。"
DOCKER_BIN="$(command -v docker)"
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd sha256sum || fatal "系统缺少 sha256sum。"
has_cmd tar || fatal "系统缺少 tar。"
case "$PORT" in 80|8080) fatal "$PORT 是系统保留端口，请改用 5700 或其他端口。" ;; esac
mkdir -p "$APP_DIR" "$QL_DATA_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
log "开始安装青龙面板"
log "Docker 命令：$DOCKER_BIN"
if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
  fatal "Docker 服务未运行，请先启动 Docker 后重试。"
fi
if "$DOCKER_BIN" ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  log "青龙容器已在运行，跳过重复安装。"
  exit 0
fi
ARCHIVE="$TMP_DIR/qinglong-image.tar.gz"
case "$PKG_URL" in
  file://*)
    ARCHIVE="${PKG_URL#file://}"
    log "使用本地离线镜像包：$ARCHIVE"
    [ -s "$ARCHIVE" ] || fatal "本地离线镜像包不存在：$ARCHIVE"
    ;;
  *)
    log "下载青龙 Docker 离线镜像包：$PKG_URL"
    fetch "$PKG_URL" "$ARCHIVE" 2>&1
    ;;
esac
[ -s "$ARCHIVE" ] || fatal "离线镜像包为空"
size="$(wc -c <"$ARCHIVE" | tr -d ' ')"
log "离线镜像包下载完成，大小：$size 字节"
if [ -n "$PKG_SHA256" ]; then
  got="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  log "离线镜像包 SHA256：$got"
  [ "$got" = "$PKG_SHA256" ] || fatal "离线镜像包校验失败：want $PKG_SHA256 got $got"
fi
log "导入青龙 Docker 镜像"
LOAD_LOG="$TMP_DIR/docker-load.log"
if "$DOCKER_BIN" load -i "$ARCHIVE" >"$LOAD_LOG" 2>&1; then
  cat "$LOAD_LOG"
else
  cat "$LOAD_LOG" || true
  log "直接导入失败，尝试 gzip 解压管道导入"
  if command -v gzip >/dev/null 2>&1 && gzip -dc "$ARCHIVE" | "$DOCKER_BIN" load >"$LOAD_LOG" 2>&1; then
    cat "$LOAD_LOG"
  else
    cat "$LOAD_LOG" || true
    fatal "Docker 镜像导入失败"
  fi
fi
if ! "$DOCKER_BIN" image inspect "$IMAGE" >/dev/null 2>&1; then
  loaded_id="$($DOCKER_BIN images --format '{{.Repository}}:{{.Tag}}' | grep -E '(^|/)qinglong:2.17.7-linuxarmv7$' | head -n 1 || true)"
  if [ -n "$loaded_id" ]; then
    IMAGE="$loaded_id"
  else
    image_id="$($DOCKER_BIN images --format '{{.ID}} {{.Repository}}:{{.Tag}}' | awk '$2 ~ /qinglong/ {print $1; exit}')"
    [ -n "$image_id" ] || fatal "镜像导入后未找到 $IMAGE"
    "$DOCKER_BIN" tag "$image_id" "$IMAGE"
  fi
fi
log "使用镜像：$IMAGE"
cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
exec "$DOCKER_BIN" run --name "$CONTAINER" --rm --network host \
  -e TZ=Asia/Shanghai \
  -e QlBaseUrl=/ \
  -v "$QL_DATA_DIR:/ql/data" \
  "$IMAGE"
EOF
chmod +x "$APP_DIR/run.sh"
cat >"/etc/systemd/system/qinglong.service" <<EOF
[Unit]
Description=WanOS Qinglong Panel
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=simple
Restart=always
RestartSec=8
ExecStartPre=-$DOCKER_BIN rm -f $CONTAINER
ExecStart=$APP_DIR/run.sh
ExecStop=$DOCKER_BIN stop $CONTAINER
ExecStopPost=-$DOCKER_BIN rm -f $CONTAINER

[Install]
WantedBy=multi-user.target
EOF
cat >"$APP_DIR/README-WanOS.txt" <<EOF
青龙面板安装完成

访问地址：http://设备IP:$PORT
首次进入请按页面提示完成初始化账号配置。

数据目录：$QL_DATA_DIR
镜像：$IMAGE
EOF
systemctl daemon-reload
systemctl enable --now qinglong.service
sleep 5
if ! systemctl is-active qinglong.service >/dev/null 2>&1; then
  systemctl status qinglong.service --no-pager -l 2>&1 || true
  fatal "青龙服务启动失败，请查看 $LOG_FILE"
fi
rm -rf "$TMP_DIR"
log "安装完成。访问地址：http://设备IP:$PORT；首次进入请按页面提示初始化账号。"
