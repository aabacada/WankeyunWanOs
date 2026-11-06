#!/bin/sh
set -eu

APP_ID="pansou"
APP_NAME="PanSou"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
BIN_DIR="$APP_DIR/bin"
ASSET_DIR="$APP_DIR/assets"
CONFIG_DIR="$DATA_DIR/config"
SERVICE="/etc/systemd/system/$APP_ID.service"
PORT="${PANSOU_PORT:-12888}"
ADDR="${PANSOU_ADDRESS:-0.0.0.0:$PORT}"
BIN_URL="${PANSOU_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/pansou-linux-armv7-v3}"
ICON_URL="${PANSOU_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/pansou.png}"
BIN_SHA256="${PANSOU_BIN_SHA256:-b02eaaa5c532f5e7760fe925df5d62bdafa5db0c8a4b369efe2b2ac14647c6ff}"
TMP_BIN="$DATA_DIR/.tmp-$APP_ID"
LOG_FILE="/var/log/wanos-$APP_ID-install.log"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

fetch(){
  url="$1"; out="$2"
  case "$url" in
    file://*) src="${url#file://}"; [ -s "$src" ] || fatal "local file not found: $src"; cp "$src" "$out" ;;
    *)
      if has_cmd curl; then curl -fL --connect-timeout 20 --max-time 1800 --retry 3 --retry-delay 2 -o "$out" "$url";
      elif has_cmd wget; then wget -O "$out" "$url";
      else fatal "missing curl/wget, cannot download app file"; fi
      ;;
  esac
  [ -s "$out" ] || fatal "downloaded file is empty: $out"
}

sha256_file(){
  if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}';
  elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}';
  else fatal "missing sha256sum, cannot verify app file"; fi
}

write_default_config(){
  mkdir -p "$CONFIG_DIR"
  cat >"$CONFIG_DIR/pansou.env" <<EOF
# PanSou runtime configuration for WanOS ARMv7.
PORT=$PORT
CACHE_PATH=./cache
CACHE_ENABLED=false
CACHE_MAX_SIZE=100
CACHE_TTL=60
ASYNC_PLUGIN_ENABLED=true
ASYNC_RESPONSE_TIMEOUT=4
ASYNC_MAX_BACKGROUND_WORKERS=20
ASYNC_MAX_BACKGROUND_TASKS=100
ASYNC_CACHE_TTL_HOURS=1
ASYNC_LOG_ENABLED=true
ENABLE_COMPRESSION=false
MIN_SIZE_TO_COMPRESS=1024
GC_PERCENT=50
OPTIMIZE_MEMORY=true
PLUGIN_TIMEOUT=30
AUTH_ENABLED=false
AUTH_TOKEN_EXPIRY=24
CHANNELS=tgsearchers7,Aliyun_4K_Movies,bdbdndn11,yunpanx,bsbdbfjfjff,yp123pan,sbsbsnsqq,yunpanxunlei,tianyifc,BaiduCloudDisk,txtyzy,peccxinpd,gotopan,PanjClub,kkxlzy,baicaoZY,MCPH01,MCPH02,MCPH03,bdwpzhpd,ysxb48,jdjdn1111,yggpan,MCPH086,zaihuayun,Q66Share,ucwpzy,shareAliyun,alyp_1,dianyingshare,Quark_Movies,XiangxiuNBB,ydypzyfx,ucquark,xx123pan,yingshifenxiang123,zyfb123,tyypzhpd,tianyirigeng,cloudtianyi,hdhhd21,Lsp115,oneonefivewpfx,qixingzhenren,taoxgzy,Channel_Shares_115,tyysypzypd,vip115hot,wp123zy,yunpan139,yunpan189,yunpanuc,yydf_hzl,leoziyuan,Q_dongman,yoyokuakeduanju,TG654TG,WFYSFX02,QukanMovie,yeqingjie_GJG666,movielover8888_film3,Baidu_netdisk,D_wusun,FLMdongtianfudi,KaiPanshare,QQZYDAPP,rjyxfx,PikPak_Share_Channel,btzhi,newproductsourcing,cctv1211,duan_ju,QuarkFree,yunpanNB,kkdj001,xxzlzn,pxyunpanxunlei,jxwpzy,kuakedongman,liangxingzhinan,xiangnikanj,solidsexydoll,guoman4K,zdqxm,kduanju,cilidianying,CBduanju,SharePanFilms,dzsgx,BooksRealm,Oscar_4Kmovies,douerpan,baidu_yppan,Q_jilupian,Netdisk_Movies,yunpanquark,ammmziyuan,ciliziyuanku,cili8888,jzmm_123pan,Q_dianying,domgmingapk,dianying4k,q_dianshiju,tgbokee,ucshare,godupan,gokuapan,gimy115,WFYSFX03,peccxin,Movie888035,xlwpzy,zyywpzy,wydwpzy,gimy100,ucshare,gimy115iso,aliyunys,clouddriveresources,XunLeiPinDao,ydwpzy,a123fxme,WPpindao,kuyupan,djya5,pan_guangya
ENABLED_PLUGINS=labi,zhizhen,shandian,duoduo,muou,wanou,hunhepan,jikepan,panwiki,pansearch,panta,qupansou,hdr4k,pan666,susu,thepiratebay,xuexizhinan,panyq,ouge,huban,cyg,erxiao,miaoso,fox4k,pianku,clmao,wuji,cldi,xiaozhang,libvio,leijing,xb6v,xys,ddys,hdmoli,yuhuage,u3c3,javdb,clxiong,jutoushe,sdso,xiaoji,xdyh,haisou,bixin,djgou,nyaa,xinjuc,aikanzy,qupanshe,xdpan,discourse,yunsou,qqpd,ahhhhfs,nsgame,gying,quark4k,quarksoo,sousou,ash
EOF
}

