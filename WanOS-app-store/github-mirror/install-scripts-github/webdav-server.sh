#!/bin/sh
set -eu
APP_ID="webdav-server"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
DAV_PORT="${WEBDAV_PORT:-21220}"
PANEL_PORT="${WEBDAV_PANEL_PORT:-21221}"
DAV_USER="${WEBDAV_USER:-wanos}"
DAV_PASS="${WANOS_APP_ADMIN_PASSWORD:-${WEBDAV_DEFAULT_PASSWORD:-wanos}}"
LOG_FILE="/var/log/wanos-webdav-server-install.log"
log(){ printf '%s
' "[WebDAV] $*"; }
fatal(){ printf '%s
' "[WebDAV] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3。"
mkdir -p "$APP_DIR" "$DATA_DIR/files"
: >"$LOG_FILE" 2>/dev/null || true
cat >"$APP_DIR/webdav-server.py" <<'PY'
#!/usr/bin/env python3
import base64, email.utils, html, os, posixpath, shutil, subprocess, time, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from xml.sax.saxutils import escape

PORT=int(os.environ.get('WEBDAV_PORT','21220'))
USER=os.environ.get('WEBDAV_USER','wanos')
PASS_FILE=os.environ.get('WEBDAV_PASS_FILE','/opt/wanos-data/apps/webdav-server/password')
ROOT=os.environ.get('WEBDAV_ROOT','/opt/wanos-data/apps/webdav-server/files')
REAL_ROOT=os.path.abspath(ROOT)

def get_password():
    try:
        return open(PASS_FILE,'r',encoding='utf-8').read().strip()
    except Exception:
        return 'wanos'

def safe_path(url_path):
    path=urllib.parse.unquote(url_path.split('?',1)[0])
    path=posixpath.normpath(path)
    if path.startswith('../') or path == '..':
        raise ValueError('bad path')
    if path == '/': rel=''
    else: rel=path.lstrip('/')
    target=os.path.abspath(os.path.join(REAL_ROOT, rel))
    if target != REAL_ROOT and not target.startswith(REAL_ROOT + os.sep):
        raise ValueError('bad path')
    return target

def http_date(ts):
    return email.utils.formatdate(ts, usegmt=True)

def href_for(path):
    quoted='/'.join(urllib.parse.quote(x) for x in path.strip('/').split('/') if x)
    return '/' + quoted + ('/' if path.endswith('/') and quoted else '')

class WebDAVHandler(BaseHTTPRequestHandler):
    server_version='WanOSWebDAV/1.0'
    def log_message(self, fmt, *args):
        return
    def unauthorized(self):
        self.send_response(401)
        self.send_header('WWW-Authenticate','Basic realm="WanOS WebDAV"')
        self.end_headers()
    def check_auth(self):
        header=self.headers.get('Authorization','')
        if not header.startswith('Basic '):
            self.unauthorized(); return False
        try:
            raw=base64.b64decode(header.split(' ',1)[1]).decode('utf-8')
        except Exception:
            self.unauthorized(); return False
        user,_,pwd=raw.partition(':')
        if user != USER or pwd != get_password():
            self.unauthorized(); return False
        return True
    def send_empty(self, code):
        self.send_response(code)
        self.send_header('Content-Length','0')
        self.end_headers()
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('DAV','1,2')
        self.send_header('Allow','OPTIONS, PROPFIND, GET, HEAD, PUT, DELETE, MKCOL, MOVE, COPY')
        self.send_header('MS-Author-Via','DAV')
        self.send_header('Content-Length','0')
        self.end_headers()
    def do_HEAD(self):
        if not self.check_auth(): return
        self.serve_file(head=True)
    def do_GET(self):
        if not self.check_auth(): return
        self.serve_file(head=False)
    def serve_file(self, head=False):
        try: target=safe_path(self.path)
        except Exception: self.send_error(400); return
        if os.path.isdir(target):
            items=[]
            base=urllib.parse.unquote(self.path.split('?',1)[0]).rstrip('/')
            for name in sorted(os.listdir(target)):
                href=(base+'/'+urllib.parse.quote(name)).replace('//','/')
                if os.path.isdir(os.path.join(target,name)): href+='/'
                items.append(f'<li><a href="{html.escape(href)}">{html.escape(name)}</a></li>')
            body=("<!doctype html><meta charset='utf-8'><title>WebDAV</title><h1>WanOS WebDAV</h1><ul>"+''.join(items)+"</ul>").encode('utf-8')
            self.send_response(200); self.send_header('Content-Type','text/html; charset=utf-8'); self.send_header('Content-Length',str(len(body))); self.end_headers()
            if not head: self.wfile.write(body)
            return
        if not os.path.isfile(target): self.send_error(404); return
        st=os.stat(target)
        self.send_response(200)
        self.send_header('Content-Type','application/octet-stream')
        self.send_header('Content-Length',str(st.st_size))
        self.send_header('Last-Modified',http_date(st.st_mtime))
        self.end_headers()
        if not head:
            with open(target,'rb') as f: shutil.copyfileobj(f,self.wfile)
    def prop_xml(self, fs_path, req_path):
        st=os.stat(fs_path)
        is_dir=os.path.isdir(fs_path)
        href=href_for(req_path.rstrip('/') + ('/' if is_dir else ''))
        display=os.path.basename(fs_path.rstrip(os.sep)) or 'files'
        res_type='<D:collection/>' if is_dir else ''
        length='' if is_dir else f'<D:getcontentlength>{st.st_size}</D:getcontentlength>'
        return f'''<D:response><D:href>{escape(href)}</D:href><D:propstat><D:prop><D:displayname>{escape(display)}</D:displayname><D:resourcetype>{res_type}</D:resourcetype>{length}<D:getlastmodified>{http_date(st.st_mtime)}</D:getlastmodified></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>'''
    def do_PROPFIND(self):
        if not self.check_auth(): return
        try: target=safe_path(self.path)
        except Exception: self.send_error(400); return
        if not os.path.exists(target): self.send_error(404); return
        req_path=urllib.parse.unquote(self.path.split('?',1)[0])
        depth=self.headers.get('Depth','1')
        responses=[self.prop_xml(target, req_path)]
        if os.path.isdir(target) and depth != '0':
            base=req_path.rstrip('/')
            for name in sorted(os.listdir(target)):
                p=os.path.join(target,name)
                responses.append(self.prop_xml(p, base+'/'+name))
        body=('<?xml version="1.0" encoding="utf-8"?><D:multistatus xmlns:D="DAV:">'+''.join(responses)+'</D:multistatus>').encode('utf-8')
        self.send_response(207); self.send_header('Content-Type','application/xml; charset=utf-8'); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_PUT(self):
        if not self.check_auth(): return
        try: target=safe_path(self.path)
        except Exception: self.send_error(400); return
        os.makedirs(os.path.dirname(target), exist_ok=True)
        existed=os.path.exists(target)
        length=int(self.headers.get('Content-Length','0') or '0')
        with open(target,'wb') as f:
            remaining=length
            while remaining>0:
                chunk=self.rfile.read(min(1024*1024,remaining))
                if not chunk: break
                f.write(chunk); remaining-=len(chunk)
        self.send_empty(204 if existed else 201)
    def do_MKCOL(self):
        if not self.check_auth(): return
        try: target=safe_path(self.path)
        except Exception: self.send_error(400); return
        if os.path.exists(target): self.send_error(405); return
        os.makedirs(target, exist_ok=True); self.send_empty(201)
    def do_DELETE(self):
        if not self.check_auth(): return
        try: target=safe_path(self.path)
        except Exception: self.send_error(400); return
        if not os.path.exists(target): self.send_error(404); return
        if os.path.isdir(target): shutil.rmtree(target)
        else: os.remove(target)
        self.send_empty(204)
    def copy_move(self, move=False):
        if not self.check_auth(): return
        dest=self.headers.get('Destination','')
        if not dest: self.send_error(400); return
        dest_path=urllib.parse.urlparse(dest).path
        try: src=safe_path(self.path); dst=safe_path(dest_path)
        except Exception: self.send_error(400); return
        if not os.path.exists(src): self.send_error(404); return
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):
            if os.path.isdir(dst): shutil.rmtree(dst)
            else: os.remove(dst)
        if move: shutil.move(src,dst)
        elif os.path.isdir(src): shutil.copytree(src,dst)
        else: shutil.copy2(src,dst)
        self.send_empty(201)
    def do_MOVE(self): self.copy_move(True)
    def do_COPY(self): self.copy_move(False)

if __name__ == '__main__':
    os.makedirs(REAL_ROOT, exist_ok=True)
    os.makedirs(os.path.dirname(PASS_FILE), exist_ok=True)
    if not os.path.exists(PASS_FILE):
        open(PASS_FILE,'w',encoding='utf-8').write('wanos\n')
    ThreadingHTTPServer(('0.0.0.0',PORT), WebDAVHandler).serve_forever()

PY
cat >"$APP_DIR/webdav-panel.py" <<'PY'
#!/usr/bin/env python3
import html, os, socket, subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs
PORT=int(os.environ.get('WEBDAV_PANEL_PORT','21221'))
DAV_PORT=os.environ.get('WEBDAV_PORT','21220')
USER=os.environ.get('WEBDAV_USER','wanos')
DATA_DIR=os.environ.get('WEBDAV_DATA_DIR','/opt/wanos-data/apps/webdav-server')
ROOT=os.path.join(DATA_DIR,'files')
PASS_FILE=os.path.join(DATA_DIR,'password')

def run(cmd,timeout=12):
    try:
        p=subprocess.run(cmd,text=True,capture_output=True,timeout=timeout)
        return p.returncode,(p.stdout or '')+(p.stderr or '')
    except Exception as e:
        return 1,str(e)
def svc(name):
    _,a=run(['systemctl','is-active',name],5); _,e=run(['systemctl','is-enabled',name],5)
    return (a.strip() or 'unknown'),(e.strip() or 'unknown')
def port_open(port):
    s=socket.socket(); s.settimeout(.5)
    try: return s.connect_ex(('127.0.0.1',int(port)))==0
    finally: s.close()
def page(msg=''):
    active,enabled=svc('webdav-server')
    rows=[('WebDAV 服务',active),('开机启动',enabled),('WebDAV 端口',DAV_PORT),('端口状态','监听中' if port_open(DAV_PORT) else '未监听'),('账号',USER),('文件目录',ROOT),('连接地址','http://设备IP:'+DAV_PORT+'/')]
    tr=''.join(f'<tr><td>{html.escape(k)}</td><td>{html.escape(str(v))}</td></tr>' for k,v in rows)
    msg_html=f'<div class="msg">{html.escape(msg)}</div>' if msg else ''
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WebDAV 服务</title><style>body{{margin:0;background:#f5f7fb;color:#172033;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}.wrap{{max-width:820px;margin:0 auto;padding:22px}}h1{{font-size:22px;margin:0 0 8px}}.sub{{color:#667085;margin-bottom:18px}}.card{{background:#fff;border:1px solid #e4e7ec;border-radius:8px;padding:16px;margin:12px 0;box-shadow:0 1px 2px rgba(16,24,40,.04)}}table{{width:100%;border-collapse:collapse}}td{{padding:10px;border-bottom:1px solid #eef1f5}}td:first-child{{width:150px;color:#667085}}button{{height:36px;padding:0 14px;border:0;border-radius:6px;background:#1f6feb;color:#fff;cursor:pointer;margin:4px 6px 4px 0}}button.secondary{{background:#667085}}input{{height:36px;border:1px solid #d0d5dd;border-radius:6px;padding:0 10px;min-width:240px}}.msg{{background:#ecfdf3;border:1px solid #abefc6;color:#067647;border-radius:6px;padding:10px;margin:12px 0}}.warn{{background:#fffaeb;border:1px solid #fedf89;color:#93370d;border-radius:6px;padding:10px;margin-top:10px}}code{{background:#eef1f5;border-radius:4px;padding:2px 5px}}</style></head><body><div class="wrap"><h1>WebDAV 服务</h1><div class="sub">用于电脑、手机文件管理器挂载 WanOS 目录。默认账号 <code>{html.escape(USER)}</code>，默认密码 <code>wanos</code>。</div>{msg_html}<div class="card"><table>{tr}</table></div><div class="card"><form method="post"><button name="action" value="start">启动</button><button name="action" value="restart">重启</button><button class="secondary" name="action" value="stop">停止</button></form></div><div class="card"><h2 style="font-size:16px;margin:0 0 12px">修改 WebDAV 密码</h2><form method="post"><input name="password" type="password" autocomplete="new-password" placeholder="输入新密码，至少 6 位"><button name="action" value="password">保存密码</button></form><div class="warn">Windows 可用“映射网络驱动器”连接；macOS 可用 Finder 连接服务器；推荐局域网使用，外网使用请配合 HTTPS 或远程访问。</div></div></div></body></html>'''
class Handler(BaseHTTPRequestHandler):
    def log_message(self,fmt,*args): return
    def send_html(self,body):
        data=body.encode('utf-8'); self.send_response(200); self.send_header('Content-Type','text/html; charset=utf-8'); self.send_header('Cache-Control','no-store'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
    def do_GET(self): self.send_html(page())
    def do_POST(self):
        length=int(self.headers.get('Content-Length','0') or '0'); data=parse_qs(self.rfile.read(length).decode('utf-8','ignore')); action=(data.get('action') or [''])[0]; msg=''
        if action in ('start','stop','restart'):
            c,o=run(['systemctl',action,'webdav-server'],20); msg='操作完成' if c==0 else '操作失败：'+o[-500:]
        elif action=='password':
            pwd=(data.get('password') or [''])[0]
            if len(pwd)<6: msg='密码至少 6 位。'
            else:
                os.makedirs(DATA_DIR,exist_ok=True); open(PASS_FILE,'w',encoding='utf-8').write(pwd+'\n'); run(['systemctl','restart','webdav-server'],20); msg='WebDAV 密码已更新。'
        self.send_html(page(msg))
if __name__=='__main__':
    os.makedirs(ROOT,exist_ok=True); ThreadingHTTPServer(('0.0.0.0',PORT),Handler).serve_forever()

PY
chmod +x "$APP_DIR/webdav-server.py" "$APP_DIR/webdav-panel.py"
[ -f "$DATA_DIR/password" ] || printf '%s
' "$DAV_PASS" >"$DATA_DIR/password"
chmod 600 "$DATA_DIR/password" 2>/dev/null || true
cat >"/etc/systemd/system/webdav-server.service" <<EOF
[Unit]
Description=WanOS WebDAV Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=WEBDAV_PORT=$DAV_PORT
Environment=WEBDAV_USER=$DAV_USER
Environment=WEBDAV_PASS_FILE=$DATA_DIR/password
Environment=WEBDAV_ROOT=$DATA_DIR/files
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/webdav-server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/webdav-server-panel.service" <<EOF
[Unit]
Description=WanOS WebDAV Server Panel
After=webdav-server.service network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=WEBDAV_PANEL_PORT=$PANEL_PORT
Environment=WEBDAV_PORT=$DAV_PORT
Environment=WEBDAV_USER=$DAV_USER
Environment=WEBDAV_DATA_DIR=$DATA_DIR
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/webdav-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
timeout 20 systemctl enable --now webdav-server.service 2>&1 | tee -a "$LOG_FILE" || { journalctl -u webdav-server -n 80 --no-pager 2>/dev/null | tee -a "$LOG_FILE" || true; fatal "WebDAV 服务启动失败，可能是 $DAV_PORT 端口被占用或脚本异常"; }
timeout 20 systemctl enable --now webdav-server-panel.service 2>&1 | tee -a "$LOG_FILE" || { journalctl -u webdav-server-panel -n 80 --no-pager 2>/dev/null | tee -a "$LOG_FILE" || true; fatal "WebDAV 面板启动失败，可能是 $PANEL_PORT 端口被占用或脚本异常"; }
log "安装完成。面板：http://设备IP:$PANEL_PORT；WebDAV：http://设备IP:$DAV_PORT/；默认账号：$DAV_USER 默认密码：$DAV_PASS"
