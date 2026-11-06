#!/bin/sh
set -eu
APP_ID="minecraft-java"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PANEL_PORT="${MC_PANEL_PORT:-25566}"
SERVER_PORT="${MC_SERVER_PORT:-25565}"
SERVER_URL="${MC_SERVER_URL:-https://launcher.mojang.com/mc/game/1.12.2/server/886945bfb2b978778c3a0288fd7fab09d315b25f/server.jar}"
SERVER_SHA1="${MC_SERVER_SHA1:-886945bfb2b978778c3a0288fd7fab09d315b25f}"
TMP_DIR="${DATA_DIR:-$APP_DIR}/.tmp-install"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="/var/log/wanos-minecraft-java-install.log"
log(){ printf '%s\n' "[Minecraft] $*"; }
fatal(){ printf '%s\n' "[Minecraft] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3 用于 Web 面板。"
if ! has_cmd java; then
  if has_cmd apt-get; then apt-get update 2>&1 | tee -a "$LOG_FILE" || true; DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jre-headless openjdk-11-jre-headless 2>&1 | tee -a "$LOG_FILE" || fatal "Java 安装失败"; else fatal "系统没有 java，也没有 apt-get。"; fi
fi
if ! has_cmd curl && ! has_cmd wget; then fatal "本应用需要 curl 或 wget 下载官方 server.jar。"; fi
mkdir -p "$APP_DIR/panel" "$DATA_DIR" "$TMP_DIR"
: >"$LOG_FILE" 2>/dev/null || true
JAR="$APP_DIR/server-1.12.2.jar"
if [ ! -f "$JAR" ]; then if has_cmd curl; then curl -fL --connect-timeout 20 --retry 2 -o "$JAR" "$SERVER_URL" 2>&1 | tee -a "$LOG_FILE"; else wget -O "$JAR" "$SERVER_URL" 2>&1 | tee -a "$LOG_FILE"; fi; fi
if has_cmd sha1sum; then got="$(sha1sum "$JAR" | awk '{print $1}')"; [ "$got" = "$SERVER_SHA1" ] || fatal "server.jar 校验失败：want $SERVER_SHA1 got $got"; fi
cat >"$APP_DIR/panel/minecraft-panel.py" <<'PYEOF'
#!/usr/bin/env python3
import html, os, subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs
APP_DIR=os.environ.get("MC_APP_DIR","/opt/wanos/apps/minecraft-java")
DATA_DIR=os.environ.get("MC_DATA_DIR","/opt/wanos-data/apps/minecraft-java")
PANEL_PORT=int(os.environ.get("MC_PANEL_PORT","25566")); SERVER_PORT=int(os.environ.get("MC_SERVER_PORT","25565"))
PROPS=os.path.join(DATA_DIR,"server.properties"); EULA=os.path.join(DATA_DIR,"eula.txt")
def run(a,t=10):
    try:
        p=subprocess.run(a,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=t); return p.returncode,(p.stdout or '').strip()
    except Exception as e: return 1,str(e)
def rf(p,d=''):
    try:
        return open(p,'r',encoding='utf-8',errors='replace').read()
    except Exception: return d
def wf(p,x): os.makedirs(os.path.dirname(p),exist_ok=True); open(p,'w',encoding='utf-8').write(x.rstrip()+"\n")
def props_default(): return f"server-port={SERVER_PORT}\nmax-players=5\nonline-mode=true\nmotd=WanOS Minecraft Server\nview-distance=6\nspawn-protection=0\n"
def stat():
    ac,a=run(['systemctl','is-active','minecraft-java'],4); ec,e=run(['systemctl','is-enabled','minecraft-java'],4); jc,j=run(['journalctl','-u','minecraft-java','-n','80','--no-pager'],8); return {'active':a if ac==0 else 'inactive','enabled':e if ec==0 else 'unknown','journal':j}
def page(msg=''):
    s=stat(); p=rf(PROPS,props_default()); ok='eula=true' in rf(EULA,'').lower(); cls='ok' if s['active']=='active' else 'bad'; msg_html=f"<div class='msg'>{html.escape(msg)}</div>" if msg else ''
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Minecraft 服务端</title><style>body{{margin:0;background:#f5f7fb;color:#172033;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Microsoft YaHei',Arial,sans-serif}}.wrap{{max-width:1040px;margin:0 auto;padding:26px 16px 40px}}.head{{display:flex;align-items:center;gap:14px;margin-bottom:18px}}.logo{{width:54px;height:54px;border-radius:14px;object-fit:cover}}h1{{font-size:24px;margin:0}}.sub{{font-size:14px;color:#667085;margin-top:4px}}.panel{{background:#fff;border:1px solid #e5e7ef;border-radius:8px;box-shadow:0 10px 26px rgba(15,23,42,.06);padding:18px;margin-bottom:14px}}.pill{{display:inline-block;padding:7px 10px;border-radius:999px;background:#eef2ff;color:#344054;font-size:13px;margin:0 8px 12px 0}}.ok{{background:#e8f7ee;color:#067647}}.bad{{background:#fff1f3;color:#b42318}}textarea{{width:100%;min-height:260px;border:1px solid #d8e0e8;border-radius:8px;padding:12px;font:13px/1.5 Consolas,Menlo,monospace;resize:vertical}}.actions{{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px}}button{{border:0;border-radius:6px;background:#2f7d32;color:#fff;padding:10px 14px;font-size:14px;cursor:pointer}}button.dark{{background:#344054}}button.light{{background:#eef2f7;color:#172033}}.msg{{background:#fff7ed;color:#9a3412;border-radius:6px;padding:10px 12px;margin-bottom:12px}}pre{{white-space:pre-wrap;word-break:break-all;background:#111827;color:#d1d5db;border-radius:8px;padding:12px;max-height:360px;overflow:auto;font-size:12px}}.warn{{color:#b42318;font-weight:700}}</style></head><body><div class="wrap"><div class="head"><img class="logo" src="/icon.png"><div><h1>Minecraft Java 服务端</h1><div class="sub">官方 1.12.2 轻量服务端，适合 ARMv7 低内存设备小人数游玩</div></div></div><div class="panel">{msg_html}<span class="pill {cls}">服务：{html.escape(s['active'])}</span><span class="pill">开机：{html.escape(s['enabled'])}</span><span class="pill">游戏端口：{SERVER_PORT}</span><p>连接地址：<b>设备IP:{SERVER_PORT}</b></p><p class="{'ok' if ok else 'warn'}">EULA：{'已同意' if ok else '未同意，需要勾选后才能启动'}</p></div><form class="panel" method="post" action="/save"><label><input type="checkbox" name="eula" value="true" {'checked' if ok else ''}> 我确认已阅读并同意 Minecraft EULA</label><p><b>server.properties</b></p><textarea name="props">{html.escape(p)}</textarea><div class="actions"><button type="submit">保存配置</button><button class="dark" formaction="/action/restart">重启</button><button class="light" formaction="/action/start">启动</button><button class="light" formaction="/action/stop">停止</button></div></form><div class="panel"><b>最近日志</b><pre>{html.escape(s['journal'])}</pre></div></div></body></html>'''
class H(BaseHTTPRequestHandler):
    def send(self,x,ct='text/html; charset=utf-8'):
        b=x if isinstance(x,bytes) else x.encode('utf-8'); self.send_response(200); self.send_header('Content-Type',ct); self.send_header('Content-Length',str(len(b))); self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path=='/icon.png':
            try: self.send(open(os.path.join(APP_DIR,'panel','icon.png'),'rb').read(),'image/png')
            except Exception: self.send_error(404)
            return
        self.send(page())
    def do_POST(self):
        l=int(self.headers.get('Content-Length','0') or '0'); f=parse_qs(self.rfile.read(l).decode('utf-8','replace'))
        if self.path=='/save': wf(PROPS,(f.get('props') or [props_default()])[0]); wf(EULA,'eula=true' if (f.get('eula') or [''])[0]=='true' else 'eula=false'); self.send(page('配置已保存。')); return
        a=self.path.rsplit('/',1)[-1]
        if a in ('start','stop','restart'): run(['systemctl',a,'minecraft-java'],15); self.send(page('已执行：'+a)); return
        self.send_error(404)
    def log_message(self,*a): return
if __name__=='__main__': ThreadingHTTPServer(('0.0.0.0',PANEL_PORT),H).serve_forever()

PYEOF
chmod +x "$APP_DIR/panel/minecraft-panel.py"
if has_cmd curl; then curl -fsSL -o "$APP_DIR/panel/icon.png" "https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/minecraft-java.png" || true; else wget -q -O "$APP_DIR/panel/icon.png" "https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/minecraft-java.png" || true; fi
if [ ! -f "$DATA_DIR/server.properties" ]; then cat >"$DATA_DIR/server.properties" <<EOF
server-port=$SERVER_PORT
max-players=5
online-mode=true
motd=WanOS Minecraft Server
view-distance=6
spawn-protection=0
EOF
fi
if [ ! -f "$DATA_DIR/eula.txt" ]; then echo "eula=false" >"$DATA_DIR/eula.txt"; fi
cat >"/etc/systemd/system/minecraft-java.service" <<EOF
[Unit]
Description=WanOS Minecraft Java Server 1.12.2
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
WorkingDirectory=$DATA_DIR
ExecStart=/usr/bin/java -Xms128M -Xmx512M -jar $JAR nogui
Restart=on-failure
RestartSec=8
[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/minecraft-java-panel.service" <<EOF
[Unit]
Description=WanOS Minecraft Java Panel
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Environment=MC_APP_DIR=$APP_DIR
Environment=MC_DATA_DIR=$DATA_DIR
Environment=MC_PANEL_PORT=$PANEL_PORT
Environment=MC_SERVER_PORT=$SERVER_PORT
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/panel/minecraft-panel.py
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable minecraft-java.service >/dev/null 2>&1 || true
systemctl enable --now minecraft-java-panel.service
rm -rf "$TMP_DIR"
log "安装完成。面板：http://设备IP:$PANEL_PORT；游戏端口：$SERVER_PORT。先在面板勾选 EULA 后再启动。"
