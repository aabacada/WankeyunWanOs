#!/bin/sh
set -eu
APP_ID="onecloud-led"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PORT="${ONECLOUD_LED_PANEL_PORT:-18231}"
log(){ printf '%s
' "[OneCloud LED] $*"; }
fatal(){ printf '%s
' "[OneCloud LED] ERROR: $*" >&2; exit 1; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
[ "$(id -u)" = "0" ] || fatal "please install as root"
has_cmd systemctl || fatal "systemd is required"
has_cmd python3 || fatal "python3 is required"
mkdir -p "$APP_DIR" "$DATA_DIR"
cat >"$APP_DIR/onecloud-led-panel.py" <<'PY'
#!/usr/bin/env python3
import html, json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

PORT = int(os.environ.get('ONECLOUD_LED_PANEL_PORT', '18231'))
DATA_DIR = os.environ.get('ONECLOUD_LED_DATA_DIR', '/opt/wanos-data/apps/onecloud-led')
CONFIG_FILE = os.path.join(DATA_DIR, 'config.json')
LEDS = {'red': '/sys/class/leds/onecloud:red:alive', 'green': '/sys/class/leds/onecloud:green:alive', 'blue': '/sys/class/leds/onecloud:blue:alive'}
COLORS = {'off': [], 'red': ['red'], 'green': ['green'], 'blue': ['blue'], 'yellow': ['red', 'green'], 'purple': ['red', 'blue'], 'cyan': ['green', 'blue'], 'white': ['red', 'green', 'blue']}
COLOR_LABELS = {'off': '\u5173\u95ed', 'red': '\u7ea2\u8272', 'green': '\u7eff\u8272', 'blue': '\u84dd\u8272', 'yellow': '\u9ec4\u8272\uff08\u7ea2+\u7eff\uff09', 'purple': '\u7d2b\u8272\uff08\u7ea2+\u84dd\uff09', 'cyan': '\u9752\u8272\uff08\u7eff+\u84dd\uff09', 'white': '\u767d\u8272\uff08\u7ea2+\u7eff+\u84dd\uff09'}
MODE_LABELS = {'steady': '\u5e38\u4eae', 'slow': '\u6162\u95ea', 'fast': '\u5feb\u95ea'}
DELAYS = {'slow': (1000, 1000), 'fast': (150, 150)}
DEFAULT_CONFIG = {'color': 'blue', 'mode': 'steady'}

def write_file(path, value):
    with open(path, 'w') as f:
        f.write(str(value))

def read_file(path):
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except Exception:
        return ''

def available():
    return {name: os.path.isdir(base) for name, base in LEDS.items()}

def load_config():
    try:
        with open(CONFIG_FILE, 'r') as f:
            data = json.load(f)
    except Exception:
        data = {}
    return {'color': data.get('color') if data.get('color') in COLORS else DEFAULT_CONFIG['color'], 'mode': data.get('mode') if data.get('mode') in MODE_LABELS else DEFAULT_CONFIG['mode']}

def save_config(cfg):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)

def set_led(name, on, mode):
    base = LEDS.get(name)
    if not base or not os.path.isdir(base):
        return
    trigger = os.path.join(base, 'trigger')
    brightness = os.path.join(base, 'brightness')
    if not on:
        if os.path.exists(trigger): write_file(trigger, 'none')
        if os.path.exists(brightness): write_file(brightness, '0')
        return
    if mode in DELAYS:
        if os.path.exists(trigger): write_file(trigger, 'timer')
        on_ms, off_ms = DELAYS[mode]
        for key, value in [('delay_on', on_ms), ('delay_off', off_ms)]:
            p = os.path.join(base, key)
            if os.path.exists(p): write_file(p, value)
    else:
        if os.path.exists(trigger): write_file(trigger, 'none')
        if os.path.exists(brightness): write_file(brightness, '1')

def apply_config(cfg):
    selected = set(COLORS.get(cfg.get('color'), []))
    for name in LEDS:
        set_led(name, name in selected, cfg.get('mode', 'steady'))

def current_state():
    rows = []
    for name, base in LEDS.items():
        rows.append({'name': name, 'path': base, 'exists': os.path.isdir(base), 'trigger': read_file(os.path.join(base, 'trigger')), 'brightness': read_file(os.path.join(base, 'brightness'))})
    return rows

def escape(value):
    return html.escape(str(value or ''), quote=True)

def render_icon_option(color, cfg):
    checked = ' checked' if cfg['color'] == color else ''
    label = escape(COLOR_LABELS[color])
    return f'<label class="icon-option {color}"><input type="radio" name="color" value="{color}"{checked}><span class="led-icon-shape"></span><b>{label}</b></label>'

def render(msg=''):
    cfg = load_config()
    all_found = all(available().values())
    mode_options = ''.join(f'<option value="{k}" {"selected" if cfg["mode"] == k else ""}>{escape(v)}</option>' for k, v in MODE_LABELS.items())
    combo_options = ''.join(f'<option value="{k}" {"selected" if cfg["color"] == k else ""}>{escape(v)}</option>' for k, v in COLOR_LABELS.items() if k not in ('red', 'green', 'blue'))
    state_rows = ''
    for item in current_state():
        state_rows += '<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>'.format(escape(item['name']), escape('\u5b58\u5728' if item['exists'] else '\u672a\u627e\u5230'), escape(item['brightness']), escape(item['trigger']))
    msg_html = f'<div class="msg">{escape(msg)}</div>' if msg else ''
    warn = '' if all_found else '<div class="warn">\u672a\u68c0\u6d4b\u5230\u5b8c\u6574\u7684\u73a9\u5ba2\u4e91\u7ea2\u7eff\u84dd\u6307\u793a\u706f\u8def\u5f84\uff0c\u8bf7\u786e\u8ba4\u8bbe\u5907\u662f\u73a9\u5ba2\u4e91\u4e14\u5185\u6838\u5df2\u66b4\u9732 LED\u3002</div>'
    dots = ''.join(f'<span class="dot {c}"></span>' for c in COLORS.get(cfg['color'], [])) or '<span class="dot"></span>'
    color_label = escape(COLOR_LABELS.get(cfg['color'], cfg['color']))
    mode_label = escape(MODE_LABELS.get(cfg['mode'], cfg['mode']))
    icon_options = ''.join(render_icon_option(c, cfg) for c in ['blue', 'red', 'green'])
    return f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\u73a9\u5ba2\u4e91\u6307\u793a\u706f</title><style>
body{{margin:0;background:#f5f7fb;color:#172033;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}.wrap{{max-width:980px;margin:0 auto;padding:22px}}h1{{font-size:24px;margin:0 0 8px}}.sub{{color:#667085;margin-bottom:18px;line-height:1.7}}.grid{{display:grid;grid-template-columns:1fr 1fr;gap:14px}}.card{{background:#fff;border:1px solid #e4e7ec;border-radius:8px;padding:16px;margin:12px 0;box-shadow:0 1px 2px rgba(16,24,40,.04)}}label{{display:block;color:#667085;font-size:13px;margin:10px 0 5px}}select{{box-sizing:border-box;width:100%;height:40px;border:1px solid #d0d5dd;border-radius:6px;padding:0 10px;background:#fff}}button{{height:38px;padding:0 14px;border:0;border-radius:6px;background:#1f6feb;color:#fff;cursor:pointer;margin:6px 8px 0 0}}.secondary{{background:#667085}}.danger{{background:#d92d20}}.msg{{background:#ecfdf3;border:1px solid #abefc6;color:#067647;border-radius:6px;padding:10px;margin:12px 0}}.warn{{background:#fffaeb;border:1px solid #fedf89;color:#93370d;border-radius:6px;padding:10px;margin:12px 0;line-height:1.7}}table{{width:100%;border-collapse:collapse}}td,th{{padding:9px;border-bottom:1px solid #eef1f5;text-align:left;font-size:13px}}th{{color:#667085}}.led-preview{{display:flex;gap:12px;align-items:center;margin-top:8px}}.dot{{width:38px;height:38px;border-radius:50%;background:#d0d5dd;box-shadow:inset 0 0 0 1px rgba(0,0,0,.08)}}.dot.red{{background:#ef4444;box-shadow:0 0 18px rgba(239,68,68,.45)}}.dot.green{{background:#22c55e;box-shadow:0 0 18px rgba(34,197,94,.45)}}.dot.blue{{background:#1d9bd7;box-shadow:0 0 18px rgba(29,155,215,.45)}}.hint{{font-size:13px;color:#667085;line-height:1.7}}.icon-grid{{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:10px 0 4px}}.icon-option{{display:grid;place-items:center;gap:8px;margin:0;padding:12px 8px;border:1px solid #d0d5dd;border-radius:8px;background:#fff;cursor:pointer;color:#344054}}.icon-option input{{position:absolute;opacity:0;pointer-events:none}}.icon-option:has(input:checked){{border-color:#1f6feb;box-shadow:0 0 0 3px rgba(31,111,235,.12)}}.led-icon-shape{{position:relative;width:64px;height:74px;display:block}}.led-icon-shape:before{{content:"";position:absolute;left:12px;top:0;width:40px;height:52px;border-radius:22px 22px 4px 4px;background:#16a34a}}.led-icon-shape:after{{content:"";position:absolute;left:2px;top:44px;width:60px;height:14px;border:6px solid #16a34a;border-radius:20px;background:transparent}}.icon-option.blue .led-icon-shape:before{{background:#1d9bd7}}.icon-option.blue .led-icon-shape:after{{border-color:#1d9bd7}}.icon-option.red .led-icon-shape:before{{background:#e21b0c}}.icon-option.red .led-icon-shape:after{{border-color:#e21b0c}}.icon-option.green .led-icon-shape:before{{background:#11fb23}}.icon-option.green .led-icon-shape:after{{border-color:#11fb23}}.icon-option b{{font-size:13px}}@media(max-width:760px){{.grid{{grid-template-columns:1fr}}.icon-grid{{grid-template-columns:repeat(3,1fr)}}}}
</style></head><body><div class="wrap"><h1>\u73a9\u5ba2\u4e91\u6307\u793a\u706f</h1><div class="sub">\u63a7\u5236\u73a9\u5ba2\u4e91\u673a\u8eab\u7ea2\u3001\u7eff\u3001\u84dd\u6307\u793a\u706f\uff0c\u652f\u6301\u5e38\u4eae\u3001\u6162\u95ea\u3001\u5feb\u95ea\uff0c\u4fdd\u5b58\u540e\u5f00\u673a\u81ea\u52a8\u6062\u590d\u3002</div>{msg_html}{warn}<div class="grid"><div class="card"><h2>\u6307\u793a\u706f\u8bbe\u7f6e</h2><form method="post"><input type="hidden" name="action" value="save"><label>\u70b9\u51fb\u9009\u62e9\u989c\u8272</label><div class="icon-grid">{icon_options}</div><label>\u7ec4\u5408\u8272 / \u5173\u95ed</label><select name="combo_color" onchange="if(this.value){{document.querySelectorAll('input[name=color]').forEach(function(x){{x.checked=false}})}}"><option value="">\u4f7f\u7528\u4e0a\u65b9\u989c\u8272\u56fe\u6807</option>{combo_options}</select><label>\u6a21\u5f0f</label><select name="mode">{mode_options}</select><button>\u4fdd\u5b58\u5e76\u5e94\u7528</button></form><form method="post"><button class="secondary" name="action" value="apply">\u91cd\u65b0\u5e94\u7528</button><button class="danger" name="action" value="off">\u5173\u95ed\u6307\u793a\u706f</button></form><div class="hint">\u7ec4\u5408\u8272\u662f\u540c\u65f6\u70b9\u4eae\u591a\u8def LED\uff0c\u5b9e\u9645\u6548\u679c\u53d6\u51b3\u4e8e\u73a9\u5ba2\u4e91\u706f\u7f69\u548c\u786c\u4ef6\u6df7\u5149\u6548\u679c\u3002</div></div><div class="card"><h2>\u5f53\u524d\u6548\u679c</h2><div class="led-preview">{dots}</div><p class="hint">\u5f53\u524d\uff1a{color_label} \u00b7 {mode_label}</p></div></div><div class="card"><h2>\u7cfb\u7edf LED \u72b6\u6001</h2><table><tr><th>\u989c\u8272</th><th>\u8def\u5f84</th><th>\u4eae\u5ea6</th><th>\u89e6\u53d1\u5668</th></tr>{state_rows}</table></div></div></body></html>'''

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): return
    def do_GET(self): self.send(render())
    def do_POST(self):
        length = int(self.headers.get('Content-Length') or 0)
        data = parse_qs(self.rfile.read(length).decode('utf-8', 'ignore'))
        action = (data.get('action') or ['save'])[0]
        cfg = load_config()
        try:
            if action == 'off':
                cfg = {'color': 'off', 'mode': 'steady'}; save_config(cfg); apply_config(cfg); msg = '\u5df2\u5173\u95ed\u6307\u793a\u706f\u3002'
            elif action == 'apply':
                apply_config(cfg); msg = '\u5df2\u91cd\u65b0\u5e94\u7528\u5f53\u524d\u8bbe\u7f6e\u3002'
            else:
                combo = (data.get('combo_color') or [''])[0]
                color = combo or (data.get('color') or [cfg['color']])[0]
                mode = (data.get('mode') or [cfg['mode']])[0]
                cfg = {'color': color if color in COLORS else 'blue', 'mode': mode if mode in MODE_LABELS else 'steady'}
                save_config(cfg); apply_config(cfg); msg = '\u5df2\u4fdd\u5b58\u5e76\u5e94\u7528\u6307\u793a\u706f\u8bbe\u7f6e\u3002'
        except Exception as exc:
            msg = f'\u5e94\u7528\u5931\u8d25\uff1a{exc}'
        self.send(render(msg))
    def send(self, body):
        raw = body.encode('utf-8')
        self.send_response(200); self.send_header('Content-Type', 'text/html; charset=utf-8'); self.send_header('Content-Length', str(len(raw))); self.end_headers(); self.wfile.write(raw)

def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    cfg = load_config()
    if not os.path.exists(CONFIG_FILE): save_config(cfg)
    try: apply_config(cfg)
    except Exception: pass
    ThreadingHTTPServer(('0.0.0.0', PORT), Handler).serve_forever()

if __name__ == '__main__': main()

PY
chmod +x "$APP_DIR/onecloud-led-panel.py"
cat >"/etc/systemd/system/onecloud-led-panel.service" <<EOF
[Unit]
Description=WanOS OneCloud LED Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=ONECLOUD_LED_PANEL_PORT=$PORT
Environment=ONECLOUD_LED_DATA_DIR=$DATA_DIR
ExecStart=/usr/bin/python3 $APP_DIR/onecloud-led-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now onecloud-led-panel >/dev/null 2>&1 || systemctl restart onecloud-led-panel
log "installed, panel port: $PORT"
