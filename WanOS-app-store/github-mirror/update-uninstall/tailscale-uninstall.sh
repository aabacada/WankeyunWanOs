#!/bin/sh
set -eu
APP_ID="tailscale"
APP_DIR="/opt/wanos/apps/$APP_ID"
TS_BIN="$APP_DIR/bin/tailscale"
TSD_BIN="$APP_DIR/bin/tailscaled"
LOG_FILE="/var/log/wanos-tailscale-uninstall.log"
log(){ printf "%s %s\n" "$(date '+%F %T')" "[Tailscale] $*" | tee -a "$LOG_FILE"; }
run(){ "$@" >>"$LOG_FILE" 2>&1 || true; }

: >"$LOG_FILE" 2>/dev/null || true
DEFAULT_ROUTE="$(ip route show default 2>/dev/null | grep -v " dev tailscale" | grep -v "tailscale0" | head -n 1 || true)"
log "开始卸载 Tailscale。"

if [ -x "$TS_BIN" ]; then
  log "执行 tailscale down。"
  run "$TS_BIN" down
elif command -v tailscale >/dev/null 2>&1; then
  log "执行 tailscale down。"
  run tailscale down
fi

run systemctl stop tailscale-panel
run systemctl disable tailscale-panel
run systemctl stop tailscaled
run systemctl disable tailscaled

if [ -x "$TSD_BIN" ]; then
  log "执行 tailscaled --cleanup。"
  run "$TSD_BIN" --cleanup
elif command -v tailscaled >/dev/null 2>&1; then
  log "执行 tailscaled --cleanup。"
  run tailscaled --cleanup
fi
run ip link delete tailscale0

if ! ip route show default 2>/dev/null | grep -q "^default "; then
  if [ -n "$DEFAULT_ROUTE" ]; then
    log "恢复默认路由：$DEFAULT_ROUTE"
    run sh -c "ip route add $DEFAULT_ROUTE"
  fi
fi

rm -f /etc/systemd/system/tailscale-panel.service /etc/systemd/system/tailscaled.service
run systemctl daemon-reload
rm -f /usr/local/bin/tailscale /usr/local/bin/tailscaled
rm -rf "$APP_DIR"

run systemctl restart nginx
run systemctl restart alist
run systemctl restart nas-media-player
log "Tailscale 已卸载，WanOS 面板服务已尝试恢复。"
echo "Tailscale 已卸载。若页面暂时打不开，请等待 10 秒后刷新或到路由器查看当前 IP。"
