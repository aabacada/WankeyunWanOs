#!/bin/sh
set -eu
APP_ID="chromium-headless"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PANEL_PORT="${CHROMIUM_PANEL_PORT:-9223}"
DEBUG_PORT="${CHROMIUM_DEBUG_PORT:-9222}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-update"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-chromium-headless-update.log"
PKG1_NAME="chromium_90.0.4430.212-1~deb10u1_armhf.deb"
PKG1_SHA256="eef2f574e7fcd02bb5b01ee00fdf9c9c574b4b2a79a2de6de5d96fa1170bc7d6"
PKG1_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/chromium-headless/chromium_90.0.4430.212-1~deb10u1_armhf.deb"
PKG2_NAME="chromium-common_90.0.4430.212-1~deb10u1_armhf.deb"
PKG2_SHA256="e758babcb6ca0155a73cf732a56f1af0d8af1ceec864121420fbc0d0be3c4dbf"
PKG2_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/chromium-headless/chromium-common_90.0.4430.212-1~deb10u1_armhf.deb"
PKG3_NAME="chromium-sandbox_90.0.4430.212-1~deb10u1_armhf.deb"
PKG3_SHA256="cced3cf25598430164722f71aecdacca58bb83c139a075338538b964221e5746"
PKG3_URL="https://wxqun988.vxjuejin.com/wanos/downloads/apps/chromium-headless/chromium-sandbox_90.0.4430.212-1~deb10u1_armhf.deb"
log(){ printf '%s\n' "[Chromium] $*"; }
fatal(){ printf '%s\n' "[Chromium] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please update as root"
case "$(uname -m 2>/dev/null || echo unknown)" in armv7l|armv7*|armhf) ;; *) fatal "本应用仅支持 ARMv7 / armv7l / armhf 架构。" ;; esac
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd dpkg || fatal "本应用需要 dpkg。"
has_cmd python3 || fatal "本应用需要 Python3 用于 Web 界面。"
if ! has_cmd curl && ! has_cmd wget; then fatal "本应用需要 curl 或 wget。"; fi
mkdir -p "$APP_DIR/panel" "$DATA_DIR/profile" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
download_one(){
  name="$1"; url="$2"; sha="$3"; dest="$TMP_DIR/$name"
  log "下载：$name"
  if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$dest" "$url" 2>&1 | tee -a "$LOG_FILE"; else wget -O "$dest" "$url" 2>&1 | tee -a "$LOG_FILE"; fi
  if has_cmd sha256sum; then got="$(sha256sum "$dest" | awk '{print $1}')"; [ "$got" = "$sha" ] || fatal "$name 校验失败：want $sha got $got"; fi
}
download_one "$PKG1_NAME" "$PKG1_URL" "$PKG1_SHA256"
download_one "$PKG2_NAME" "$PKG2_URL" "$PKG2_SHA256"
download_one "$PKG3_NAME" "$PKG3_URL" "$PKG3_SHA256"
log "安装 Chromium 90 ARMv7"
set +e
dpkg -i "$TMP_DIR/$PKG2_NAME" "$TMP_DIR/$PKG3_NAME" "$TMP_DIR/$PKG1_NAME" 2>&1 | tee -a "$LOG_FILE"
dpkg_status=$?
set -e
if [ "$dpkg_status" != "0" ]; then
  if has_cmd apt-get; then
    log "尝试用 apt-get 补齐系统依赖"
    apt-get update 2>&1 | tee -a "$LOG_FILE" || true
    DEBIAN_FRONTEND=noninteractive apt-get -f install -y 2>&1 | tee -a "$LOG_FILE" || fatal "依赖补齐失败，请查看 $LOG_FILE"
  else
    fatal "dpkg 安装失败且系统没有 apt-get，请查看 $LOG_FILE"
  fi
fi
cat >"$APP_DIR/panel/chromium-panel.py" <<'PYEOF'
#!/usr/bin/env python3
import html
import json
import os
import subprocess
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("CHROMIUM_PANEL_PORT", "9223"))
DEBUG_PORT = int(os.environ.get("CHROMIUM_DEBUG_PORT", "9222"))
APP_DIR = os.environ.get("CHROMIUM_APP_DIR", "/opt/wanos/apps/chromium-headless")
HOME_URL = os.environ.get("CHROMIUM_HOME_URL", "https://wanos.xyz")

