#!/bin/sh
set -eu

APP_ID="tiantang"
APP_DIR="/opt/wanos/apps/$APP_ID"
DATA_DIR="/opt/wanos-data/apps/$APP_ID"
SERVICE="/etc/systemd/system/$APP_ID.service"

log() { printf '%s
' "[甜糖] $*"; }

remove_desktop_icon() {
  log "移除桌面入口。"
  if command -v node >/dev/null 2>&1; then
    node <<'NODE'
const fs = require("fs");
const paths = [
  process.env.MYBOX_DATA ? process.env.MYBOX_DATA + "/config.json" : "",
  "/opt/wanos-data/config.json",
  "/opt/mybox/data/config.json"
].filter(Boolean);
for (const file of paths) {
  try {
    if (!fs.existsSync(file)) continue;
    const cfg = JSON.parse(fs.readFileSync(file, "utf8") || "{}");
    if (!Array.isArray(cfg.apps)) continue;
    const next = cfg.apps.filter(app => app && app.id !== "tiantang");
    if (next.length !== cfg.apps.length) {
      cfg.apps = next;
      fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n");
    }
  } catch (err) {}
}
NODE
  fi
  if command -v systemctl >/dev/null 2>&1; then systemctl restart alist 2>/dev/null || systemctl restart mybox 2>/dev/null || true; fi
}
[ "$(id -u)" = "0" ] || { printf '%s
' "[甜糖] ERROR: 请使用 root 用户卸载。" >&2; exit 1; }

remove_desktop_icon
systemctl stop "$APP_ID" >/dev/null 2>&1 || true
systemctl disable "$APP_ID" >/dev/null 2>&1 || true
pkill -f 'ttmanager_arm32|ttnode|ttrun.sh' >/dev/null 2>&1 || true
if [ -x "$APP_DIR/ttmanager_arm32" ]; then
  "$APP_DIR/ttmanager_arm32" -uninstall >/dev/null 2>&1 || true
fi
rm -f "$SERVICE"
systemctl daemon-reload >/dev/null 2>&1 || true
rm -rf "$APP_DIR"
if [ "${TIANTANG_PURGE_DATA:-0}" = "1" ]; then
  rm -rf "$DATA_DIR"
  log "卸载完成，已清理缓存和数据。"
else
  log "卸载完成。缓存数据保留在 $DATA_DIR，如需彻底清理请执行：TIANTANG_PURGE_DATA=1 sh uninstall.sh"
fi
