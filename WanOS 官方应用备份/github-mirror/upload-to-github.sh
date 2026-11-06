#!/usr/bin/env bash
# 把 WanOS 官网资源离线镜像传到 aabacada/wankeyunwanos：
# 文本进仓库的 "WanOS 官方应用备份" 目录，大文件走同一个 Release。
# 需要先 gh auth login（账号 aabacada）。在 ~/workspace/wanos-market/ 下执行。
set -euo pipefail
REPO="aabacada/wankeyunwanos"
DIR="WanOS 官方应用备份"
TAG="wanos-armv7-20261106"
WORK="$HOME/workspace/wankeyunwanos"

# 0) 生成脚本与目录已按真实仓库名 + 子目录生成过（REPO=aabacada/wankeyunwanos
#    SUBDIR="WanOS 官方应用备份"）；改动后重跑：
#    REPO="$REPO" python3 github-mirror/rewrite-offline.py
#    REPO="$REPO" SUBDIR="$DIR" python3 github-mirror/build-catalog-github.py
#    python3 github-mirror/build-release-files.py

# 1) 文本文件进仓库（约 4 MB：67 个 install.sh、129 个 update/uninstall 脚本、67 个图标、目录与克隆站页面）
#    先克隆已有仓库（里面已有固件与 1.txt 等内容，不要 git init 覆盖），再同步子目录。
# git clone "https://github.com/$REPO.git" "$WORK"
# rsync -a --delete ~/workspace/wanos-market/ "$WORK/$DIR"/
# cd "$WORK" && git add "$DIR" \
#   && git commit -m "WanOS mirror: WanOS-official resources, offline (Releases + raw)" \
#   && git push origin main

# 2) 建 Release 并上传 128 个大文件（共约 1.76 GiB，视网速而定），全部在同一个 Release 里
#    49 个主安装包 + 47 个额外官网文件 + 32 个脚本用图标；单个文件都 <2 GB，最大约 133 MB（Home Assistant 已暂时排除）。
#    清单 github-mirror/release-files.txt 里是全部 128 个文件（已核对都在本地）。
# cd ~/workspace/wanos-market
# gh release create "$TAG" --repo "$REPO" --title "WanOS armv7 2026-11-06 (offline mirror)" \
#   --notes-file github-mirror/README.md $(cat github-mirror/release-files.txt)

# 3) 核对
# gh release view "$TAG" --repo "$REPO"   # 应为 128 个附件
# curl -I "https://github.com/$REPO/releases/download/$TAG/ntfy-linux-armv7-v2.25.0"
# curl -fsSL "https://raw.githubusercontent.com/$REPO/main/WanOS%20%E5%AE%98%E6%96%B9%E5%BA%94%E7%94%A8%E5%A4%87%E4%BB%BD/github-mirror/install-scripts-github/ntfy.sh" | head -n 5
echo "已按 aabacada/wankeyunwanos 配好：先 gh auth login，再按上面 1、2、3 步跑（命令都在注释里）"
