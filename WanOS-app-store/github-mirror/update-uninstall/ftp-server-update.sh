#!/bin/sh
set -eu
APP_ID="ftp-server"
APP_NAME="FTP 服务"
if [ -n "${WANOS_APP_INSTALL_ROOT:-}" ]; then APP_DIR="$WANOS_APP_INSTALL_ROOT"; else APP_DIR="/opt/wanos/apps/$APP_ID"; fi
if [ -n "${WANOS_APP_DATA_ROOT:-}" ]; then DATA_DIR="$WANOS_APP_DATA_ROOT"; else DATA_DIR="/opt/wanos-data/apps/$APP_ID"; fi
PORT="${FTP_PANEL_PORT:-21210}"
FTP_USER="${FTP_USER:-wanosftp}"
FTP_PASS="${WANOS_APP_ADMIN_PASSWORD:-${FTP_DEFAULT_PASSWORD:-wanosftp}}"
FTP_PORT="${FTP_PORT:-21}"
PASV_MIN="${FTP_PASV_MIN_PORT:-21100}"
PASV_MAX="${FTP_PASV_MAX_PORT:-21110}"
FILES_DIR="$DATA_DIR/files"
LOG_FILE="/var/log/wanos-ftp-server-update.log"
log(){ printf '%s
' "[FTP] $*"; }
fatal(){ printf '%s
' "[FTP] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please update as root"
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3 用于本地 Web 面板。"
: >"$LOG_FILE" 2>/dev/null || true
if ! has_cmd vsftpd; then
  has_cmd apt-get || fatal "系统没有 vsftpd，也没有 apt-get，无法自动安装 FTP 服务。"
  log "安装 vsftpd"
  apt-get update 2>&1 | tee -a "$LOG_FILE" || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd 2>&1 | tee -a "$LOG_FILE" || fatal "vsftpd 安装失败"
fi
mkdir -p "$APP_DIR" "$DATA_DIR" "$FILES_DIR"
cat >"$APP_DIR/ftp-panel.py" <<'PY'
#!/usr/bin/env python3
import html, json, os, socket, subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

PORT = int(os.environ.get('FTP_PANEL_PORT', '21210'))
FTP_USER = os.environ.get('FTP_USER', 'wanosftp')
DATA_DIR = os.environ.get('FTP_DATA_DIR', '/opt/wanos-data/apps/ftp-server')
FILES_DIR = os.path.join(DATA_DIR, 'files')
VSFTPD_CONF = '/etc/vsftpd.conf'


def run(cmd, timeout=12):
    try:
        p = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
        return p.returncode, (p.stdout or '') + (p.stderr or '')
    except Exception as exc:
        return 1, str(exc)


def service_status(name):
    code, out = run(['systemctl', 'is-active', name], 5)
    active = out.strip() or ('active' if code == 0 else 'unknown')
    code2, out2 = run(['systemctl', 'is-enabled', name], 5)
    enabled = out2.strip() or 'unknown'
    return active, enabled


def port_open(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.5)
    try:
        return s.connect_ex(('127.0.0.1', port)) == 0
    finally:
        s.close()


def page(message=''):
    active, enabled = service_status('vsftpd')
    panel_active, panel_enabled = service_status('ftp-server-panel')
    port21 = '监听中' if port_open(21) else '未监听'
    msg = f'<div class="msg">{html.escape(message)}</div>' if message else ''
    rows = [
        ('FTP 服务', active), ('开机启动', enabled), ('21 端口', port21),
        ('面板服务', panel_active), ('FTP 用户', FTP_USER), ('文件目录', FILES_DIR),
        ('被动端口', '21100-21110')
    ]
    tr = ''.join(f'<tr><td>{html.escape(k)}</td><td>{html.escape(str(v))}</td></tr>' for k, v in rows)
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FTP 服务</title><style>
body{{margin:0;background:#f5f7fb;color:#172033;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}.wrap{{max-width:820px;margin:0 auto;padding:22px}}h1{{font-size:22px;margin:0 0 8px}}.sub{{color:#667085;margin-bottom:18px}}.card{{background:#fff;border:1px solid #e4e7ec;border-radius:8px;padding:16px;margin:12px 0;box-shadow:0 1px 2px rgba(16,24,40,.04)}}table{{width:100%;border-collapse:collapse}}td{{padding:10px;border-bottom:1px solid #eef1f5}}td:first-child{{width:150px;color:#667085}}button{{height:36px;padding:0 14px;border:0;border-radius:6px;background:#1f6feb;color:#fff;cursor:pointer;margin:4px 6px 4px 0}}button.secondary{{background:#667085}}button.danger{{background:#d92d20}}input{{height:36px;border:1px solid #d0d5dd;border-radius:6px;padding:0 10px;min-width:240px}}.msg{{background:#ecfdf3;border:1px solid #abefc6;color:#067647;border-radius:6px;padding:10px;margin:12px 0}}.warn{{background:#fffaeb;border:1px solid #fedf89;color:#93370d;border-radius:6px;padding:10px;margin-top:10px}}code{{background:#eef1f5;border-radius:4px;padding:2px 5px}}</style></head><body><div class="wrap"><h1>FTP 服务</h1><div class="sub">局域网 FTP 文件传输服务，默认账号 <code>{html.escape(FTP_USER)}</code>，目录 <code>{html.escape(FILES_DIR)}</code>。</div>{msg}<div class="card"><table>{tr}</table></div><div class="card"><form method="post"><button name="action" value="start">启动</button><button name="action" value="restart">重启</button><button class="secondary" name="action" value="stop">停止</button></form></div><div class="card"><h2 style="font-size:16px;margin:0 0 12px">修改 FTP 密码</h2><form method="post"><input name="password" type="password" autocomplete="new-password" placeholder="输入新密码，至少 6 位"><button name="action" value="password">保存密码</button></form><div class="warn">连接地址：<code>ftp://设备IP/</code>；外网访问 FTP 还需要路由器放行 21 和 21100-21110 端口。</div></div></div></body></html>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return
    def send_html(self, body):
        data = body.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        self.send_html(page())
    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0') or '0')
        data = parse_qs(self.rfile.read(length).decode('utf-8', 'ignore'))
        action = (data.get('action') or [''])[0]
        message = ''
        if action in ('start', 'stop', 'restart'):
            code, out = run(['systemctl', action, 'vsftpd'], 20)
            message = '操作完成' if code == 0 else '操作失败：' + out[-500:]
        elif action == 'password':
            pwd = (data.get('password') or [''])[0]
            if len(pwd) < 6:
                message = '密码至少 6 位。'
            else:
                code, out = run(['sh', '-c', 'printf "%s:%s\n" "$1" "$2" | chpasswd', 'sh', FTP_USER, pwd], 20)
                message = 'FTP 密码已更新。' if code == 0 else '修改失败：' + out[-500:]
        self.send_html(page(message))


if __name__ == '__main__':
    os.makedirs(FILES_DIR, exist_ok=True)
    ThreadingHTTPServer(('0.0.0.0', PORT), Handler).serve_forever()

PY
chmod +x "$APP_DIR/ftp-panel.py"
FTP_SHELL="/bin/sh"
[ -x /bin/bash ] && FTP_SHELL="/bin/bash"
if ! grep -qx "$FTP_SHELL" /etc/shells 2>/dev/null; then echo "$FTP_SHELL" >> /etc/shells 2>/dev/null || true; fi
if ! id "$FTP_USER" >/dev/null 2>&1; then
  useradd -M -d "$FILES_DIR" -s "$FTP_SHELL" "$FTP_USER"
else
  usermod -d "$FILES_DIR" -s "$FTP_SHELL" "$FTP_USER" 2>/dev/null || true
fi
printf '%s:%s
' "$FTP_USER" "$FTP_PASS" | chpasswd 2>&1 | tee -a "$LOG_FILE" || fatal "初始化 FTP 用户密码失败"
chown -R "$FTP_USER:$FTP_USER" "$FILES_DIR" 2>/dev/null || true
chmod 755 "$DATA_DIR" "$FILES_DIR" 2>/dev/null || true
if [ -f /etc/vsftpd.conf ] && [ ! -f /etc/vsftpd.conf.wanos.bak ]; then cp /etc/vsftpd.conf /etc/vsftpd.conf.wanos.bak; fi
cat > /etc/vsftpd.wanos.userlist <<EOF
$FTP_USER
EOF
cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
check_shell=YES
userlist_enable=YES
userlist_file=/etc/vsftpd.wanos.userlist
userlist_deny=NO
local_root=$FILES_DIR
listen_port=$FTP_PORT
pasv_enable=YES
pasv_min_port=$PASV_MIN
pasv_max_port=$PASV_MAX
utf8_filesystem=YES
EOF
mkdir -p /var/run/vsftpd/empty
cat >"/etc/systemd/system/ftp-server-panel.service" <<EOF
[Unit]
Description=WanOS FTP Server Panel
After=network-online.target vsftpd.service
Wants=network-online.target

[Service]
Type=simple
Environment=FTP_PANEL_PORT=$PORT
Environment=FTP_USER=$FTP_USER
Environment=FTP_DATA_DIR=$DATA_DIR
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/ftp-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now vsftpd.service 2>&1 | tee -a "$LOG_FILE" || fatal "vsftpd 启动失败，可能是 21 端口被占用"
systemctl enable --now ftp-server-panel.service 2>&1 | tee -a "$LOG_FILE" || fatal "FTP 面板启动失败"
log "更新完成。面板：http://设备IP:$PORT；FTP：ftp://设备IP/；默认账号：$FTP_USER 默认密码：$FTP_PASS"
