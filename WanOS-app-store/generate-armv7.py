#!/usr/bin/env python3
"""Regenerate armv7-apps.md from armv7-apps.json. Source of truth is the JSON."""
import json, pathlib
BASE = pathlib.Path(__file__).parent
d = json.loads((BASE / "armv7-apps.json").read_text(encoding="utf-8"))
apps = d["apps"]

def fmt_mb(b):
    return f"{b/1024/1024:.1f} MB" if b else ""

def table(title, tier):
    rows = [x for x in apps if x["tier"] == tier]
    lines = [f"## {title}（{len(rows)} 个）\n"]
    lines.append("| 应用 | ID | 版本 | 端口 | 大小 | 安装包 / 安装方式 |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    for x in sorted(rows, key=lambda y: y["id"]):
        if x["tier"] == "wpk":
            link = f"[下载 .wpk]({x['package_url']})"
        elif x["package_url"]:
            link = f"[下载]({x['package_url']})"
        elif x["install_url"]:
            link = f"[安装脚本]({x['install_url']})"
        else:
            link = "已内置"
        size = x.get("size_display") or fmt_mb(x.get("download_size_bytes") or 0)
        lines.append(f"| {x['name']} | `{x['id']}` | {x.get('version') or '—'} | {x.get('port') or '—'} | {size or '—'} | {link} |")
    lines.append("")
    for x in sorted(rows, key=lambda y: y["id"]):
        if x["tier"] == "package":
            sha = x.get("package_sha256") or ""
            ver = "已下载校验通过" if x.get("download_verified") else ("SHA 与清单不符（实测 090e697a…，服务端已更新）" if x["id"] == "wanos-wallpaper" else "未下载")
            lines.append(f"- **{x['name']}** `{x['id']}`：{ver}；SHA256 `{sha[:16]}…`；{x.get('armv7_evidence','')}")
    lines.append("")
    return "\n".join(lines)

md = []
md.append("# 玩客云 armv7 能用的应用（单独整理）\n")
md.append("来源：本地已下载的官方应用目录 `app-store-api-20260721.json`（`https://wxqun988.vxjuejin.com/wanos/api/app-store`，71 个应用，更新于 2026-07-21），加设备导出（2026-11-06）核对已安装状态。\n")
md.append("## 结论\n")
md.append("- API 共 71 个，**armv7 能用 70 个**，排除 1 个：**迅雷**（见下）。\n")
md.append("- 有 armv7 安装包直链 48 个（已全部下载到 `workspace/wanos-apps/` 并校验，48 个中 47 个 SHA 通过，1 个壁纸 SHA 与清单不符）；.wpk 直链 1 个（2048）；无直链、走 install.sh 安装 19 个；已内置、无需安装 2 个。\n")
md.append("- 筛选标准：API `architectures` 含 armv7 / linux-armv7，或有 linux-armv7 安装包，或 install.sh 明确支持 armv7/armhf，或为 armv7 .wpk / 设备内置。\n")
md.append("- 注意：本清单只看架构能不能用，不看安装方式难不难——其中 Docker 镜像类（青龙、Home Assistant、夸克自动转存、Gopeed）、PHP/系统服务类（Typecho、CUPS 等）仍需按官方 install.sh 在设备上装，不能直接改成 .wpk。\n")
md.append(table("A. 有 armv7 安装包直链", "package"))
md.append(table("B. .wpk 直链", "wpk"))
md.append(table("C. 无直链，走 install.sh 安装", "install_script"))
md.append(table("D. 已内置，无需安装", "builtin"))
md.append("## 排除的 1 个\n")
md.append("| 应用 | ID | 原因 |")
md.append("| --- | --- | --- |")
md.append("| 迅雷远程下载 | `xunlei` | architectures 仅 linux-arm64 / linux-amd64；install.sh 只认 aarch64/arm64 与 x86_64/amd64，其余架构直接报错；上游 cnk3x/xunlei 只有 amd64/arm64 包，群晖 SPK 也只有 x86_64/armv8，无 armv7 |")
md.append("")
md.append("## 设备导出里另外的 7 个（不在 API 里，不计入上面 70 个）\n")
md.append("Alist、计算器、记事本、WanOS 音乐、媒体播放、下载中心、相册（7 个内置），都在 armv7 设备上，但官方 API 里没有、无公网直链。\n")
md.append("## 文件\n")
md.append("- `armv7-apps.json`：本清单的机器可读版，含每个应用的端口、简介、安装包/安装脚本链接、SHA256、已下载校验状态。\n")
md.append("- `apps.json`：78 个应用的完整合并目录（含上面 7 个设备应用 + 迅雷）。\n")
md.append("- 克隆站 `index.html` 已加“仅 ARMv7 能用”筛选，选它就只显示这 70 个（合并目录里是 77 个，因为还含设备那 7 个）。\n")
(BASE / "armv7-apps.md").write_text("\n".join(md), encoding="utf-8")
print("wrote armv7-apps.md")