def run(args, timeout=8):
    try:
        p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
        return p.returncode, (p.stdout or "").strip()
    except Exception as exc:
        return 1, str(exc)

def get_json(url):
    try:
        with urllib.request.urlopen(url, timeout=3) as res:
            return json.loads(res.read().decode("utf-8", "replace")), ""
    except Exception as exc:
        return None, str(exc)

def service_status():
    code, active = run(["systemctl", "is-active", "chromium-headless"], timeout=4)
    vcode, version = run(["/usr/bin/chromium", "--version"], timeout=6)
    info, err = get_json(f"http://127.0.0.1:{DEBUG_PORT}/json/version")
    return {
        "active": active if code == 0 else "inactive",
        "version": version if vcode == 0 else "未安装或不可执行",
        "debug_ok": isinstance(info, dict),
        "debug_info": info or {},
        "debug_error": err,
    }

def page():
    s = service_status()
    icon = "/icon.png"
    data = {
        "homeUrl": HOME_URL,
        "debugPort": DEBUG_PORT,
        "status": s,
    }
    return f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chromium</title>
<style>
:root{{color-scheme:light;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Microsoft YaHei',Arial,sans-serif;}}
*{{box-sizing:border-box}} body{{margin:0;height:100vh;background:#e8eaed;color:#202124;overflow:hidden}}
.browser{{height:100vh;display:grid;grid-template-rows:auto 1fr;background:#fff}}
.top{{background:#f1f3f4;border-bottom:1px solid #dadce0;box-shadow:0 1px 2px rgba(60,64,67,.08)}}
.tabbar{{height:36px;display:flex;align-items:end;padding:6px 10px 0;gap:8px;background:#dee1e6}}
.tab{{height:30px;min-width:180px;max-width:260px;background:#fff;border-radius:8px 8px 0 0;display:flex;align-items:center;gap:8px;padding:0 12px;font-size:13px;color:#3c4043;box-shadow:0 -1px 0 rgba(0,0,0,.02)}}
.tab img{{width:16px;height:16px}} .tab-title{{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
.toolbar{{height:50px;display:flex;align-items:center;gap:8px;padding:7px 12px}}
.iconbtn{{width:34px;height:34px;border:0;border-radius:50%;background:transparent;color:#5f6368;display:grid;place-items:center;cursor:pointer;font-size:18px}}
.iconbtn:hover{{background:#e8eaed}} .iconbtn:disabled{{opacity:.35;cursor:default}}
.addr{{height:36px;flex:1;display:flex;align-items:center;background:#fff;border:1px solid #dfe1e5;border-radius:18px;padding:0 12px;gap:8px;box-shadow:inset 0 0 0 1px transparent}}
.addr:focus-within{{background:#fff;border-color:#8ab4f8;box-shadow:0 0 0 1px #8ab4f8}}
.lock{{font-size:14px;color:#5f6368}} input{{border:0;outline:0;background:transparent;width:100%;font-size:14px;color:#202124}}
.openbtn{{height:34px;border:0;border-radius:17px;padding:0 14px;background:#1a73e8;color:#fff;font-size:13px;cursor:pointer}}
.more{{font-size:20px;color:#5f6368}}
.content{{position:relative;background:#fff;min-height:0}}
iframe{{width:100%;height:100%;border:0;background:#fff}}
.start{{position:absolute;inset:0;display:grid;place-items:center;background:#fff;z-index:2}}
.start-card{{width:min(560px,92vw);text-align:center;padding:20px}}
.logo{{width:82px;height:82px;border-radius:50%;margin:0 auto 18px;display:block}}
.search{{height:44px;border-radius:22px;border:1px solid #dfe1e5;display:flex;align-items:center;padding:0 16px;gap:10px;box-shadow:0 1px 6px rgba(32,33,36,.12)}}
.search input{{font-size:15px}} .hint{{margin-top:14px;font-size:13px;color:#5f6368;line-height:1.7}}
.status{{position:absolute;right:12px;bottom:12px;background:rgba(255,255,255,.96);border:1px solid #dadce0;border-radius:8px;padding:8px 10px;font-size:12px;color:#5f6368;box-shadow:0 6px 18px rgba(60,64,67,.16);z-index:3}}
.status.ok{{color:#137333}} .status.bad{{color:#b3261e}}
.blocked{{position:absolute;left:14px;bottom:14px;max-width:520px;background:#fff8e1;border:1px solid #f6c453;color:#5f4300;border-radius:8px;padding:10px 12px;font-size:13px;display:none;z-index:4;line-height:1.6}}
.blocked a{{color:#1a73e8}} .blocked .button{{display:inline-flex;margin-top:8px;background:#1a73e8;color:#fff;text-decoration:none;border-radius:6px;padding:9px 12px}}
@media(max-width:640px){{.tab{{min-width:120px}}.toolbar{{gap:4px;padding:7px 8px}}.iconbtn{{width:30px}}.openbtn{{padding:0 10px}}}}
</style></head><body>
<div class="browser"><div class="top"><div class="tabbar"><div class="tab"><img src="{icon}" alt=""><span class="tab-title" id="tabTitle">新标签页</span></div></div>
<div class="toolbar"><button class="iconbtn" id="back" title="后退">‹</button><button class="iconbtn" id="forward" title="前进">›</button><button class="iconbtn" id="reload" title="刷新">↻</button><button class="iconbtn" id="home" title="主页">⌂</button><form class="addr" id="navForm"><span class="lock">🔍</span><input id="urlInput" autocomplete="off" spellcheck="false" placeholder="搜索或输入网址"></form><button class="openbtn" id="goBtn">打开</button><button class="iconbtn more" id="external" title="新窗口打开">⋮</button></div></div>
<div class="content"><iframe id="view" referrerpolicy="no-referrer"></iframe><div class="start" id="start"><div class="start-card"><img class="logo" src="{icon}" alt=""><form class="search" id="startForm"><span>🔍</span><input id="startInput" placeholder="搜索或输入网址" autocomplete="off"></form><div class="hint">Chromium 90 ARMv7 无头服务在后台运行。部分网站禁止嵌入显示时，请点右上角新窗口打开。</div></div></div><div class="blocked" id="blocked">如果页面空白或拒绝显示，通常是网站禁止 iframe 嵌入。<a id="blockedOpen" href="#" target="_blank">点这里新窗口打开</a>。</div><div class="status" id="status"></div></div></div>
<script id="boot" type="application/json">{html.escape(json.dumps(data, ensure_ascii=False))}</script>
<script>
const boot = JSON.parse(document.getElementById('boot').textContent);
const view = document.getElementById('view');
const input = document.getElementById('urlInput');
const startInput = document.getElementById('startInput');
const start = document.getElementById('start');
const tabTitle = document.getElementById('tabTitle');
const statusEl = document.getElementById('status');
const blocked = document.getElementById('blocked');
const blockedOpen = document.getElementById('blockedOpen');
let historyStack = [];
let historyIndex = -1;
let currentUrl = '';
function normalize(text){{
  text = String(text || '').trim();
  if (!text) return '';
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(text)) return text;
  if (/^[\w.-]+\.[a-z]{2,}([/:?#].*)?$/i.test(text) || /^\d+\.\d+\.\d+\.\d+/.test(text)) return 'http://' + text;
  return 'https://www.baidu.com/s?wd=' + encodeURIComponent(text);
}}
function setStatus(){{
  const s = boot.status || {{}};
  if (s.active === 'active') {{ statusEl.textContent = s.debug_ok ? 'Chromium 服务运行中' : 'Chromium 启动中'; statusEl.className = 'status ok'; }}
  else {{ statusEl.textContent = 'Chromium 服务未运行'; statusEl.className = 'status bad'; }}
}}
function escapeHtml(text){{ return String(text).replace(/[&<>"']/g, ch => ({{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}}[ch])); }}
function load(url, push=true){{
  url = normalize(url); if(!url) return;
  currentUrl = url; input.value = url; startInput.value = url; tabTitle.textContent = url.replace(/^https?:\/\//,'').slice(0,42);
  start.style.display = 'none'; blocked.style.display = 'block'; blockedOpen.href = url;
  blocked.innerHTML = '<b>网页需要在新页面打开。</b><br>请点击下面按钮打开：<br><a class="button" href="'+escapeHtml(url)+'" target="_blank" rel="noreferrer">打开 '+escapeHtml(url)+'</a>';
  view.src = 'about:blank';
  if(push) {{ historyStack = historyStack.slice(0, historyIndex + 1); historyStack.push(url); historyIndex = historyStack.length - 1; }}
  updateButtons();
}}
function updateButtons(){{ document.getElementById('back').disabled = historyIndex <= 0; document.getElementById('forward').disabled = historyIndex >= historyStack.length - 1; }}
document.getElementById('navForm').onsubmit = e => {{ e.preventDefault(); load(input.value); }};
document.getElementById('startForm').onsubmit = e => {{ e.preventDefault(); load(startInput.value); }};
document.getElementById('goBtn').onclick = () => load(input.value);
document.getElementById('home').onclick = () => load(boot.homeUrl);
document.getElementById('reload').onclick = () => {{ if(currentUrl) view.src = currentUrl; }};
document.getElementById('back').onclick = () => {{ if(historyIndex > 0) {{ historyIndex--; load(historyStack[historyIndex], false); }} }};
document.getElementById('forward').onclick = () => {{ if(historyIndex < historyStack.length - 1) {{ historyIndex++; load(historyStack[historyIndex], false); }} }};
document.getElementById('external').onclick = () => {{ if(currentUrl) window.open(currentUrl, '_blank', 'noopener,noreferrer'); }};
view.onload = () => {{ blocked.style.display = 'none'; try {{ const title = view.contentDocument && view.contentDocument.title; if(title) tabTitle.textContent = title.slice(0,42); }} catch(e) {{}} }};
setStatus(); updateButtons(); input.value = ''; startInput.focus();
</script></body></html>"""

class Handler(BaseHTTPRequestHandler):
    def send_bytes(self, data, ctype):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        if self.path == "/icon.png":
            icon = os.path.join(APP_DIR, "panel", "icon.png")
            try:
                self.send_bytes(open(icon, "rb").read(), "image/png")
            except Exception:
                self.send_error(404)
            return
        if self.path.startswith("/api/status"):
            self.send_bytes(json.dumps(service_status(), ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
            return
        self.send_bytes(page().encode("utf-8"), "text/html; charset=utf-8")
    def do_POST(self):
        action = self.path.rsplit("/", 1)[-1]
        if action in ("start", "stop", "restart"):
            run(["systemctl", action, "chromium-headless"], timeout=15)
            self.send_response(303)
            self.send_header("Location", "/")
            self.end_headers()
            return
        self.send_error(404)
    def log_message(self, fmt, *args):
        return
if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()

PYEOF
if has_cmd curl; then curl -fsSL -o "$APP_DIR/panel/icon.png" "https://wanos.xyz/downloads/apps/chromium-headless/chromium.png" || true; else wget -q -O "$APP_DIR/panel/icon.png" "https://wanos.xyz/downloads/apps/chromium-headless/chromium.png" || true; fi
cat >"/etc/systemd/system/chromium-headless.service" <<EOF
[Unit]
Description=Chromium Headless Browser
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=HOME=$DATA_DIR
ExecStart=/usr/bin/chromium --headless --no-sandbox --disable-gpu --disable-dev-shm-usage --disable-software-rasterizer --disable-background-networking --disable-sync --disable-extensions --disable-component-update --no-first-run --no-default-browser-check --renderer-process-limit=1 --remote-debugging-address=0.0.0.0 --remote-debugging-port=$DEBUG_PORT --user-data-dir=$DATA_DIR/profile about:blank
Restart=always
RestartSec=5
MemoryMax=650M

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/chromium-headless-panel.service" <<EOF
[Unit]
Description=WanOS Chromium Browser UI
After=chromium-headless.service network-online.target
Wants=chromium-headless.service network-online.target

[Service]
Type=simple
Environment=CHROMIUM_PANEL_PORT=$PANEL_PORT
Environment=CHROMIUM_DEBUG_PORT=$DEBUG_PORT
Environment=CHROMIUM_APP_DIR=$APP_DIR
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/panel/chromium-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable chromium-headless.service >/dev/null 2>&1 || true
systemctl enable chromium-headless-panel.service >/dev/null 2>&1 || true
systemctl restart chromium-headless.service
systemctl restart chromium-headless-panel.service
rm -rf "$TMP_DIR"
log "更新完成。打开浏览器界面：http://设备IP:$PANEL_PORT"
