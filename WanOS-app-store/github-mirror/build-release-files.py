#!/usr/bin/env python3
"""Build github-mirror/release-files.txt: the files for `gh release create`.
Sources: manifest.json (50 main packages), manifest-extra.json (48 extra files),
script-referenced icons in install-scripts-github/ (32 pngs).
home-assistant is excluded (see EXCLUDED; user choice 2026-11-06 - its panel Go
backend is gone from WanOS CDN and the install would fatal). Main-package paths
are absolute because those files live outside the repo in ../../wanos-apps/.
"""
import json, pathlib, re

EXCLUDED = {"home-assistant"}
TAG = "wanos-armv7-20261106"
BASE = pathlib.Path(__file__).parent
MARKET = BASE.parent

files = []
for m in json.load(open(MARKET.parent / "wanos-apps" / "manifest.json")):
    if m["id"] in EXCLUDED:
        continue
    files.append(f"/home/hatch/workspace/wanos-apps/{m['id']}/{m['filename']}")
for f in json.load(open(BASE / "manifest-extra.json"))["files"]:
    if f["id"] in EXCLUDED:
        continue
    files.append(f"github-mirror/extra-downloads/{f['id']}/{f['filename']}")
icons = set()
for p in (BASE / "install-scripts-github").glob("*.sh"):
    for m in re.finditer(rf"releases/download/{TAG}/([^\s\"'\)}}]+\.png)", p.read_text(errors="ignore")):
        icons.add(f"github-mirror/icons/{m.group(1)}")
files += sorted(icons)
missing = [f for f in files if not (pathlib.Path(f).exists() if f.startswith("/") else (MARKET / f).exists())]
assert not missing, missing
total = sum((pathlib.Path(f) if f.startswith("/") else MARKET / f).stat().st_size for f in files)
(BASE / "release-files.txt").write_text("\n".join(files) + "\n")
print(f"files: {len(files)} total: {total} bytes = {total/1073741824:.2f} GiB")