set_env_line(){
  key="$1"
  value="$2"
  file="$3"
  if grep -q "^$key=" "$file"; then
    sed -i "s|^$key=.*|$key=$value|" "$file"
  else
    printf '\n%s=%s\n' "$key" "$value" >>"$file"
  fi
}

ensure_config(){
  file="$CONFIG_DIR/pansou.env"
  if [ ! -s "$file" ]; then
    write_default_config
    return
  fi
  if ! awk 'BEGIN{ok=1} /^[[:space:]]*($|#)/{next} index($0,"=")==0{ok=0; exit} END{exit ok?0:1}' "$file"; then
    backup="$file.bad.$(date +%Y%m%d%H%M%S)"
    mv -f "$file" "$backup" 2>/dev/null || true
    log "invalid pansou.env backed up: $backup"
    write_default_config
    return
  fi
  set_env_line PORT "$PORT" "$file"
  set_env_line CACHE_ENABLED "false" "$file"
  set_env_line CHANNELS "tgsearchers7,Aliyun_4K_Movies,bdbdndn11,yunpanx,bsbdbfjfjff,yp123pan,sbsbsnsqq,yunpanxunlei,tianyifc,BaiduCloudDisk,txtyzy,peccxinpd,gotopan,PanjClub,kkxlzy,baicaoZY,MCPH01,MCPH02,MCPH03,bdwpzhpd,ysxb48,jdjdn1111,yggpan,MCPH086,zaihuayun,Q66Share,ucwpzy,shareAliyun,alyp_1,dianyingshare,Quark_Movies,XiangxiuNBB,ydypzyfx,ucquark,xx123pan,yingshifenxiang123,zyfb123,tyypzhpd,tianyirigeng,cloudtianyi,hdhhd21,Lsp115,oneonefivewpfx,qixingzhenren,taoxgzy,Channel_Shares_115,tyysypzypd,vip115hot,wp123zy,yunpan139,yunpan189,yunpanuc,yydf_hzl,leoziyuan,Q_dongman,yoyokuakeduanju,TG654TG,WFYSFX02,QukanMovie,yeqingjie_GJG666,movielover8888_film3,Baidu_netdisk,D_wusun,FLMdongtianfudi,KaiPanshare,QQZYDAPP,rjyxfx,PikPak_Share_Channel,btzhi,newproductsourcing,cctv1211,duan_ju,QuarkFree,yunpanNB,kkdj001,xxzlzn,pxyunpanxunlei,jxwpzy,kuakedongman,liangxingzhinan,xiangnikanj,solidsexydoll,guoman4K,zdqxm,kduanju,cilidianying,CBduanju,SharePanFilms,dzsgx,BooksRealm,Oscar_4Kmovies,douerpan,baidu_yppan,Q_jilupian,Netdisk_Movies,yunpanquark,ammmziyuan,ciliziyuanku,cili8888,jzmm_123pan,Q_dianying,domgmingapk,dianying4k,q_dianshiju,tgbokee,ucshare,godupan,gokuapan,gimy115,WFYSFX03,peccxin,Movie888035,xlwpzy,zyywpzy,wydwpzy,gimy100,ucshare,gimy115iso,aliyunys,clouddriveresources,XunLeiPinDao,ydwpzy,a123fxme,WPpindao,kuyupan,djya5,pan_guangya" "$file"
  set_env_line ENABLED_PLUGINS "labi,zhizhen,shandian,duoduo,muou,wanou,hunhepan,jikepan,panwiki,pansearch,panta,qupansou,hdr4k,pan666,susu,thepiratebay,xuexizhinan,panyq,ouge,huban,cyg,erxiao,miaoso,fox4k,pianku,clmao,wuji,cldi,xiaozhang,libvio,leijing,xb6v,xys,ddys,hdmoli,yuhuage,u3c3,javdb,clxiong,jutoushe,sdso,xiaoji,xdyh,haisou,bixin,djgou,nyaa,xinjuc,aikanzy,qupanshe,xdpan,discourse,yunsou,qqpd,ahhhhfs,nsgame,gying,quark4k,quarksoo,sousou,ash" "$file"
}

