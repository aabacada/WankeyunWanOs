#!/bin/sh
set -eu
APP_ID="nvr-lite"
APP_NAME="网络摄像机录像"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PKG_URL="${NVR_LITE_PACKAGE_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/nvr-lite-motion-focal-armhf.tar.gz}"
PKG_SHA256="${NVR_LITE_PACKAGE_SHA256:-7f077deeecd0b59ebba5f6baa3e63514564efc456dbfbfc55f761e40526d959c}"
PANEL_PORT="${NVR_PANEL_PORT:-18081}"
WEB_PORT="${NVR_WEB_PORT:-18082}"
STREAM_PORT="${NVR_STREAM_PORT:-18083}"
CONF_DIR="$DATA_DIR/config"
REC_DIR="$DATA_DIR/recordings"
MOTION_CONF="$CONF_DIR/motion.conf"
CAMERA_CONF="$CONF_DIR/camera.conf"
LOG_FILE="/var/log/wanos-nvr-lite-install.log"
TMP_DIR="/tmp/wanos-nvr-lite-install"
trap 'rm -rf "$TMP_DIR"' EXIT
log(){ printf '%s\n' "[NVR] $*"; }
fatal(){ printf '%s\n' "[NVR] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "请使用 root 安装。"
has_cmd systemctl || fatal "本应用需要 systemd。"
has_cmd python3 || fatal "本应用需要 Python3 用于中文 Web 面板。"
: >"$LOG_FILE" 2>/dev/null || true
if ! has_cmd motion; then
  has_cmd dpkg || fatal "系统缺少 dpkg，无法安装离线 deb 包。"
  if ! has_cmd curl && ! has_cmd wget; then
    fatal "系统缺少 curl/wget，无法下载离线包。"
  fi
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
  [ -d "$TMP_DIR" ] || fatal "临时目录创建失败：$TMP_DIR"
  log "下载 motion 离线包：$PKG_URL"
  if has_cmd curl; then
    curl -fL --connect-timeout 15 --max-time 3600 --retry 3 --retry-delay 2 --create-dirs -o "$TMP_DIR/package.tar.gz" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE" || fatal "离线包下载失败"
  else
    wget -O "$TMP_DIR/package.tar.gz" "$PKG_URL" 2>&1 | tee -a "$LOG_FILE" || fatal "离线包下载失败"
  fi
  [ -s "$TMP_DIR/package.tar.gz" ] || fatal "离线包下载后文件为空"
  if [ -n "$PKG_SHA256" ]; then
    GOT="$(sha256sum "$TMP_DIR/package.tar.gz" | awk '{print $1}')"
    [ "$GOT" = "$PKG_SHA256" ] || fatal "离线包校验失败：want $PKG_SHA256 got $GOT"
  fi
  tar -xzf "$TMP_DIR/package.tar.gz" -C "$TMP_DIR" 2>&1 | tee -a "$LOG_FILE" || fatal "离线包解压失败"
  DEB_DIR="$TMP_DIR/debs"
  if [ ! -d "$DEB_DIR" ]; then
    DEB_DIR="$(find "$TMP_DIR" -maxdepth 3 -type d -name debs | head -n 1)"
  fi
  [ -n "$DEB_DIR" ] && [ -d "$DEB_DIR" ] || fatal "离线包格式错误：缺少 debs 目录"
  log "安装 motion 离线 deb 包"
  dpkg -i "$DEB_DIR"/*.deb 2>&1 | tee -a "$LOG_FILE" || fatal "motion 离线 deb 安装失败，请检查离线包是否包含完整依赖"
  rm -rf "$TMP_DIR"
fi
mkdir -p "$APP_DIR" "$CONF_DIR" "$REC_DIR"
cat >"$MOTION_CONF" <<EOF
daemon off
setup_mode off
log_level 6
log_type all
videodevice /dev/video0
width 1280
height 720
framerate 10
target_dir $REC_DIR
picture_output off
movie_output on
movie_codec mkv
movie_max_time 1800
stream_port $STREAM_PORT
stream_localhost off
stream_maxrate 10
webcontrol_port $WEB_PORT
webcontrol_localhost off
webcontrol_parms 2
webcontrol_interface 0
camera $CAMERA_CONF
EOF
cat >"$CAMERA_CONF" <<EOF
camera_name camera1
netcam_url
netcam_userpass
width 1280
height 720
framerate 10
target_dir $REC_DIR/camera1
picture_output off
movie_output on
movie_codec mkv
movie_max_time 1800
stream_port $STREAM_PORT
EOF
mkdir -p "$REC_DIR/camera1"
cat >"$APP_DIR/nvr-panel.py" <<'PY'
#!/usr/bin/env python3
import html
import json
import os
import socket
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

APP_DIR = os.environ.get("NVR_APP_DIR", "/opt/wanos/apps/nvr-lite")
DATA_DIR = os.environ.get("NVR_DATA_DIR", "/opt/wanos-data/apps/nvr-lite")
PANEL_PORT = int(os.environ.get("NVR_PANEL_PORT", "18081"))
WEB_PORT = int(os.environ.get("NVR_WEB_PORT", "18082"))
STREAM_PORT = int(os.environ.get("NVR_STREAM_PORT", "18083"))
CONF_DIR = os.path.join(DATA_DIR, "config")
REC_DIR = os.path.join(DATA_DIR, "recordings")
MOTION_CONF = os.path.join(CONF_DIR, "motion.conf")
CAMERA_CONF = os.path.join(CONF_DIR, "camera.conf")


def run(cmd, timeout=12):
    try:
        p = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except Exception as exc:
        return 1, str(exc)


def service_status(name):
    code, out = run(["systemctl", "is-active", name], 5)
    active = out.strip() or ("active" if code == 0 else "unknown")
    code2, out2 = run(["systemctl", "is-enabled", name], 5)
    enabled = out2.strip() or "unknown"
    return active, enabled


def port_open(port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    try:
        return sock.connect_ex(("127.0.0.1", int(port))) == 0
    finally:
        sock.close()


def read_camera():
    data = {
        "name": "camera1",
        "url": "",
        "userpass": "",
        "width": "1280",
        "height": "720",
        "framerate": "10",
        "movie_max_time": "1800",
        "record_dir": os.path.join(REC_DIR, "camera1"),
    }
    try:
        for raw in open(CAMERA_CONF, "r", encoding="utf-8", errors="ignore"):
            line = raw.strip()
            if not line or line.startswith("#") or " " not in line:
                continue
            key, value = line.split(None, 1)
            if key == "camera_name":
                data["name"] = value
            elif key == "netcam_url":
                data["url"] = value
            elif key == "netcam_userpass":
                data["userpass"] = value
            elif key in ("width", "height", "framerate", "movie_max_time"):
                data[key] = value
            elif key == "target_dir":
                data["record_dir"] = value
    except FileNotFoundError:
        pass
    return data


def write_camera(data):
    os.makedirs(CONF_DIR, exist_ok=True)
    os.makedirs(data["record_dir"], exist_ok=True)
    lines = [
        "camera_name " + data["name"],
        "netcam_url " + data["url"],
        "netcam_userpass " + data["userpass"],
        "width " + data["width"],
        "height " + data["height"],
        "framerate " + data["framerate"],
        "target_dir " + data["record_dir"],
        "picture_output off",
        "movie_output on",
        "movie_codec mkv",
        "movie_max_time " + data["movie_max_time"],
        "stream_port " + str(STREAM_PORT),
    ]
    with open(CAMERA_CONF, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def disk_usage(path):
    try:
        st = os.statvfs(path)
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        used = total - free
        return total, used, free
    except Exception:
        return 0, 0, 0


def fmt_bytes(n):
    n = float(n or 0)
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if n < 1024 or unit == "TB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024


def render(message=""):
    cam = read_camera()
    active, enabled = service_status("nvr-lite")
    panel_active, panel_enabled = service_status("nvr-lite-panel")
    total, used, free = disk_usage(REC_DIR)
    stream_url = f"http://设备IP:{STREAM_PORT}/"
    control_url = f"http://设备IP:{WEB_PORT}/"
    msg = f'<div class="msg">{html.escape(message)}</div>' if message else ""
    rows = [
        ("录像服务", active),
        ("开机启动", enabled),
        ("中文面板", panel_active),
        ("motion 控制端口", "监听中" if port_open(WEB_PORT) else "未监听"),
        ("视频流端口", "监听中" if port_open(STREAM_PORT) else "未监听"),
        ("录像目录", REC_DIR),
        ("磁盘已用/可用", fmt_bytes(used) + " / " + fmt_bytes(free)),
    ]
    trs = "".join(f"<tr><td>{html.escape(k)}</td><td>{html.escape(str(v))}</td></tr>" for k, v in rows)
    def val(k):
        return html.escape(cam.get(k, ""))
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>网络摄像机录像</title><style>
body{{margin:0;background:#f5f7fb;color:#172033;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}.wrap{{max-width:980px;margin:0 auto;padding:22px}}h1{{font-size:22px;margin:0 0 8px}}h2{{font-size:16px;margin:0 0 12px}}.sub{{color:#667085;margin-bottom:18px}}.grid{{display:grid;grid-template-columns:1fr 1fr;gap:14px}}.card{{background:#fff;border:1px solid #e4e7ec;border-radius:8px;padding:16px;margin:12px 0;box-shadow:0 1px 2px rgba(16,24,40,.04)}}table{{width:100%;border-collapse:collapse}}td{{padding:10px;border-bottom:1px solid #eef1f5}}td:first-child{{width:150px;color:#667085}}label{{display:block;color:#667085;font-size:13px;margin:10px 0 5px}}input{{box-sizing:border-box;width:100%;height:38px;border:1px solid #d0d5dd;border-radius:6px;padding:0 10px}}button{{height:36px;padding:0 14px;border:0;border-radius:6px;background:#1f6feb;color:#fff;cursor:pointer;margin:4px 6px 4px 0}}button.secondary{{background:#667085}}button.danger{{background:#d92d20}}.msg{{background:#ecfdf3;border:1px solid #abefc6;color:#067647;border-radius:6px;padding:10px;margin:12px 0}}.warn{{background:#fffaeb;border:1px solid #fedf89;color:#93370d;border-radius:6px;padding:10px;margin-top:10px}}code{{background:#eef1f5;border-radius:4px;padding:2px 5px}}.links a{{display:inline-block;margin-right:10px;color:#1f6feb}}@media(max-width:760px){{.grid{{grid-template-columns:1fr}}}}</style></head><body><div class="wrap"><h1>网络摄像机录像</h1><div class="sub">轻量 NVR，基于 motion，适合 1-2 路低码率 RTSP 摄像头录像。</div>{msg}<div class="grid"><div class="card"><h2>运行状态</h2><table>{trs}</table><div class="links"><a href="/preview" target="_blank">打开视频流预览</a><a href="/control" target="_blank">打开 motion 控制页</a></div></div><div class="card"><h2>服务操作</h2><form method="post"><button name="action" value="start">启动</button><button name="action" value="restart">重启</button><button class="secondary" name="action" value="stop">停止</button><button class="danger" name="action" value="clean">清理 7 天前录像</button></form><div class="warn">摄像头地址一般是 <code>rtsp://账号:密码@摄像头IP:554/...</code>。不同品牌路径不一样，需要以摄像头后台为准。</div></div></div><div class="card"><h2>摄像头配置</h2><form method="post"><input type="hidden" name="action" value="save"><label>摄像头名称</label><input name="name" value="{val('name')}"><label>RTSP 地址</label><input name="url" value="{val('url')}" placeholder="rtsp://user:pass@192.168.31.100:554/stream1"><label>单独账号密码，可留空</label><input name="userpass" value="{val('userpass')}" placeholder="user:password"><div class="grid"><div><label>宽度</label><input name="width" value="{val('width')}"></div><div><label>高度</label><input name="height" value="{val('height')}"></div><div><label>帧率</label><input name="framerate" value="{val('framerate')}"></div><div><label>单个录像文件秒数</label><input name="movie_max_time" value="{val('movie_max_time')}"></div></div><label>录像保存目录</label><input name="record_dir" value="{val('record_dir')}"><button>保存并重启录像</button></form></div></div></body></html>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def send_html(self, body):
        data = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/preview"):
            self.send_response(302)
            self.send_header("Location", f"http://{self.headers.get('Host','').split(':')[0]}:{STREAM_PORT}/")
            self.end_headers()
            return
        if self.path.startswith("/control"):
            self.send_response(302)
            self.send_header("Location", f"http://{self.headers.get('Host','').split(':')[0]}:{WEB_PORT}/")
            self.end_headers()
            return
        self.send_html(render())

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        form = parse_qs(self.rfile.read(length).decode("utf-8", "ignore"))
        action = (form.get("action") or [""])[0]
        message = ""
        if action in ("start", "stop", "restart"):
            code, out = run(["systemctl", action, "nvr-lite"], 20)
            message = "操作完成。" if code == 0 else "操作失败：" + out[-500:]
        elif action == "clean":
            code, out = run(["find", REC_DIR, "-type", "f", "-mtime", "+7", "-delete"], 60)
            message = "已清理 7 天前录像。" if code == 0 else "清理失败：" + out[-500:]
        elif action == "save":
            data = {
                "name": (form.get("name") or ["camera1"])[0].strip() or "camera1",
                "url": (form.get("url") or [""])[0].strip(),
                "userpass": (form.get("userpass") or [""])[0].strip(),
                "width": (form.get("width") or ["1280"])[0].strip() or "1280",
                "height": (form.get("height") or ["720"])[0].strip() or "720",
                "framerate": (form.get("framerate") or ["10"])[0].strip() or "10",
                "movie_max_time": (form.get("movie_max_time") or ["1800"])[0].strip() or "1800",
                "record_dir": (form.get("record_dir") or [os.path.join(REC_DIR, "camera1")])[0].strip() or os.path.join(REC_DIR, "camera1"),
            }
            write_camera(data)
            code, out = run(["systemctl", "restart", "nvr-lite"], 20)
            message = "配置已保存并重启录像服务。" if code == 0 else "配置已保存，但重启失败：" + out[-500:]
        self.send_html(render(message))


if __name__ == "__main__":
    os.makedirs(CONF_DIR, exist_ok=True)
    os.makedirs(REC_DIR, exist_ok=True)
    ThreadingHTTPServer(("0.0.0.0", PANEL_PORT), Handler).serve_forever()
PY
chmod +x "$APP_DIR/nvr-panel.py"
cat >"/etc/systemd/system/nvr-lite.service" <<EOF
[Unit]
Description=WanOS Lite NVR Motion Recorder
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/motion -n -c $MOTION_CONF
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat >"/etc/systemd/system/nvr-lite-panel.service" <<EOF
[Unit]
Description=WanOS Lite NVR Panel
After=network-online.target nvr-lite.service
Wants=network-online.target

[Service]
Type=simple
Environment=NVR_APP_DIR=$APP_DIR
Environment=NVR_DATA_DIR=$DATA_DIR
Environment=NVR_PANEL_PORT=$PANEL_PORT
Environment=NVR_WEB_PORT=$WEB_PORT
Environment=NVR_STREAM_PORT=$STREAM_PORT
ExecStart=/usr/bin/python3 $APP_DIR/nvr-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now nvr-lite.service nvr-lite-panel.service 2>&1 | tee -a "$LOG_FILE" || fatal "服务启动失败"
log "安装完成。中文面板端口：$PANEL_PORT；motion 控制端口：$WEB_PORT；视频流端口：$STREAM_PORT。"
