#!/bin/sh
set -eu

APP_ID="oec-led"
APP_NAME="OEC/T 指示灯"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PORT="${OEC_LED_PANEL_PORT:-18232}"

log(){ printf '%s\n' "[$APP_NAME] $*"; }
fatal(){ printf '%s\n' "[$APP_NAME] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "systemd is required"
has_cmd python3 || fatal "python3 is required"

mkdir -p "$APP_DIR" "$DATA_DIR"

cat >"$APP_DIR/oec-led-panel.py" <<'PY'
#!/usr/bin/env python3
import html
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

PORT = int(os.environ.get("OEC_LED_PANEL_PORT", "18232"))
DATA_DIR = os.environ.get("OEC_LED_DATA_DIR", "/opt/wanos-data/apps/oec-led")
CONFIG_FILE = os.path.join(DATA_DIR, "config.json")
GPIO_ROOT = "/sys/class/gpio"

# OEC BOX WXY4 device tree has gpio-leds disabled, so no visible LED appears in
# /sys/class/leds. These are parsed from /sys/firmware/fdt:
# red: gpio0 pin19, green: gpio3 pin12, blue: gpio3 pin11, all active-low.
GPIO_LEDS = {
    "red": {"gpio": 19, "label": "红灯"},
    "green": {"gpio": 108, "label": "绿灯"},
    "blue": {"gpio": 107, "label": "蓝灯"},
}
COLORS = {
    "off": [],
    "red": ["red"],
    "green": ["green"],
    "blue": ["blue"],
    "yellow": ["red", "green"],
    "purple": ["red", "blue"],
    "cyan": ["green", "blue"],
    "white": ["red", "green", "blue"],
}
COLOR_LABELS = {
    "off": "关闭",
    "red": "红色",
    "green": "绿色",
    "blue": "蓝色",
    "yellow": "黄色",
    "purple": "紫色",
    "cyan": "青色",
    "white": "白色",
}
MODE_LABELS = {"steady": "常亮", "slow": "慢闪", "fast": "快闪"}
DELAYS = {"slow": (0.8, 0.8), "fast": (0.16, 0.16)}
DEFAULT_CONFIG = {"color": "green", "mode": "steady"}

blink_lock = threading.Lock()
blink_stop = threading.Event()
blink_thread = None

def esc(value):
    return html.escape(str(value or ""), quote=True)

def read_text(path):
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except Exception:
        return ""

def write_text(path, value):
    with open(path, "w") as f:
        f.write(str(value))

def gpio_path(num):
    return os.path.join(GPIO_ROOT, "gpio{}".format(num))

def export_gpio(num):
    path = gpio_path(num)
    if not os.path.isdir(path):
        try:
            write_text(os.path.join(GPIO_ROOT, "export"), num)
        except Exception:
            pass
    for _ in range(20):
        if os.path.isdir(path):
            break
        time.sleep(0.05)
    if not os.path.isdir(path):
        raise RuntimeError("GPIO {} 不可用".format(num))
    write_text(os.path.join(path, "direction"), "out")

def set_gpio(name, on):
    num = GPIO_LEDS[name]["gpio"]
    export_gpio(num)
    # Active-low: 0 lights up, 1 turns off.
    write_text(os.path.join(gpio_path(num), "value"), "0" if on else "1")

def all_off():
    for name in GPIO_LEDS:
        try:
            set_gpio(name, False)
        except Exception:
            pass

def apply_once(color, on=True):
    selected = set(COLORS.get(color, [])) if on else set()
    for name in GPIO_LEDS:
        set_gpio(name, name in selected)

def stop_blink():
    global blink_thread
    blink_stop.set()
    if blink_thread and blink_thread.is_alive():
        blink_thread.join(timeout=1.5)
    blink_thread = None
    blink_stop.clear()

def blink_loop(color, on_sec, off_sec):
    while not blink_stop.is_set():
        apply_once(color, True)
        if blink_stop.wait(on_sec):
            break
        apply_once(color, False)
        if blink_stop.wait(off_sec):
            break

def apply_config(cfg):
    global blink_thread
    with blink_lock:
        stop_blink()
        color = cfg.get("color", "green")
        mode = cfg.get("mode", "steady")
        if color == "off":
            all_off()
            return
        if mode in DELAYS:
            on_sec, off_sec = DELAYS[mode]
            blink_thread = threading.Thread(target=blink_loop, args=(color, on_sec, off_sec), daemon=True)
            blink_thread.start()
        else:
            apply_once(color, True)

def load_config():
    try:
        with open(CONFIG_FILE, "r") as f:
            data = json.load(f)
    except Exception:
        data = {}
    color = data.get("color") if data.get("color") in COLORS else DEFAULT_CONFIG["color"]
    mode = data.get("mode") if data.get("mode") in MODE_LABELS else DEFAULT_CONFIG["mode"]
    return {"color": color, "mode": mode}

def save_config(cfg):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)

def gpio_state_rows():
    rows = ""
    for name, info in GPIO_LEDS.items():
        num = info["gpio"]
        value = read_text(os.path.join(gpio_path(num), "value"))
        rows += "<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>".format(
            esc(info["label"]), num, esc(value or "-"), "亮" if value == "0" else "灭"
        )
    return rows

def option(value, current, label):
    return '<option value="{}" {}>{}</option>'.format(esc(value), "selected" if value == current else "", esc(label))