[ "$(id -u)" = "0" ] || fatal "please install as root"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf|arm*) ;; *) fatal "unsupported architecture, ARMv7/armhf required" ;; esac
has_cmd systemctl || fatal "systemd is required"

mkdir -p "$APP_DIR" "$DATA_DIR" "$BIN_DIR" "$ASSET_DIR" "$CONFIG_DIR" "$DATA_DIR/cache" "$DATA_DIR/logs"
: >"$LOG_FILE" 2>/dev/null || true
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
pkill -f "$BIN_DIR/pansou" >/dev/null 2>&1 || true
ensure_config

log "download binary: $BIN_URL"
fetch "$BIN_URL" "$TMP_BIN" 2>&1 | tee -a "$LOG_FILE"
GOT="$(sha256_file "$TMP_BIN")"
log "SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch: want $BIN_SHA256 got $GOT"
mv -f "$TMP_BIN" "$BIN_DIR/pansou"
chmod 0755 "$BIN_DIR/pansou"

if fetch "$ICON_URL" "$ASSET_DIR/icon.png" >/dev/null 2>&1; then
  mkdir -p "$DATA_DIR/assets"
  cp "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  chmod 0644 "$ASSET_DIR/icon.png" "$DATA_DIR/assets/icon.png" 2>/dev/null || true
  log "icon installed"
else
  log "icon download failed, service install continues"
fi

cat >"$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu
APP_DIR="$APP_DIR"
DATA_DIR="$DATA_DIR"
cd "$DATA_DIR"
if [ -n "\${PANSOU_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  exec "$APP_DIR/bin/pansou" \${PANSOU_ARGS}
fi
exec "$APP_DIR/bin/pansou"
EOF
chmod 0755 "$APP_DIR/run.sh"

cat >"$SERVICE" <<EOF
[Unit]
Description=WanOS PanSou
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DATA_DIR
Environment=HOME=$DATA_DIR
Environment=PANSOU_PORT=$PORT
Environment=PANSOU_ADDRESS=$ADDR
Environment=CONFIG_DIR=$CONFIG_DIR
Environment=TZ=Asia/Shanghai
Environment=PORT=$PORT
Environment=GIN_MODE=release
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat >"$APP_DIR/README-WanOS.txt" <<EOF
PanSou installed.
URL: http://device-ip:$PORT
Service: $APP_ID
Data: $DATA_DIR
EOF

systemctl daemon-reload
systemctl enable "$APP_ID" >/dev/null 2>&1 || true
systemctl restart "$APP_ID"
sleep 4
if ! systemctl is-active "$APP_ID" >/dev/null 2>&1; then
  systemctl status "$APP_ID" --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  journalctl -u "$APP_ID" -n 120 --no-pager -l 2>&1 | tee -a "$LOG_FILE" || true
  fatal "service start failed, check: journalctl -u $APP_ID -n 120 --no-pager"
fi
log "install done: http://device-ip:$PORT"
