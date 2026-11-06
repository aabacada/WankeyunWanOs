#!/usr/bin/env python3
"""Build app-store-github.json v2: the offline-mirror catalog.
Sources: apps.json (81 merged), manifest.json (50 main packages),
manifest-extra.json (48 extra WanOS files), manifest-text-resources.json
(131 update/uninstall scripts + 68 icons), rewrite-report-v2.json.
Every WanOS-official URL becomes a GitHub URL:
 - package -> Releases/<filename> (same TAG for all)
 - install/update/uninstall -> raw.githubusercontent/.../<path> (git-tracked text)
 - icon -> raw.githubusercontent/.../icons/<id>.<ext> (git-tracked)
The 3 manual .wpk apps (fengshows-live, live-manager, yt-live) have no public
URLs and are left exactly as in apps.json (excluded by user request).
Un-mirrorable WanOS files are listed under top-level "mirror_gaps".
"""
import hashlib, json, os, pathlib
from urllib.parse import quote

REPO = os.environ.get("REPO", "YOUR_USER/YOUR_REPO")
TAG = os.environ.get("TAG", "wanos-armv7-20261106")

# Subdirectory in the repo where the text files live, e.g. "WanOS-app-store".
# Empty = repo root holds the market files. The value is URL-encoded for raw URLs.
SUBDIR = os.environ.get("SUBDIR", "")

# Temporarily excluded from the mirror (user choice 2026-11-06): home-assistant.
# Its panel Go backend wanos-hass-panel-linux-armv7 is gone from WanOS CDN, so the
# legacy install branch fatals at the panel download step and HA itself never
# installs. Re-add by removing the id from this set (and from rewrite-offline.py
# and build-release-files.py) and re-running the three generators; the 483 MB package
# and panel frontend tar are still kept as local backups.
EXCLUDED = {"home-assistant"}

BASE = pathlib.Path(__file__).parent
MARKET = BASE.parent
release = f"https://github.com/{REPO}/releases/download/{TAG}"
raw = f"https://raw.githubusercontent.com/{REPO}/main"
if SUBDIR:
    raw = f"{raw}/{quote(SUBDIR)}"

apps = json.load(open(MARKET / "apps.json"))
man = {m["id"]: m for m in json.load(open(BASE.parent.parent / "wanos-apps" / "manifest.json"))}
extra = json.load(open(BASE / "manifest-extra.json"))
text = json.load(open(BASE / "manifest-text-resources.json"))
rew = json.load(open(BASE / "rewrite-report-v2.json"))

extra_by_id = {}
for f in extra["files"]:
    extra_by_id.setdefault(f["id"], []).append(f)
icons = {i["id"]: i for i in text["icons"]}
scripts = {(s["id"], s["kind"]): s for s in text["scripts"]}

