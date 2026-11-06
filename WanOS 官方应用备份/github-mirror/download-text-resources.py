#!/usr/bin/env python3
"""Download remaining WanOS-official text resources for the offline mirror:
 - update.sh / uninstall.sh for all 71 API apps (63 update + 68 uninstall URLs)
 - API catalog icons for all 68 apps that have a URL icon
Stored under github-mirror/: update-uninstall/<id>-update.sh, <id>-uninstall.sh
and icons/<app-id>.<ext> (kept extension from URL; .svg/.jpg kept as-is).
Skips files already present. A URL returning HTML instead of a script/image is
recorded as failed, not saved. Writes manifest-text-resources.json.
"""
import hashlib, json, pathlib, subprocess

BASE = pathlib.Path(__file__).parent
api = json.load(open(BASE.parent / "app-store-api-20260721.json"))
apps = api["apps"]

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()

def fetch(url, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        return "exists"
    r = subprocess.run(["curl", "-fsSL", "--connect-timeout", "20", "--retry", "2",
                        "-o", str(dest), url], capture_output=True, text=True)
    if r.returncode != 0:
        dest.unlink(missing_ok=True)
        return f"http-fail: {r.stderr.strip()[-120:]}"
    data = dest.read_bytes()
    # HTML error page instead of the real file?
    if data[:15].lower().startswith(b"<!doctype html") or data[:6].lower() == b"<html>":
        dest.unlink()
        return "html-error-page"
    return "ok"

results, failures = [], []
for a in apps:
    for kind in ("update", "uninstall"):
        url = a.get(f"{kind}_url") or ""
        if not url:
            continue
        dest = BASE / "update-uninstall" / f"{a['id']}-{kind}.sh"
        st = fetch(url, dest)
        if st != "ok" and st != "exists":
            failures.append({"id": a["id"], "kind": kind, "url": url, "error": st})
            print(f"FAIL {a['id']} {kind}: {st}")
            continue
        results.append({"id": a["id"], "kind": kind, "url": url,
                        "file": str(dest.relative_to(BASE)),
                        "sha256": sha256(dest), "size_bytes": dest.stat().st_size})
        print(f"ok {a['id']} {kind} {dest.stat().st_size}B")

icons_ok, icons_fail = [], []
for a in apps:
    url = a.get("icon") or ""
    if not url.startswith("http"):
        continue
    ext = url.rstrip("/").split("/")[-1].split(".")[-1].lower().split("?")[0]
    if ext not in ("png", "jpg", "jpeg", "svg", "webp", "gif"):
        ext = "png"
    dest = BASE / "icons" / f"{a['id']}.{ext}"
    st = fetch(url, dest)
    if st != "ok" and st != "exists":
        icons_fail.append({"id": a["id"], "url": url, "error": st})
        print(f"ICON FAIL {a['id']}: {st}")
        continue
    icons_ok.append({"id": a["id"], "url": url, "file": str(dest.relative_to(BASE)),
                     "sha256": sha256(dest), "size_bytes": dest.stat().st_size})
    print(f"icon ok {a['id']} {dest.stat().st_size}B")

out = {"scripts": results, "scripts_failed": failures,
       "icons": icons_ok, "icons_failed": icons_fail,
       "totals": {"scripts": len(results), "scripts_bytes": sum(r["size_bytes"] for r in results),
                  "icons": len(icons_ok), "icons_bytes": sum(r["size_bytes"] for r in icons_ok)}}
(BASE / "manifest-text-resources.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
print("scripts:", len(results), "failed:", len(failures),
      "| icons:", len(icons_ok), "failed:", len(icons_fail))
