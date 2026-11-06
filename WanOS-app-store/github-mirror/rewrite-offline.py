#!/usr/bin/env python3
"""Rewrite install.sh v2: 100% WanOS-CDN offline.
Reads original scripts from ../../wanos-apps/install-scripts, writes install-scripts-github/.
Rules:
 - Every literal wxqun988.vxjuejin.com / wanos.xyz URL -> GitHub Releases URL (same TAG).
 - Variable base URLs (CDN_BASE / BASE_URL / BIN_BASE_URL / *_URL:-https://...) whose
   value is a WanOS URL -> Releases base; suffix filenames then resolve correctly,
   EXCEPT $BASE_URL/icon.png which is special-cased to <app-id>.png.
 - Icons: <app>/icon.png, icon-small.png, logo.png, xianyu.png, chromium.png,
   minecraft.png, icon-v3.png, wifi-drivers.png -> Releases/<app-id>.png
   (flat Release namespace: icon.png would collide across apps).
 - Panels (.py/.sh): basename as-is (already unique).
 - netbian index.json -> netbian-index.json.
 - Mojang server.jar is NOT rewritten (public resource, out of scope per user 2026-11-06).
 - OnlyOffice ASSETS_URL is dead code in the script (remote download disabled, zip must
   be supplied locally); its URL is still rewritten so grep=0, but the file itself is
   NOT in Releases (both CDN hosts return a 20KB HTML page, not a zip) - see README.
 - Left untouched on purpose (not WanOS CDN): vendor WiFi driver URLs, apt-get,
   Docker Hub image names, api.openai.com, cdnjs, tailscale.com docs, baidu search.
Usage: REPO=USER/NAME TAG=wanos-armv7-20261106 python3 rewrite-offline.py
"""
import json, os, pathlib, re, hashlib

REPO = os.environ.get("REPO", "YOUR_USER/YOUR_REPO")
TAG = os.environ.get("TAG", "wanos-armv7-20261106")

# Temporarily excluded from the mirror (user choice 2026-11-06): home-assistant.
# Its panel Go backend wanos-hass-panel-linux-armv7 is gone from WanOS CDN, so the
# legacy install branch fatals at the panel download step and HA itself never
# installs. Re-add by removing the id from this set (and from build-catalog-github.py
# and build-release-files.py) and re-running the three generators; the 483 MB package
# and panel frontend tar are still kept as local backups.
EXCLUDED = {"home-assistant"}
BASE = pathlib.Path(__file__).parent
SRC = BASE.parent.parent / "wanos-apps" / "install-scripts"
DST = BASE / "install-scripts-github"
MAN = BASE.parent.parent / "wanos-apps" / "manifest.json"
EXTRA = BASE / "manifest-extra.json"
ICONS = BASE.parent.parent / "wanos-apps" / "icons"

release = f"https://github.com/{REPO}/releases/download/{TAG}"

# filenames known to exist in Releases (50 + extra + icons)
known = {m["filename"] for m in json.loads(MAN.read_text())}
known.add("wano--2048.wpk")
if EXTRA.exists():
    known |= {f["filename"] for f in json.loads(EXTRA.read_text())["files"]}
# icons: <app-id>.png
icon_files = {}
if ICONS.exists():
    for p in ICONS.glob("*.png"):
        known.add(p.name)
        icon_files[p.stem] = p.name
# extra icons downloaded into extra-downloads (chromium-headless, minecraft-java, happy-guandan)
icon_files.update({
    "chromium-headless": "chromium-headless.png",
    "minecraft-java": "minecraft-java.png",
    "happy-guandan": "happy-guandan.png",
})
known |= set(icon_files.values())
# renames for flat namespace
RENAMES = {
    "index.json": "netbian-index.json",
    "icon.png": None,  # handled per-app below
    "icon-small.png": None,
    "logo.png": None,
    "xianyu.png": None,
    "chromium.png": "chromium-headless.png",
    "minecraft.png": "minecraft-java.png",
    "icon-v3.png": "wanos-wallpaper.png",
    "wifi-drivers.png": "wanos-wifi-drivers.png",
}

def release_name(app_id, url):
    """Map a WanOS URL to its Releases filename.
    A URL whose last segment is the app id itself (or $APP_ID) is a *base*
    URL (BASE_URL / CDN_BASE / BIN_BASE_URL), not a file: map it to the bare
    Releases base so `$BASE/<file>` compositions stay correct.
    """
    fn = url.rstrip("/").split("/")[-1].split("?")[0].strip('}"\'')
    if fn in (app_id, "$APP_ID"):
        return ""  # base URL -> bare Releases base
    if fn in RENAMES and RENAMES[fn]:
        return RENAMES[fn]
    if fn in ("icon.png", "icon-small.png", "logo.png", "xianyu.png"):
        return f"{app_id}.png"
    return fn