def render(message=""):
    cfg = load_config()
    color_options = "".join(option(k, cfg["color"], v) for k, v in COLOR_LABELS.items())
    mode_options = "".join(option(k, cfg["mode"], v) for k, v in MODE_LABELS.items())
    dots = "".join('<span class="dot {}"></span>'.format(c) for c in COLORS.get(cfg["color"], [])) or '<span class="dot"></span>'
    msg_html = '<div class="msg">{}</div>'.format(esc(message)) if message else ""
    return """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>OEC/T 指示灯</title><style>
body{{margin:0;background:#f5f7fb;color:#172033;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}.wrap{{max-width:960px;margin:0 auto;padding:22px}}h1{{font-size:24px;margin:0 0 8px}}.sub{{color:#667085;margin-bottom:18px;line-height:1.7}}.grid{{display:grid;grid-template-columns:1fr 1fr;gap:14px}}.card{{background:#fff;border:1px solid #e4e7ec;border-radius:8px;padding:16px;margin:12px 0;box-shadow:0 1px 2px rgba(16,24,40,.04)}}label{{display:block;color:#667085;font-size:13px;margin:10px 0 5px}}select{{box-sizing:border-box;width:100%;height:40px;border:1px solid #d0d5dd;border-radius:6px;padding:0 10px;background:#fff}}button{{height:38px;padding:0 14px;border:0;border-radius:6px;background:#1f6feb;color:#fff;cursor:pointer;margin:12px 8px 0 0}}.danger{{background:#d92d20}}.msg{{background:#ecfdf3;border:1px solid #abefc6;color:#067647;border-radius:6px;padding:10px;margin:12px 0}}.warn{{background:#fffaeb;border:1px solid #fedf89;color:#93370d;border-radius:6px;padding:10px;margin:12px 0;line-height:1.7}}table{{width:100%;border-collapse:collapse}}td,th{{padding:9px;border-bottom:1px solid #eef1f5;text-align:left;font-size:13px}}th{{color:#667085}}.preview{{display:flex;gap:12px;margin:18px 0}}.dot{{width:44px;height:44px;border-radius:50%;background:#d0d5dd;box-shadow:inset 0 0 0 1px rgba(0,0,0,.08)}}.dot.red{{background:#ef4444;box-shadow:0 0 18px rgba(239,68,68,.45)}}.dot.green{{background:#22c55e;box-shadow:0 0 18px rgba(34,197,94,.45)}}.dot.blue{{background:#1d9bd7;box-shadow:0 0 18px rgba(29,155,215,.45)}}.hint{{font-size:13px;color:#667085;line-height:1.7}}@media(max-width:760px){{.grid{{grid-template-columns:1fr}}}}
</style></head><body><div class="wrap"><h1>网心云 OEC/T 指示灯</h1><div class="sub">控制 OEC/T rk3566 设备树里的三色指示灯 GPIO。实测脚位：红灯 GPIO19、绿灯 GPIO108、蓝灯 GPIO107，均为低电平点亮。</div>{msg}<div class="grid"><div class="card"><h2>灯光设置</h2><form method="post"><label>颜色</label><select name="color">{color_options}</select><label>模式</label><select name="mode">{mode_options}</select><button>保存并应用</button><button class="danger" name="color" value="off">关闭指示灯</button></form><div class="warn">如果刚刷机后系统服务占用了灯，保存一次会接管这三个 GPIO。</div></div><div class="card"><h2>当前效果</h2><div class="preview">{dots}</div><p class="hint">当前：{color} · {mode}</p></div></div><div class="card"><h2>GPIO 状态</h2><table><tr><th>灯</th><th>GPIO</th><th>value</th><th>状态</th></tr>{rows}</table></div></div></body></html>""".format(
        msg=msg_html,
        color_options=color_options,
        mode_options=mode_options,
        dots=dots,
        color=esc(COLOR_LABELS.get(cfg["color"], cfg["color"])),
        mode=esc(MODE_LABELS.get(cfg["mode"], cfg["mode"])),
        rows=gpio_state_rows(),
    )

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def do_GET(self):
        self.send_html(render())

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        data = parse_qs(self.rfile.read(length).decode("utf-8", "ignore"))
        cfg = {
            "color": (data.get("color") or [DEFAULT_CONFIG["color"]])[0],
            "mode": (data.get("mode") or [DEFAULT_CONFIG["mode"]])[0],
        }
        if cfg["color"] not in COLORS:
            cfg["color"] = DEFAULT_CONFIG["color"]
        if cfg["mode"] not in MODE_LABELS:
            cfg["mode"] = DEFAULT_CONFIG["mode"]
        try:
            save_config(cfg)
            apply_config(cfg)
            message = "已保存并应用指示灯设置。"
        except Exception as exc:
            message = "应用失败：" + str(exc)
        self.send_html(render(message))

    def send_html(self, body):
        raw = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    for info in GPIO_LEDS.values():
        export_gpio(info["gpio"])
    cfg = load_config()
    if not os.path.exists(CONFIG_FILE):
        save_config(cfg)
    apply_config(cfg)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()

if __name__ == "__main__":
    main()
PY

chmod +x "$APP_DIR/oec-led-panel.py"

cat >"/etc/systemd/system/oec-led-panel.service" <<EOF
[Unit]
Description=WanOS OEC/T LED Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=OEC_LED_PANEL_PORT=$PORT
Environment=OEC_LED_DATA_DIR=$DATA_DIR
ExecStart=/usr/bin/python3 $APP_DIR/oec-led-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable oec-led-panel >/dev/null 2>&1 || true
systemctl restart oec-led-panel
log "installed, panel port: $PORT"
