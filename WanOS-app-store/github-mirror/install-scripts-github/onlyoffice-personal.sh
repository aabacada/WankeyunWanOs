#!/bin/sh
set -eu

APP_ID="onlyoffice-personal"
APP_NAME="OnlyOffice Personal"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-${WANOS_APP_DIR:-/opt/wanos/apps/$APP_ID}}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-${WANOS_APP_DATA:-/opt/wanos-data/apps/$APP_ID}}"
BIN_URL="${ONLYOFFICE_PERSONAL_BIN_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/onlyoffice-personal-linux-armv7-v1}"
BIN_SHA256="${ONLYOFFICE_PERSONAL_BIN_SHA256:-92bcc31377092004fa12c4fa41bb7b9fc4ff53c80abe7816d6f4ad646abf2241}"
ASSETS_URL="${ONLYOFFICE_PERSONAL_ASSETS_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/OnlyofficePersonal-main-local-icons.zip}"
ASSETS_SHA256="${ONLYOFFICE_PERSONAL_ASSETS_SHA256:-099e52de780a413016978c8b4b8eb28be1a997d1a178b5be0055e243efe4d20b}"
PACKAGE_URL="${PACKAGE_URL:-${WANOS_APP_PACKAGE_URL:-}}"
PACKAGE_SHA256="${PACKAGE_SHA256:-${WANOS_APP_PACKAGE_SHA256:-}}"
PORT="${ONLYOFFICE_PERSONAL_PORT:-42180}"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
download(){ if has_cmd curl; then curl -fL --connect-timeout 30 --retry 3 -o "$2" "$1"; elif has_cmd wget; then wget -O "$2" "$1"; else fatal "missing curl/wget"; fi; }
sha256_file(){ if has_cmd sha256sum; then sha256sum "$1" | awk '{print $1}'; elif has_cmd busybox; then busybox sha256sum "$1" | awk '{print $1}'; else fatal "missing sha256sum"; fi; }
patch_office_icons(){
  ROOT="$DATA_DIR/www/OnlyofficePersonal-main"
  HTML="$ROOT/office.html"
  CSS_DIR="$ROOT/assets"
  CSS="$CSS_DIR/wanos-local-icons.css"
  [ -f "$HTML" ] || return 0
  mkdir -p "$CSS_DIR"
  cat > "$CSS" <<'EOF'
.fas{display:inline-block;width:1.15em;min-width:1.15em;text-align:center;font-style:normal;font-family:Arial,"Microsoft YaHei",sans-serif;font-weight:700;line-height:1}
.fas:before{display:inline-block}
.fa-file-alt:before{content:"DOC"}
.fa-plus-circle:before{content:"+"}
.fa-file-word:before{content:"W";color:#2b579a}
.fa-file-excel:before{content:"X";color:#217346}
.fa-file-powerpoint:before{content:"P";color:#d24726}
.fa-file-pdf:before{content:"PDF";color:#c62828;font-size:.72em}
.fa-folder-open:before,.fa-folder:before{content:"DIR";color:#d99000;font-size:.72em}
.fa-upload:before,.fa-cloud-upload-alt:before{content:"UP";font-size:.78em}
.fa-link:before{content:"LK";font-size:.78em}
.fa-external-link-alt:before{content:"OPEN";font-size:.62em}
.fa-history:before{content:"H";font-size:.9em}
.fa-trash:before{content:"DEL";color:#d33;font-size:.68em}
EOF
  if grep -q "cdnjs.cloudflare.com/ajax/libs/font-awesome" "$HTML"; then
    sed 's#<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">#<link rel="stylesheet" href="./assets/wanos-local-icons.css">#' "$HTML" > "$HTML.tmp"
    mv -f "$HTML.tmp" "$HTML"
  elif ! grep -q "wanos-local-icons.css" "$HTML"; then
    sed 's#</head>#    <link rel="stylesheet" href="./assets/wanos-local-icons.css">\
</head>#' "$HTML" > "$HTML.tmp"
    mv -f "$HTML.tmp" "$HTML"
  fi
}

mkdir -p "$APP_DIR/bin" "$DATA_DIR/tmp" "$DATA_DIR/www"

BIN_TMP="$DATA_DIR/tmp/$APP_ID.bin.tmp"
log "download binary: $BIN_URL"
download "$BIN_URL" "$BIN_TMP"
GOT="$(sha256_file "$BIN_TMP")"
log "binary SHA256: $GOT"
[ "$GOT" = "$BIN_SHA256" ] || fatal "binary SHA256 mismatch"
mv -f "$BIN_TMP" "$APP_DIR/bin/$APP_ID"
chmod +x "$APP_DIR/bin/$APP_ID"

if [ ! -f "$DATA_DIR/www/OnlyofficePersonal-main/office.html" ] || [ "${ONLYOFFICE_PERSONAL_FORCE_ASSETS:-0}" = "1" ]; then
  AVAIL_KB="$(df -Pk "$DATA_DIR" | awk 'NR==2{print $4}')"
  [ "${AVAIL_KB:-0}" -gt 2300000 ] || fatal "not enough free space in $DATA_DIR, need about 2.3GB while installing assets"
  case "$PACKAGE_URL" in
    file://*) ZIP_TMP="${PACKAGE_URL#file://}"; log "use local offline package: $ZIP_TMP" ;;
    /*) ZIP_TMP="$PACKAGE_URL"; log "use local offline package: $ZIP_TMP" ;;
    "") fatal "assets are not installed. Please upload/select OnlyofficePersonal-main-local-icons.zip as offline package, then install again" ;;
    *) fatal "remote asset download is disabled. Please upload/select the offline package locally instead of using CDN" ;;
  esac
  [ -s "$ZIP_TMP" ] || fatal "offline package not found or empty: $ZIP_TMP"
  GOT="$(sha256_file "$ZIP_TMP")"
  log "offline package SHA256: $GOT"
  WANT_SHA="${PACKAGE_SHA256:-$ASSETS_SHA256}"
  [ -z "$WANT_SHA" ] || [ "$GOT" = "$WANT_SHA" ] || fatal "offline package SHA256 mismatch: want $WANT_SHA got $GOT"
  rm -rf "$DATA_DIR/www/OnlyofficePersonal-main"
  "$APP_DIR/bin/$APP_ID" --data "$DATA_DIR" --extract "$ZIP_TMP"
else
  log "assets already installed"
fi
patch_office_icons

cat > "$APP_DIR/run.sh" <<EOF
#!/bin/sh
exec "$APP_DIR/bin/$APP_ID" --addr "0.0.0.0:$PORT" --data "$DATA_DIR"
EOF
chmod +x "$APP_DIR/run.sh"

if has_cmd systemctl && [ -d /run/systemd/system ]; then
  cat > /etc/systemd/system/$APP_ID.service <<EOF
[Unit]
Description=WanOS OnlyOffice Personal
After=network-online.target

[Service]
Type=simple
ExecStart=$APP_DIR/run.sh
Restart=always
RestartSec=5
WorkingDirectory=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload || true
  systemctl enable --now "$APP_ID.service" || fatal "systemd start failed"
else
  log "systemd not detected, start with background process"
  pkill -f "$APP_DIR/bin/$APP_ID" 2>/dev/null || true
  nohup "$APP_DIR/run.sh" > "$DATA_DIR/app.log" 2>&1 &
fi

log "installed: http://device-ip:$PORT"
