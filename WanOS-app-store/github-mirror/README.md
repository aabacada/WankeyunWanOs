# WanOS 官网资源 100% 离线镜像

结论先说：**WanOS 官方两个域名（`wxqun988.vxjuejin.com` / `wanos.xyz`）的资源已做到 100% 离线镜像**，不含 2026-11-06 暂时排除的 Home Assistant（见下）。按用户 2026-11-06 的口径，公开互联网资源（Mojang、apt、Docker Hub、厂商驱动、OpenAI 等）**不**镜像，脚本里仍走原地址。

## 镜像了什么

| 东西 | 数量 | 大小 | 怎么传 |
| --- | --- | --- | --- |
| 主安装包（清单 51 个） | 51 | 约 1.70 GiB | GitHub Releases 附件 |
| 额外官网文件（本轮补下） | 47 | 约 534 MiB | GitHub Releases 附件（48 个已下载，HA 面板前端包已排除、仅本地备份） |
| 脚本里引用的图标 | 32 | 约 0.97 MiB | GitHub Releases 附件 |
| **Release 合计** | **129** | **约 1.77 GiB** | `release-files.txt` 是全部 129 个文件清单 |
| 改写后 install.sh | 67 | 约 0.4 MB | 直接 `git push`（raw 链接） |
| update / uninstall 脚本 | 129 | 约 0.34 MB | 直接 `git push` |
| 目录图标（克隆站用） | 68 | 约 3.1 MB | 直接 `git push` |
| 目录与清单（app-store-github.json 等） | — | 约 0.5 MB | 直接 `git push` |

克隆站 `index.html` 已改成读 `github-mirror/app-store-github.json`（镜像目录），按钮与安装命令都指向 GitHub，不再指向官网。

## 暂时排除：Home Assistant（2026-11-06，用户决定）

面板 Go 后端 `wanos-hass-panel-linux-armv7` 已从官网下线，本地 483 MB 离线包里只有一个镜像 tar、没有全量包标记，脚本走旧安装分支，先下已镜像的面板前端包，再下这个面板二进制——官网没有、Release 里也没有，脚本的 `download_file` 下载后校验文件非空就直接 `fatal` 退出，HA 本体也装不上。所以先把 HA 整个排除在镜像外：目录里没有它（total 80）、Release 里没有它的两个文件、改写后脚本与 update/uninstall 脚本、图标也都已移除。

本地备份没删：483 MB 离线包（`wanos-apps/home-assistant/`）与面板前端包（`extra-downloads/home-assistant/`）都在，目录 `app-store-github.json` 的 `excluded` 字段记了原因与恢复办法。恢复二选一：(a) 从已装 HA 的设备取 `/opt/wanos/apps/home-assistant/hass-panel-go/wanos-hass-panel`，以 `wanos-hass-panel-linux-armv7` 之名补进 Release；(b) 改脚本让旧分支容忍面板后端缺失。然后把 `home-assistant` 从 `rewrite-offline.py`、`build-catalog-github.py`、`build-release-files.py` 三个文件的 `EXCLUDED` 里去掉，重跑三个生成器即可。

## 本轮补下的 48 个额外官网文件

- 额外 armv7 主包 20 个：AdGuard Home、DDNS-GO、小龙虾、花生壳、V2Ray、Gopeed Docker 镜像、小雅 Alist Docker 镜像、节点小宝 Docker 镜像、KodBox、Chromium 3 个 `.deb`、Tailscale、CUPS 驱动库、CUPS Web 面板、NUT 离线包、Hass 面板前端、LinkEase 挂载包、百度网盘 v8（脚本用的已是 v8，清单里还是 v7）
- 多架构包 15 个：迅雷 amd64、WebView 壁纸 / m3u8 / 欢乐掼蛋 / 兰奏云 / EasyTier / AI 助手 / 百度网盘 v8 的 arm64 + amd64，及 WiFi 驱动 arm64
- 面板与辅助脚本 5 个：Tailscale / MiniDLNA / NUT / 小雅面板 `.py`、小雅清理 `.sh`，及壁纸索引 `netbian/index.json`
- 图标 4 个：Chromium、Minecraft、欢乐掼蛋、壁纸 `icon-v3.png`（其余 28 个图标此前已在 `wanos-apps/icons/`）
- 壁纸 `.wpk` 1 个：`wanos-wallpaper_20260718_v4.wpk`（7.8 MB，WPK v1，含 armv7/arm64/amd64 三个二进制，已验 zip 结构与 manifest）
- 其余：Hass 面板前端包等已计入上述分类

SHA256 校验：48 个全部通过（其中 Chromium 两个 `.deb` 与壁纸 arm64/amd64 的脚本内 SHA 与 API 快照不一致，以脚本内为准，实测一致；壁纸 armv7 与清单 SHA 不符是服务端已更新，实测 SHA `090e697a…` 已在目录中修正）。

## 改写规则

`install-scripts-github/`（68 个）由 `rewrite-offline.py` 从原版脚本生成：

- 所有 `wxqun988.vxjuejin.com` / `wanos.xyz` 的下载地址改成 `https://github.com/<仓库>/releases/download/wanos-armv7-20261106/<文件名>`；
- 变量型地址（`CDN_BASE`、`BASE_URL`、`BIN_BASE_URL`）的基地址也改成 Releases 根地址，`$BASE/<文件名>` 的拼接保持正确；图标因 Releases 是扁平命名空间，统一改成 `<应用id>.png`；
- Chromium 面板默认首页 `https://wanos.xyz` 改成 `about:blank`（只是浏览器打开的起始页，不是下载）；
- 公开资源不动：Mojang `server.jar`、apt-get、Docker Hub 镜像名、WiFi 厂商驱动、api.openai.com、cdnjs、tailscale.com 文档链接。