out_apps = []
counts = {"pkg": 0, "install": 0, "update": 0, "uninstall": 0, "icon": 0}
for a in apps["apps"]:
    b = dict(a)
    aid = a["id"]
    if aid in EXCLUDED:
        continue
    # package: manifest (50) first, then extra files that are install packages.
    # baidupan: the current install.sh uses v8, the manifest only had v7.
    pkg = None
    if aid in man:
        pkg = man[aid]["filename"]
    primary_extra = {
        "adguard-home": "AdGuardHome_linux_armv7_v0.107.76.tar.gz",
        "ddns-go": "ddns-go_6.13.3_linux_armv7.tar.gz",
        "picoclaw": "picoclaw_Linux_armv7.tar.gz",
        "phddns": "phddns_armv7_5.1.0-wanos.2.tar.gz",
        "v2ray-proxy": "v2ray-proxy_v5.6.0_armv7_wanos.1.tar.gz",
        "xiaoya-alist": "xiaoya-alist_armv7.tar.gz",
        "jiedianxiaobao": "jiedianxiaobao_armv7.tar.gz",
        "gopeed": "gopeed_armv7.tar.gz",
        "kodbox": "kodbox-main_20260604.zip",
        "tailscale": "tailscale_1.98.4_arm.tgz",
        "chromium-headless": "chromium_90.0.4430.212-1~deb10u1_armhf.deb",
        "baidupan-client": "baidupan-client-linux-armv7-v8",
    }
    if aid in primary_extra:
        pkg = primary_extra[aid]
    if pkg:
        b["package_url"] = f"{release}/{pkg}"
        counts["pkg"] += 1
    # all mirrored files for this app (manifest + extra), for the site/downloads
    mine = []
    if aid in man:
        m = man[aid]
        mine.append({"filename": m["filename"], "url": f"{release}/{m['filename']}",
                     "sha256": m["sha256"], "size_bytes": m.get("size_bytes")})
    for f in extra["files"]:
        if f["id"] == aid:
            mine.append({"filename": f["filename"], "url": f"{release}/{f['filename']}",
                         "sha256": f["sha256"], "size_bytes": f["size_bytes"],
                         "category": f["category"]})
    if mine:
        b["packages_github"] = mine
    # wallpaper armv7: manifest/API SHA 592ef6a1... is stale (server updated the file);
    # twice-verified actual SHA 090e697a... - shown on the site so verification matches.
    if aid == "wanos-wallpaper":
        b["package_sha256"] = "090e697af5013fa9bf38f7b3d1e1a152005cd79b9a71aeb4b55867d4baa16cd6"
    # install script (rewritten) - lives under github-mirror/ in the repo
    if aid in rew:
        b["install_url"] = f"{raw}/github-mirror/install-scripts-github/{aid}.sh"
        p = BASE / "install-scripts-github" / f"{aid}.sh"
        b["install_sha256"] = hashlib.sha256(p.read_bytes()).hexdigest()
        counts["install"] += 1
    # update / uninstall (git-tracked text)
    if (aid, "update") in scripts:
        b["update_url"] = f"{raw}/github-mirror/update-uninstall/{aid}-update.sh"
        counts["update"] += 1
    if (aid, "uninstall") in scripts:
        b["uninstall_url"] = f"{raw}/github-mirror/update-uninstall/{aid}-uninstall.sh"
        counts["uninstall"] += 1
    # rewrite any other WanOS URL left in the copied app dict (packages[] multi-arch
    # lists, wpk url, etc.) when its filename is in the mirror set
    mirror_filenames = {m["filename"] for m in man.values()} | {f["filename"] for f in extra["files"]}
    def _rw(v):
        if isinstance(v, str) and ("wanos.xyz" in v or "wxqun988" in v):
            fn = v.rstrip("/").split("/")[-1]
            if fn in mirror_filenames:
                return f"{release}/{fn}"
            return v
        if isinstance(v, dict):
            return {k: _rw(x) for k, x in v.items()}
        if isinstance(v, list):
            return [_rw(x) for x in v]
        return v
    b = _rw(b)
    # icon (git-tracked, under github-mirror/)
    if aid in icons:
        ext = icons[aid]["file"].split(".")[-1]
        b["icon"] = f"{raw}/github-mirror/icons/{aid}.{ext}"
        counts["icon"] += 1
    out_apps.append(b)

doc = {
    "repo_placeholder": REPO,
    "tag": TAG,
    "note": ("WanOS 官网资源离线镜像目录：安装包走 GitHub Releases，install/update/uninstall "
             "脚本与图标进 git（raw 链接）。原官方地址见 app-store-api-20260721.json / apps.json。"
             "3 个手动 .wpk（凤凰秀直播、直播源管理、YT直播）按用户要求排除在外，无公网地址。"
             + (f"文本文件在仓库的“{SUBDIR}”目录下。" if SUBDIR else "")),
    "total": len(out_apps),
    "rewritten_counts": counts,
    "excluded": [
        {"id": "home-assistant",
         "reason": "暂时排除（用户 2026-11-06 决定）：面板 Go 后端 wanos-hass-panel-linux-armv7 已从官网下线，本地 483 MB 离线包只有镜像 tar、走旧安装分支，改写后脚本会在下载面板二进制那步 fatal 退出，HA 本体也装不上。483 MB 包与面板前端包仍在本地备份，未删除。",
         "re_add": "从已装 HA 的设备取 /opt/wanos/apps/home-assistant/hass-panel-go/wanos-hass-panel，以 wanos-hass-panel-linux-armv7 之名补进 Release；或改脚本让旧分支容忍面板后端缺失；然后把 home-assistant 从本文件与 rewrite-offline.py、build-release-files.py 的 EXCLUDED 里去掉，重跑三个生成器。"},
    ],
    "mirror_gaps": [g for g in extra.get("unavailable_wanos_files", []) if g["id"] not in EXCLUDED] + [
        {"id": "tiantang", "filename": "install.sh",
         "url": "https://wanos.xyz/downloads/apps/tiantang/install.sh",
         "reason": "官方 install.sh 本身已损坏：多余 fi（168 行）+ 尾部重复 UUID 块 + 孤立 '; then' 片段（206-211 行），sh/bash -n 均报错，官方安装无法执行；重新下载核对字节一致，确为上游文件。镜像版已按 1-167 + 171-177 + 179-198 行重组，bash -n 通过，仅此一处改动。"},
    ],
    "apps": out_apps,
}
(BASE / "app-store-github.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2))
print("total", len(out_apps), counts)
print("gaps:", len(doc["mirror_gaps"]))
