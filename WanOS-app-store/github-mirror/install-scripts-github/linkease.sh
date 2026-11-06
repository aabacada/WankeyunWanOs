#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_DIR:-/opt/wanos/apps/linkease}"
DATA_DIR="${WANOS_APP_DATA_DIR:-/opt/wanos-data/apps/linkease}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
BIN_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/linkease-binary-1.7.5.tar.gz"
BIN_SHA="f3ae319974d940f5741cd9fbd295a3a378164e7df82665defa99935608fe733a"
MOUNT_URL="https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/linkmount-arm.zip"
MOUNT_SHA="eb08439f15bfaada23c7c733c5ad3876ea60e613745b95cbef5a5ad1383593fe"
log(){ echo "[易有云] $*"; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { log "ERROR: 缺少命令 $1"; exit 1; }; }
sha_check(){ file="$1"; want="$2"; got="$(sha256sum "$file" | awk '{print $1}')"; [ "$got" = "$want" ] || { log "ERROR: 校验失败：want $want got $got"; exit 1; }; }
fetch(){ url="$1"; out="$2"; if command -v curl >/dev/null 2>&1; then curl -fL --connect-timeout 20 --retry 2 "$url" -o "$out"; elif command -v wget >/dev/null 2>&1; then wget -O "$out" "$url"; else log "ERROR: 缺少 curl/wget"; exit 1; fi; }
case "$(uname -m)" in armv7l|armv6l|arm*) ;; *) log "ERROR: 当前架构 $(uname -m) 暂不支持，本应用需要 ARMv7/armhf"; exit 1 ;; esac
need_cmd sha256sum
need_cmd awk
need_cmd unzip
need_cmd tar
mkdir -p "$APP_DIR/bin" "$DATA_DIR" "$TMP_DIR"
log "下载安装包：$BIN_URL"
fetch "$BIN_URL" "$TMP_DIR/linkease-binary.tar.gz"
sha_check "$TMP_DIR/linkease-binary.tar.gz" "$BIN_SHA"
log "下载挂载组件：$MOUNT_URL"
fetch "$MOUNT_URL" "$TMP_DIR/linkmount-arm.zip"
sha_check "$TMP_DIR/linkmount-arm.zip" "$MOUNT_SHA"
rm -rf "$TMP_DIR/linkease-binary" "$TMP_DIR/linkmount"
mkdir -p "$TMP_DIR/linkease-binary" "$TMP_DIR/linkmount"
tar --strip-components=1 -zxf "$TMP_DIR/linkease-binary.tar.gz" -C "$TMP_DIR/linkease-binary"
unzip -q "$TMP_DIR/linkmount-arm.zip" -d "$TMP_DIR/linkmount"
cp "$TMP_DIR/linkease-binary/linkease.arm" "$APP_DIR/bin/linkease"
cp "$TMP_DIR/linkease-binary/heif-converter.arm" "$APP_DIR/bin/heif-converter"
cp "$TMP_DIR/linkease-binary/linkease-media.arm" "$APP_DIR/bin/linkease-media"
rm -rf "$APP_DIR/bin/linkmount"
cp -a "$TMP_DIR/linkmount/arm/bin" "$APP_DIR/bin/linkmount"
chmod 755 "$APP_DIR/bin/linkease" "$APP_DIR/bin/heif-converter" "$APP_DIR/bin/linkease-media" || true
find "$APP_DIR/bin/linkmount" -type f -exec chmod 755 {} \; 2>/dev/null || true
ln -sf "$APP_DIR/bin/linkease" /usr/sbin/linkease
ln -sf "$APP_DIR/bin/heif-converter" /usr/sbin/heif-converter
ln -sf "$APP_DIR/bin/linkease-media" /usr/sbin/linkease-media
rm -rf /usr/sbin/linkmount
ln -sfn "$APP_DIR/bin/linkmount" /usr/sbin/linkmount
export PATH="$APP_DIR/bin:$APP_DIR/bin/linkmount:/usr/sbin:/usr/bin:/sbin:/bin"
log "安装系统服务"
"$APP_DIR/bin/linkease" --serviceControl uninstall >/dev/null 2>&1 || true
"$APP_DIR/bin/linkease" --serviceControl install
"$APP_DIR/bin/linkease" --serviceControl start || { log "serviceControl start 失败，尝试 systemctl 启动"; systemctl start com.linkease.linkeasedaemon.service; }
echo "1.7.5-wanos.1" > "$APP_DIR/version"
rm -rf "$TMP_DIR"
log "安装完成。Web 面板端口：8897"
