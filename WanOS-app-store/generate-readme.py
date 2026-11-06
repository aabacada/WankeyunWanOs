#!/usr/bin/env python3
"""Regenerate the "应用目录" section of README.md from the mirror catalog.

Reads github-mirror/app-store-github.json (77 apps) and rebuilds the table
between the <!-- APPS:START --> and <!-- APPS:END --> markers in README.md:
icon | name | description | version | Release package | install script.
README itself cannot do the official market's cards/buttons, so the table
carries the same information: image, name, introduction, Release address.
Icons are the git-tracked raw URLs from the catalog; apps without a real
icon (device built-ins, text glyphs) show "—". Apps without a package show
"—" under 安装包 and are installed via their install script instead.
Usage: python3 generate-readme.py
"""
import json, pathlib

BASE = pathlib.Path(__file__).parent
CAT = BASE / "github-mirror" / "app-store-github.json"
README = BASE / "README.md"

def cell(t):
    return " ".join(str(t or "").split()).replace("|", "\\|") or "—"

def main():
    d = json.loads(CAT.read_text())
    apps = d["apps"]
    n_pkg = sum(1 for a in apps if a.get("package_url"))
    n_inst = sum(1 for a in apps if a.get("install_url"))
    lines = [
        f"共 {len(apps)} 个应用（镜像目录；{n_pkg} 个有安装包，{n_inst} 个有安装脚本）。",
        "安装包链接指向 GitHub Releases 附件，安装脚本链接指向改写后的 raw 脚本，在 WanOS 设备上以 root 执行即可安装。安装包一栏为空的请用安装脚本安装；图标为空的是设备内置应用。",
        "",
        "| 图标 | 应用 | 介绍 | 版本 | 安装包 | 安装脚本 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for a in apps:
        icon = a.get("icon") or ""
        img = f'<img src="{icon}" width="48" alt="{a.get("name", "")}">' if icon.startswith("http") else "—"
        pkg = f"[下载]({a['package_url']})" if a.get("package_url") else "—"
        inst = f"[安装]({a['install_url']})" if a.get("install_url") else "—"
        lines.append(
            f"| {img} | **{cell(a.get('name'))}** | {cell(a.get('description'))} "
            f"| {cell(a.get('version'))} | {pkg} | {inst} |"
        )
    body = "\n".join(lines)
    text = README.read_text()
    start = text.index("<!-- APPS:START -->")
    end = text.index("<!-- APPS:END -->")
    new = text[: start + len("<!-- APPS:START -->")] + "\n" + body + "\n" + text[end:]
    README.write_text(new)
    print(f"wrote README.md app catalog: {len(apps)} rows ({n_pkg} with package, {n_inst} with install script)")

if __name__ == "__main__":
    main()
