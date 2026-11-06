#!/usr/bin/env python3
"""Download the extra WanOS-CDN files needed for a 100% WanOS-CDN offline mirror.
Excludes the 3 manual .wpk apps (fengshows-live, live-manager, yt-live) - they have
no public URL / install.sh and are not in this list.
Excludes (documented gaps, not downloadable from WanOS CDN):
 - OnlyOffice assets zip: both CDN hosts return a 20KB HTML page, script itself
   says remote download is disabled and the zip must be supplied locally.
 - WiFi vendor drivers (42 entries, ~415 MiB): TP-Link/Tenda/Mercury/Netcore sites,
   per-hardware on-demand catalog embedded in wanos-wifi-drivers.sh, not WanOS CDN.
Writes extra-downloads/<app>/<filename> + manifest-extra.json with sha256/size.
Usage: python3 download-extra.py  (rerun skips files whose sha matches expected)
"""
import hashlib, json, pathlib, subprocess, sys

BASE = pathlib.Path(__file__).parent
OUT = BASE / "extra-downloads"
OUT.mkdir(parents=True, exist_ok=True)

# (app_id, url, expected_sha256 or None, category)
ITEMS = [
 # --- extra armv7 / main install files (not in the original 50) ---
 ("adguard-home", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/adguard-home/AdGuardHome_linux_armv7_v0.107.76.tar.gz", "0c60e959fc9ef0c8a0a728961390e6f77cbc9fcd8f3de07646be52cefe68d988", "extra-armv7"),
 ("ddns-go", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/ddns-go/ddns-go_6.13.3_linux_armv7.tar.gz", None, "extra-armv7"),
 ("picoclaw", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/picoclaw/picoclaw_Linux_armv7.tar.gz", None, "extra-armv7"),
 ("phddns", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/phddns/phddns_armv7_5.1.0-wanos.2.tar.gz", "21a929b82b32c0d5c16123df2abcf4e01f5361902291a74f45dd66eb08b92f29", "extra-armv7"),
 ("v2ray-proxy", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/v2ray-proxy/v2ray-proxy_v5.6.0_armv7_wanos.1.tar.gz", "609d2c9ddccf9e1bf0577fe70c9e6d214e3645f2ef9bd776de709fb4fd599041", "extra-armv7"),
 ("xiaoya-alist", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/xiaoya-alist/xiaoya-alist_armv7.tar.gz", "6566864ffc09cc3f7b7976ea5539097fb1a9a24674bb990d6b0d00d4f5dc15dd", "extra-armv7"),
 ("jiedianxiaobao", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/jiedianxiaobao/jiedianxiaobao_armv7.tar.gz", "17354e719c1ee9c09afb3af0f1651af7731b3974f164f368b4eed46a7658c4c9", "extra-armv7"),
 ("gopeed", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/gopeed/gopeed_armv7.tar.gz", "963dbce2dc7c11c6488e5d70e7ae8ee2e09a32f333e8454d72d8ce193370a1d0", "extra-armv7"),
 ("kodbox", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/kodbox/kodbox-main_20260604.zip", "a737f0e8a88efed6f97a2adec30cc92463995b1c7442abbd5c10f4dd2492907e", "extra-armv7"),
 ("cups-print", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/cups-print/cups-print-driver-library_ubuntu20.04_armhf_v1.tar.gz", "d2ecd61b26483b7d10123ddec0146befea105853105ebfdf978e1e73816db57d", "extra-armv7"),
 ("cups-print", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/cups-print/cups-web-linux-armv7-v33", "65ebbfcdfd5cecec1886ca54e29968f18fcc1c47f114e4f57813fc4156f17c7f", "extra-armv7"),
 ("nut-ups", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/nut-ups/nut-ups-offline-armhf-ubuntu20.04.tar.gz", "50a9d045f73553abbd80cd65fe263bdc2491818ac3e533988666052d0aa7b86c", "extra-armv7"),
 ("home-assistant", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/hass-panel/hass-panel-armv7-offline.tar.gz", None, "extra-armv7"),
 ("tailscale", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/tailscale/tailscale_1.98.4_arm.tgz", "18d4568fe5c72ac31fdac4a8af233770a0357673e6a32f315d04eb0453f495bd", "extra-armv7"),
 ("chromium-headless", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/chromium-headless/chromium_90.0.4430.212-1~deb10u1_armhf.deb", "eef2f574e7fcd02bb5b01ee00fdf9c9c574b4b2a79a2de6de5d96fa1170bc7d6", "extra-armv7"),
 ("chromium-headless", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/chromium-headless/chromium-sandbox_90.0.4430.212-1~deb10u1_armhf.deb", "cced3cf25598430164722f71aecdacca58bb83c139a075338538b964221e5746", "extra-armv7"),
 ("chromium-headless", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/chromium-headless/chromium-common_90.0.4430.212-1~deb10u1_armhf.deb", "e758babcb6ca0155a73cf732a56f1af0d8af1ceec864121420fbc0d0be3c4dbf", "extra-armv7"),
 ("linkease", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/linkease/linkmount-arm.zip", "eb08439f15bfaada23c7c733c5ad3876ea60e613745b95cbef5a5ad1383593fe", "extra-armv7"),
 # baidupan v8: current install.sh uses v8, manifest only had v7
 ("baidupan-client", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/baidupan-client/baidupan-client-linux-armv7-v8", "680b421fc5dec8ff644e85391212f206235f45f08889c2b556c42cdc1b754899", "extra-armv7"),
 ("baidupan-client", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/baidupan-client/baidupan-client-linux-arm64-v8", "5fa4572b953734845d1fa86020317748e7407ffda7cf228f21504791ed9551dc", "other-arch"),
 ("baidupan-client", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/baidupan-client/baidupan-client-linux-amd64-v8", "0e3cb8a7342fc7bfa78280f8bc22f48ad3eb49dd382ffa63cd6d545ae00b5828", "other-arch"),
 # --- other architectures (scripts select by uname -m) ---
 ("xunlei", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/xunlei/xunlei-linux-amd64-v2", "c19aa2f3", "other-arch"),  # prefix only in API; full sha checked after download
 ("webview-tv-live", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/webview-tv-live/webview-tv-live-linux-arm64-v2", "7b77d090", "other-arch"),
 ("webview-tv-live", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/webview-tv-live/webview-tv-live-linux-amd64-v2", "0db9e290", "other-arch"),
 ("wanos-wallpaper", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/wanos-wallpaper-linux-arm64-v4", "56dce072a6f144b1228ad386ddccec7f598c36849bc5cdabaaa5c1a968845757", "other-arch"),
 ("wanos-wallpaper", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/wanos-wallpaper-linux-amd64-v4", "f9d40cc489e8237de1fcfcb5ebcc9949138d8a7762d4e10bb4e5d30c1f47a8a0", "other-arch"),
 ("m3u8-downloader", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/m3u8-downloader/m3u8-downloader-linux-arm64-v3", "b1a071af", "other-arch"),
 ("m3u8-downloader", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/m3u8-downloader/m3u8-downloader-linux-amd64-v3", "6bbcb83f", "other-arch"),
 ("happy-guandan", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/happy-guandan/happy-guandan-linux-arm64-v3", "996980c35aaf269c88e39dbe277a675a07cb888569a0e79a1a5e148cb1504f49", "other-arch"),
 ("happy-guandan", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/happy-guandan/happy-guandan-linux-amd64-v3", "3c02ced7060423a6b1bcbf79e0ef4eeeb777dbe5d3955e3e4b0111fc00e111fe", "other-arch"),
 ("lanzoupan-client", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/lanzoupan-client/lanzoupan-client-linux-arm64-v1", "befba42c", "other-arch"),
 ("lanzoupan-client", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/lanzoupan-client/lanzoupan-client-linux-amd64-v1", "82092602", "other-arch"),
 ("easytier", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/easytier/easytier-linux-aarch64-v2.6.4.zip", "f533ec25", "other-arch"),
 ("easytier", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/easytier/easytier-linux-x86_64-v2.6.4.zip", "61b659ea", "other-arch"),
 ("wanos-ai-assistant", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-ai-assistant/wanos-ai-assistant-linux-arm64-v6", "e08282cd", "other-arch"),
 ("wanos-ai-assistant", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-ai-assistant/wanos-ai-assistant-linux-amd64-v6", "b35b8dcb", "other-arch"),
 ("wanos-wifi-drivers", "https://wxqun988.vxjuejin.com/wanos/downloads/components/wifi-drivers/wanos-wifi-drivers-linux-arm64-v1.tar.gz", "a4d5465e5815d47928f2ce0afeb310b2b325cd8d33ae0afaec5c401998d36e6f", "other-arch"),
 ("wanos-wallpaper", "https://wxqun988.vxjuejin.com/wanos/downloads/wpk/wanos-wallpaper_20260718_v4.wpk", "aba429df4ef17b08db5ce52568d5aabbc4582ea98240e74208a8c6809fd9e4ac", "wpk"),
 # --- panel / helper scripts hosted on WanOS CDN ---
 ("tailscale", "https://wanos.xyz/downloads/apps/tailscale/tailscale-panel.py", None, "panel"),
 ("minidlna", "https://wanos.xyz/downloads/apps/minidlna/minidlna-panel.py", None, "panel"),
 ("nut-ups", "https://wanos.xyz/downloads/apps/nut-ups/nut-panel.py", "8dca6b1df13fd28375d5380e062e980a4b663e09c1b8d53609b101edba1da8b8", "panel"),
 ("xiaoya-alist", "https://wanos.xyz/downloads/apps/xiaoya-alist/xiaoya-panel.py", None, "panel"),
 ("xiaoya-alist", "https://wanos.xyz/downloads/apps/xiaoya-alist/xiaoya-cleanup.sh", None, "panel"),
 ("wanos-wallpaper", "https://wxqun988.vxjuejin.com/wanos/wallpapers/netbian/index.json", None, "panel"),
 # --- icons (only those NOT already in wanos-apps/icons/) ---
 ("chromium-headless", "https://wanos.xyz/downloads/apps/chromium-headless/chromium.png", None, "icon"),
 ("minecraft-java", "https://wanos.xyz/downloads/apps/minecraft-java/minecraft.png", None, "icon"),
 ("happy-guandan", "https://wanos.xyz/downloads/apps/happy-guandan/icon.png", None, "icon"),  # wanos.xyz host works; wxqun988 404s
 ("wanos-wallpaper", "https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/icon-v3.png", None, "icon"),
 # NOTE: Mojang server.jar intentionally NOT mirrored - public internet resource,
 # user scope 2026-11-06: only WanOS-official resources are mirrored.
]

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()

results, failures = [], []
for app, url, exp, cat in ITEMS:
    fn = url.rstrip("/").split("/")[-1]
    dest = OUT / app / fn
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and exp and len(exp) == 64 and sha256(dest) == exp:
        print(f"skip ok {app}/{fn}")
    else:
        r = subprocess.run(["curl", "-fL", "--connect-timeout", "20", "--retry", "2",
                            "-o", str(dest), url], capture_output=True, text=True)
        if r.returncode != 0:
            print(f"FAIL {app}/{fn} {url} :: {r.stderr.strip()[-200:]}")
            failures.append({"id": app, "filename": fn, "url": url, "category": cat, "error": r.stderr.strip()[-200:]})
            if dest.exists():
                dest.unlink(missing_ok=True)
            continue
    got = sha256(dest)
    size = dest.stat().st_size
    ok = True
    if exp:
        ok = got.startswith(exp) if len(exp) < 64 else got == exp
    status = "sha-ok" if ok else "SHA-MISMATCH"
    if not ok:
        failures.append({"id": app, "filename": fn, "url": url, "category": cat, "expected": exp, "got": got})
    print(f"{status} {app}/{fn} {size} bytes sha={got[:16]}...")
    results.append({"id": app, "filename": fn, "url": url, "category": cat,
                    "sha256": got, "size_bytes": size, "status": status})

total = sum(r["size_bytes"] for r in results)
manifest = {"total_files": len(results), "total_bytes": total,
            "total_mib": round(total / 1048576, 1), "failures": failures, "files": results}
(BASE / "manifest-extra.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
print(f"done: {len(results)} ok, {len(failures)} failures, total {total} bytes ({total/1048576:.1f} MiB)")
sys.exit(1 if failures else 0)
