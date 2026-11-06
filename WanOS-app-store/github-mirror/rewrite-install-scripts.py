#!/usr/bin/env python3
"""Rewrite install.sh package URLs to GitHub Releases.
Usage: REPO=USER/NAME TAG=wanos-armv7-20261106 python3 rewrite-install-scripts.py
Edit REPO/TAG below, or set env vars.
Reads ../wanos-apps/install-scripts/*.sh, writes install-scripts-github/*.sh
Only URLs whose filename is one of the 50 downloaded packages are rewritten;
icons / other-arch / extra packages are left pointing at the official CDN (see README).
"""
import json, os, pathlib, re, hashlib
REPO = os.environ.get("REPO", "YOUR_USER/YOUR_REPO")
TAG = os.environ.get("TAG", "wanos-armv7-20261106")
BASE = pathlib.Path(__file__).parent
SRC = BASE.parent.parent / "wanos-apps" / "install-scripts"
DST = BASE / "install-scripts-github"
MAN = BASE.parent.parent / "wanos-apps" / "manifest.json"
filenames = {m["filename"] for m in json.loads(MAN.read_text())}
filenames.add("wano--2048.wpk")
base = f"https://github.com/{REPO}/releases/download/{TAG}"
DST.mkdir(parents=True, exist_ok=True)
stats = {}
for p in sorted(SRC.glob("*.sh")):
    t = p.read_text(errors="ignore")
    orig = t
    def repl(m):
        url = m.group(0)
        fn = url.rstrip("}").split("/")[-1].strip('}"\'')
        if "$" in fn or fn not in filenames:
            return url
        return f"{base}/{fn}"
    t = re.sub(r"https?://(?:wxqun988\.vxjuejin\.com|wanos.xyz)/[^\s\"\'\)}]+", repl, t)
    (DST / p.name).write_text(t)
    stats[p.stem] = {"changed": t != orig, "sha256": hashlib.sha256(t.encode()).hexdigest()}
    print(p.stem, "changed" if t != orig else "unchanged")
pathlib.Path(BASE / "rewrite-report.json").write_text(json.dumps(stats, ensure_ascii=False, indent=2))
print(f"done: {sum(1 for v in stats.values() if v['changed'])}/{len(stats)} changed")
