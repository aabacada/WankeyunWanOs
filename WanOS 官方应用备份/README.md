# WanOS 应用市场（镜像）

一个可直接托管到 GitHub / GitHub Pages 的 WanOS 应用市场克隆，**含官网资源离线镜像**：安装包走 GitHub Releases，安装 / 更新 / 卸载脚本与图标走 GitHub raw，官网下线后仍可安装。3 个手动 `.wpk`（凤凰秀直播、直播源管理、YT直播）按要求排除在外。详情与缺口见 `github-mirror/README.md`。

## 里面有什么

| 文件 | 说明 |
| --- | --- |
| `index.html` | 静态应用市场页：搜索、按分类筛选、按“有安装包 / 有 .wpk / 已安装”筛选，打开即用，无需构建 |
| `apps.json` | 合并后的应用目录，81 个应用（见下） |
| `app-store-api-20260721.json` | 官方 API 原始快照，`https://wxqun988.vxjuejin.com/wanos/api/app-store`，更新于 2026-07-21 |
| `update.sh` | 重新拉取官方 API、重新生成 `apps.json` 的脚本 |
| `.nojekyll` | GitHub Pages 用，告诉 GitHub 不要用 Jekyll 处理 |
| `armv7-apps.json` / `armv7-apps.md` | 玩客云 armv7 能用的应用单独整理：API 71 个中能用 70 个（有 armv7 安装包 48 个、.wpk 1 个、走 install.sh 19 个、已内置 2 个），排除迅雷 1 个；`index.html` 已加“仅 ARMv7 能用”筛选 |
| `generate-armv7.py` | 从 `armv7-apps.json` 重新生成 `armv7-apps.md` 的脚本 |
| `github-mirror/` | 传 GitHub 的离线镜像：67 个改写后 install.sh（官方 CDN 引用 0 个）、129 个 update/uninstall 脚本、67 个图标、47 个额外官网文件（`manifest-extra.json`）、`app-store-github.json`（80 个应用，安装包/脚本/图标地址全改成 GitHub；Home Assistant 已暂时排除）、`upload-to-github.sh` 与 `release-files.txt`（128 个 Release 文件，约 1.76 GiB） |

## 数据

- 官方 API：71 个应用，含名称、简介、分类、图标、端口、安装/更新/卸载脚本链接及 SHA256、多架构安装包链接及 SHA256、标签、下载量。
- 设备导出（2026-11-06，`upload.md`）：81 个应用，补上 API 里没有的 10 个内置/手动安装应用（Alist、计算器、记事本、WanOS 音乐、媒体播放、下载中心、相册、凤凰秀直播、直播源管理、YT直播），以及 18 个“设备已安装”状态。
- 合并后：**81 个应用，50 个带安装包直链，68 个带安装脚本，1 个带官方 .wpk（WanOS 壁纸）**。
- 版本差异：API（2026-07-21）和设备导出（2026-11-06）核对过，71 个重叠应用的版本号没有差异。

## 为什么安装包走 Releases

50 个主安装包共约 1.69 GiB，其中 Home Assistant 483 MB、New API 133 MB、青龙 103 MB 都超 GitHub 100 MB 单文件上限，整批也超 1 GB 仓库建议值；加上本轮补下的 47 个额外官网文件（48 个已下载，HA 面板前端包已排除）与 32 个图标，Release 共 128 个文件、约 1.76 GiB，单个文件都 <2 GB。
所以文本（脚本、图标、目录、页面，约 4 MB）直接 `git push`，大文件走 GitHub Releases。`index.html` 读的是镜像目录 `github-mirror/app-store-github.json`，点“下载安装包”从 Releases 下，点“安装脚本”从 raw 下，不再经过官网 CDN。原始官方目录仍保留在 `apps.json`。

## 托管到 GitHub

目标仓库 `aabacada/wankeyunwanos`（main 分支），文本文件放在 `WanOS 官方应用备份` 目录下：

```bash
git clone https://github.com/aabacada/wankeyunwanos.git ~/workspace/wankeyunwanos
rsync -a --delete ~/workspace/wanos-market/ ~/workspace/wankeyunwanos/"WanOS 官方应用备份"/
cd ~/workspace/wankeyunwanos
git add "WanOS 官方应用备份"
git commit -m "WanOS mirror: WanOS-official resources, offline (Releases + raw)"
git push origin main
```

注意：市场页在子目录里，GitHub Pages 只能从仓库根目录或 `/docs` 发布，所以这个布局下 Pages 不能直接当网站用，只能在仓库文件浏览器里打开 `index.html` 所在目录查看；要当网站用的话需另建仓库放根目录。

## 在 WanOS 设备上安装

在卡片上点“安装脚本”查看，或在设备上以 root 执行，例如（地址为改写后的 GitHub raw 脚本，包从 Releases 下）：

```sh
curl -fsSL https://raw.githubusercontent.com/aabacada/wankeyunwanos/main/WanOS%20%E5%AE%98%E6%96%B9%E5%BA%94%E7%94%A8%E5%A4%87%E4%BB%BD/github-mirror/install-scripts-github/openlist.sh | sh
```

“复制安装命令”按钮就是复制这行。不要在非 WanOS、非 ARMv7 设备上跑这些脚本。

## 更新目录

```bash
./update.sh
```

它会重新拉取官方 API，重新生成 `apps.json`（需要联网；设备导出那 10 个应用和已安装状态会保留在生成逻辑里，见脚本注释）。

## 声明

- 非官方项目，与 WanOS 官方无关。
- 目录数据来自公开、无需登录的官方 API 和用户自己设备的导出；安装包与脚本已按 `github-mirror/README.md` 的方案改写为 GitHub 地址重传（非官方镜像，有被投诉下架的可能）。
- 官方目录更新后，以官方为准；本镜像的 `apps.json` 需要定期跑 `update.sh` 同步；镜像缺口（3 个官网文件下不到、甜糖脚本官方已损坏已修）见 `github-mirror/README.md`。