def app_id_from_url(url):
    parts = [p for p in url.split("/") if p]
    # .../downloads/apps/<app>/<file>
    if "apps" in parts:
        return parts[parts.index("apps") + 1]
    return ""

WANOS_RE = re.compile(r"https?://(?:wxqun988\.vxjuejin\.com|wanos\.xyz)/[^\s\"'\)}]+")

def rewrite_text(t, app_id):
    # 1. literal WanOS URLs (strip trailing } that belongs to ${...} in templates)
    def repl(m):
        url = m.group(0)
        name = release_name(app_id, url)
        return release if name == "" else f"{release}/{name}"
    t = WANOS_RE.sub(repl, t)
    # 2. variable bases that were built from a WanOS URL but written as
    #    $BASE_URL / $BIN_BASE_URL / $CDN_BASE etc. - the base definition lines
    #    above were already replaced by rule 1 (they contain the literal URL),
    #    so $BASE_URL now == release base. Fix the one bad composition:
    #    $BASE_URL/icon.png -> release/<app>.png  (wanos-ai-assistant)
    t = t.replace("$BASE_URL/icon.png", f"{release}/{app_id}.png")
    t = t.replace("${BASE_URL}/icon.png", f"{release}/{app_id}.png")
    # 3. Mojang / apt / Docker Hub / vendor drivers: public resources, intentionally left alone.
    # 4. chromium-headless: the only remaining wanos.xyz ref is the browser panel's
    #    default HOME_URL (not a download - the start page). Point it at about:blank
    #    so the mirrored browser does not home to a possibly-dead WanOS site.
    if app_id == "chromium-headless":
        t = t.replace('os.environ.get("CHROMIUM_HOME_URL", "https://wanos.xyz")',
                      'os.environ.get("CHROMIUM_HOME_URL", "about:blank")')
    return t

DST.mkdir(parents=True, exist_ok=True)
stats, remaining = {}, []
for p in sorted(SRC.glob("*.sh")):
    app_id = p.stem
    if app_id in EXCLUDED:
        continue
    t = p.read_text(errors="ignore")
    orig = t
    if app_id == "tiantang":
        # Upstream tiantang install.sh is corrupted: extra `fi` at line 168,
        # duplicated UUID block + orphan `; then` fragment + duplicated
        # sleep/UUID tail (lines 199-220). Fresh re-download is byte-identical,
        # so this is upstream's file, not a download error. The mirror keeps
        # lines 1-167 + 171-177 + 179-198; result passes bash -n (see README).
        lines = t.splitlines(keepends=True)
        t = "".join(lines[0:167] + lines[170:177] + lines[178:198])
        stats_tiantang_fix = True
    else:
        stats_tiantang_fix = False
    t = rewrite_text(t, app_id)
    # tailscale worker template: the heredoc copies PANEL_URL/ARCHIVE_URL literally
    # into a generated script; both copies were rewritten by rule 1 already.
    (DST / p.name).write_text(t)
    left = re.findall(r"wxqun988\.vxjuejin\.com|wanos\.xyz", t)
    if left:
        remaining.append((p.name, len(left)))
    stats[p.stem] = {"changed": t != orig,
                     "sha256": hashlib.sha256(t.encode()).hexdigest(),
                     "wanos_refs_left": len(left),
                     "upstream_fix": "tiantang duplicated tail removed (see README)" if stats_tiantang_fix else None}
pathlib.Path(BASE / "rewrite-report-v2.json").write_text(
    json.dumps(stats, ensure_ascii=False, indent=2))
print(f"done: {sum(1 for v in stats.values() if v['changed'])}/{len(stats)} changed")
print("scripts still referencing WanOS CDN:", remaining if remaining else "NONE - 0 refs")
# list non-WanOS external downloads left (for README gaps section)
import collections
ext = collections.Counter()
for p in sorted(DST.glob("*.sh")):
    t = p.read_text(errors="ignore")
    for m in re.finditer(r"https?://([a-zA-Z0-9.-]+)", t):
        host = m.group(1)
        if host in ("github.com", "raw.githubusercontent.com"):
            continue
        if host in ("127.0.0.1", "localhost") or "DEVICE" in m.group(0) or "device-ip" in m.group(0).lower():
            continue
        ext[host] += 1
print("external hosts still referenced (not WanOS CDN):", dict(ext))