## 缺口：3 处，官网本身的问题，镜像补不上

1. **OnlyOffice assets zip 下不到**：`OnlyofficePersonal-main-local-icons.zip` 在两个官方域名上都只返回 20KB 的 HTML 错误页；脚本本身也写明远程下载已禁用，须在 WanOS 界面本地上传该 zip 才能装。镜像里留了它的 Releases 地址占位（变量是死代码，从不实际下载），文件本身无法从官网获得。
2. **WanOS 测试应用二进制下不到**：`wanos-test-app-linux-armv7` 同样是官网首页 HTML / 404，文件在官网不存在，官方安装本身已坏。这是个测试应用，影响很小。
3. **甜糖 install.sh 官方已损坏，镜像版修过**：重新下载核对字节一致，确为上游文件：168 行多一个 `fi`，尾部还有重复的 UUID 块和一段缺了开头的 `; then` 孤儿片段（206–211 行），`sh -n` / `bash -n` 都报错，官方安装无法执行。镜像版只做了这一处重组（保留 1–167 + 171–177 + 179–198 行），`bash -n` 通过。除此以外与官方逐行一致。

Home Assistant 的面板后端缺失已不列为缺口：它已被暂时排除在镜像外（见上节），不是待补的文件。

## 验证结果（2026-11-06，本地）

- 改写后 67 个脚本中 `wxqun988` / `wanos.xyz` 引用：**0 个**（`grep` 验证）。
- 67 个脚本 `bash -n` 语法检查：**全部通过**（含修过的甜糖）。
- 改写后脚本引用的 121 个不同 Releases 文件：除缺口的 2 个文件（OnlyOffice zip、测试应用二进制）外，**全部在上传清单里**（`release-files.txt` 129 个文件逐个核对都在本地）。
- update / uninstall 脚本与目录图标共下载 131 个脚本、68 个图标，**全部下载成功，0 失败**（HTML 错误页会被识别并拒收）；其中 Home Assistant 的 update/uninstall 脚本与图标（3 个文件）已从镜像内排除，镜像内为 129 个 update/uninstall 脚本、68 个图标（另有改写后 install 脚本 67 个；清理大师图标从其 .wpk 内提取，非下载）。
- 克隆站本地 HTTP 校验通过：`index.html` 200，镜像目录 total=78，其中 61 个有安装包地址。

## 上传步骤（见 upload-to-github.sh）

仓库：`aabacada/wankeyunwanos`（公开库，main 分支）。文本文件进仓库的 `WanOS-app-store` 目录，大文件走同一个 Release。

```bash
# 先 gh auth login（已在用的账号 aabacada）；目录与脚本已按真实仓库名生成过，不用再换占位符
# 1) 文本进仓库（约 4 MB）：克隆已有仓库，把本地 wanos-market/ 内容同步进子目录后推
git clone https://github.com/aabacada/wankeyunwanos.git ~/workspace/wankeyunwanos
rsync -a --delete ~/workspace/wanos-market/ ~/workspace/wankeyunwanos/"WanOS-app-store"/
cd ~/workspace/wankeyunwanos
git add "WanOS-app-store"
git commit -m "WanOS mirror: WanOS-official resources, offline (Releases + raw)"
git push origin main
# 2) 建 Release 并上传 129 个文件（约 1.77 GiB），全部在同一个 Release 里
cd ~/workspace/wanos-market
gh release create wanos-armv7-20261106 --repo aabacada/wankeyunwanos --title "WanOS armv7 2026-11-06 (offline mirror)" --notes-file github-mirror/README.md $(cat github-mirror/release-files.txt)
# 3) 核对：gh release view wanos-armv7-20261106 --repo aabacada/wankeyunwanos（应为 129 个附件），再 curl -I 抽一个附件
```

## 其他 WanOS 怎么装（传完之后）

在另一台 WanOS 设备上以 root 执行改写后的脚本，例如 ntfy：

```sh
curl -fsSL https://raw.githubusercontent.com/aabacada/wankeyunwanos/main/WanOS-app-store/github-mirror/install-scripts-github/ntfy.sh | sh
```

脚本默认就从你仓库的 Releases 下安装包。也可以直接在克隆站 `index.html` 里点“安装脚本”或复制安装命令。

## 风险要先说

- 版权/下架：这些包是 WanOS 官方打包的上游应用（含迅雷、百度网盘等第三方），重传到 GitHub 有被投诉下架的可能，仓库里已写明来源和“非官方镜像”。官方 CDN 还在时，目录克隆（只存链接）比全量重传稳妥得多。
- GitHub 不是 CDN：Releases 是用来发版的，不是无限流量网盘，流量异常大时可能被限流。
- 国内访问：GitHub raw / Releases 在部分网络下慢或不稳，设备上要先测 `curl -I` 能通，再指望它装机；不通就还是走官方 CDN。
- 迅雷仍是 arm64-only，不在 armv7 清单里；Releases 里可以留着它那个 arm64 包，但 armv7 设备装不了。
- 上述 3 个缺口与 1 个暂排除项（Home Assistant）及 apt / Docker Hub / 厂商驱动等公开依赖不受镜像覆盖，装机时仍需联网或本地已有环境。
