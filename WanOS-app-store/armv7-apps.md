# 玩客云 armv7 能用的应用（单独整理）

来源：本地已下载的官方应用目录 `app-store-api-20260721.json`（`https://wxqun988.vxjuejin.com/wanos/api/app-store`，71 个应用，更新于 2026-07-21），加设备导出（2026-11-06）核对已安装状态。

## 结论

- API 共 71 个，**armv7 能用 70 个**，排除 1 个：**迅雷**（见下）。

- 有 armv7 安装包直链 48 个（已全部下载到 `workspace/wanos-apps/` 并校验，48 个中 47 个 SHA 通过，1 个壁纸 SHA 与清单不符）；.wpk 直链 1 个（2048）；无直链、走 install.sh 安装 19 个；已内置、无需安装 2 个。

- 筛选标准：API `architectures` 含 armv7 / linux-armv7，或有 linux-armv7 安装包，或 install.sh 明确支持 armv7/armhf，或为 armv7 .wpk / 设备内置。

- 注意：本清单只看架构能不能用，不看安装方式难不难——其中 Docker 镜像类（青龙、Home Assistant、夸克自动转存、Gopeed）、PHP/系统服务类（Typecho、CUPS 等）仍需按官方 install.sh 在设备上装，不能直接改成 .wpk。

## A. 有 armv7 安装包直链（48 个）

| 应用 | ID | 版本 | 端口 | 大小 | 安装包 / 安装方式 |
| --- | --- | --- | --- | --- | --- |
| 115网盘 | `115pan-client` | 1.0.0-wanos.1 | 8736 | 6.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/115pan-client/115pan-client-linux-armv7-v1) |
| 123云盘 | `123pan-client` | 1.0.0-wanos.1 | 8737 | 6.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/123pan-client/123pan-client-linux-armv7-v1) |
| 阿里网盘 | `alipan-client` | 1.0.0-wanos.2 | 8742 | 6.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/alipan-client/alipan-client-linux-armv7-v2) |
| 百度网盘 WanOS版 | `baidupan-client` | 1.0.0-wanos.7 | 8732 | 6.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/baidupan-client/baidupan-client-armv7-v7) |
| Bark服务端 | `bark-server` | 2.0.0-wanos.1 | 8090 | 15.4 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/bark-server/bark-server-linux-armv7-v1) |
| 移动云盘 | `cloud139-client` | 1.0.0-wanos.1 | 8735 | 6.8 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/cloud139-client/cloud139-client-linux-armv7-v1) |
| 天翼云盘 | `cloud189-client` | 1.0.0-wanos.1 | 8734 | 9.9 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/cloud189-client/cloud189-client-linux-armv7-v1) |
| CUPS 打印服务 | `cups-print` | 1.0.0-wanos.33 | 18631 | 34.0 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/cups-print/cups-print_ubuntu20.04_armhf_offline.tar.gz) |
| 呆呆面板 | `daidai-panel` | 1.0.0-wanos.2 | 5701 | 12.0 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/daidai-panel/daidai-linux-armv7.tar.gz) |
| EasyTier | `easytier` | 2.6.4-wanos.2 | 11211 | 19.0 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/easytier/easytier-linux-armv7-v2.6.4.zip) |
| Filebrowser 文件管理 | `filebrowser` | 2.63.10-wanos.4 | 8082 | 14.2 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/filebrowser/linux-armv7-filebrowser-v2.63.10.tar.gz) |
| Gitea Git 仓库 | `gitea` | 1.26.2-wanos.2 | 3000 | 35.4 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/gitea/gitea-1.26.2-linux-arm-6.xz) |
| Gotify 通知服务 | `gotify` | 2.9.1-wanos.1 | 2587 | 35.4 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/gotify/gotify-linux-armv7-v2.9.1) |
| 开心掼蛋 | `happy-guandan` | 1.0.0-wanos.6 | 8095 | 11.3 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/happy-guandan/happy-guandan-linux-armv7-v3) |
| Home Assistant 智能家居 | `home-assistant` | 2023.4-wanos.6 | 5123 | 461.0 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/home-assistant/home-assistant-armv7-offline.tar.gz) |
| 蓝奏云盘 | `lanzoupan-client` | 1.0.0-wanos.1 | 8741 | 6.7 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/lanzoupan-client/lanzoupan-client-linux-armv7-v1) |
| 易有云 | `linkease` | 1.7.5-wanos.1 | 8897 | 46.5 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/linkease/linkease-binary-1.7.5.tar.gz) |
| 直播录制 | `live-recorder` | 1.0.0-wanos.3 | 18081 | 11.4 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/live-recorder/live-recorder-armv7-go-v3) |
| Lucky万吉 | `lucky` | 2.27.2-wanos.4 | 16601 | 8.7 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/lucky/lucky_2.27.2_Linux_armv7.tar.gz) |
| M3U8下载器 | `m3u8-downloader` | 1.0.0-wanos.4 | 8750 | 6.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/m3u8-downloader/m3u8-downloader-linux-armv7-v3) |
| MySQL 数据库 | `mariadb-adminer` | 10.3.39-wanos.3 | 18086 | 48.5 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/mariadb-adminer/mariadb-adminer-focal-armhf-offline.tar.gz) |
| 局域网音视频广播 | `minidlna` | 0.1.3-wanos.1 | 18200 | 41.5 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/minidlna/minidlna-focal-armhf-offline.tar.gz) |
| 觅思文档 | `mrdoc` | 1.0.0-wanos.2 | 10888 | 68.8 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/mrdoc/mrdoc-armhf.tar.gz) |
| New API | `new-api` | 1.0.0-wanos.2 | 3000 | 127.3 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/new-api/new-api-linux-armv7-v1) |
| ntfy 通知服务 | `ntfy` | 2.25.0-wanos.1 | 2586 | 67.0 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/ntfy/ntfy-linux-armv7-v2.25.0) |
| 网络摄像机录像 | `nvr-lite` | 0.1.0-wanos.1 | 18081 | 93.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/nvr-lite/nvr-lite-motion-focal-armhf.tar.gz) |
| OnlyOffice Personal | `onlyoffice-personal` | 1.0.0-wanos.2 | 42180 | 5.7 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/onlyoffice-personal/onlyoffice-personal-linux-armv7-v1) |
| OpenList 网盘目录 | `openlist` | 4.2.2-wanos.2 | 5245 | 42.1 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/openlist/openlist-linux-musleabihf-armv7l.tar.gz) |
| 盘搜 | `pansou` | 1.0.0-wanos.5 | 12888 | 23.4 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/pansou/pansou-linux-armv7-v3) |
| 青龙面板 | `qinglong` | 2.17.7-wanos.2 | 5700 | 98.2 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/qinglong/qinglong_2.17.7_linux_armv7_docker_image.tar.gz) |
| 夸克网盘自动转存 | `quark-auto-save` | latest-wanos.4 | 5005 | 23.3 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/quark-auto-save/quark-auto-save-linux-armv7-docker-image-v1.tar.gz) |
| 夸克网盘 | `quarkpan-client` | 1.0.0-wanos.2 | 8733 | 6.9 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/quarkpan-client/quarkpan-client-linux-armv7-v2) |
| SQLite 数据库 | `sqlite-phpliteadmin` | 1.9.8.2-wanos.4 | 18087 | 19.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/sqlite-phpliteadmin/sqlite-phpliteadmin-focal-armhf-offline-wanos.4.tar.gz) |
| sub2api | `sub2api` | 1.0.0-wanos.1 | 18080 | 81.2 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/sub2api/sub2api-linux-armv7-v1) |
| Syncthing 同步 | `syncthing` | 2.1.0-wanos.4 | 8384 | 10.7 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/syncthing/syncthing-linux-arm-v2.1.0.tar.gz) |
| 甜糖边缘节点 | `tiantang` | 1.18.17-wanos.1 | 1024 | 37.1 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/tiantang/ttmanager_arm32) |
| Typecho 博客 | `typecho-blog` | 1.3.0-wanos.3 | 8088 | 0.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/typecho-blog/typecho-v1.3.0.zip) |
| 微力同步 | `verysync` | 2.21.3-wanos.4 | 8886 | 14.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/verysync/verysync-linux-armv6-v2.21.3.tar.gz) |
| WanOS 智能助手 | `wanos-ai-assistant` | 2026.07.09-6 | 18330 | 6.7 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-ai-assistant/wanos-ai-assistant-linux-armv7-v6) |
| Cloudflare 内网穿透 | `wanos-cf-tunnel` | 1.0.0-wanos.4 | 41644 | 8.4 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-cf-tunnel/wanos-cf-tunnel-linux-armv7-v4) |
| 直播推流 | `wanos-ffstreamer` | 1.0.0-wanos.2 | 4156 | 6.2 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-ffstreamer/wanos-ffstreamer-linux-armv7-v2) |
| WanOS 壁纸 | `wanos-wallpaper` | 2026.07.18-1 | 18344 | 6.1 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/wanos-wallpaper/wanos-wallpaper-linux-armv7-v4) |
| USB WiFi 驱动组件 | `wanos-wifi-drivers` | 2026.07.09-8 | 18321 | 20.9 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/components/wifi-drivers/wanos-wifi-drivers-linux-armv7-v4.tar.gz) |
| IPTV电视直播 | `webview-tv-live` | 1.0.0-wanos.3 | 8090 | 6.9 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/webview-tv-live/webview-tv-live-linux-armv7-v2) |
| WOL网络唤醒 | `wol-network-wakeup` | 1.0.0-wanos.2 | 12100 | 10.0 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/wol-network-wakeup/wol-app-linux-armv7) |
| 闲鱼自动发货 | `xianyu-autodelivery` | 1.0.0-wanos.8 | 12088 | 11.5 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/xianyu-autodelivery/xianyu-autodelivery-linux-armv7-v8) |
| 小智AI服务端 | `xiaozhi-server` | 1.0.0-wanos.2 | 18081 | 33.2 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/xiaozhi-server/xiaozhi-server-linux-armv7-v2) |
| YT-DLP 视频下载 | `yt-dlp-web` | 1.0.0-wanos.1 | 50000 | 39.6 MB | [下载](https://wxqun988.vxjuejin.com/wanos/downloads/apps/yt-dlp-web/yt-dlp-web-armhf-wanos.tar.gz) |

- **115网盘** `115pan-client`：已下载校验通过；SHA256 `67a3312df03627c4…`；API architectures: armv7; 安装包文件名含 armv7（115pan-client-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **123云盘** `123pan-client`：已下载校验通过；SHA256 `371f99de647aaa69…`；API architectures: armv7; 安装包文件名含 armv7（123pan-client-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **阿里网盘** `alipan-client`：已下载校验通过；SHA256 `16c376bdcba7ab7f…`；API architectures: armv7; 安装包文件名含 armv7（alipan-client-linux-armv7-v2）; install.sh 校验 uname 为 armv7/armhf
- **百度网盘 WanOS版** `baidupan-client`：已下载校验通过；SHA256 `e725cd05a4323fbd…`；API architectures: armv7; 安装包文件名含 armv7（baidupan-client-armv7-v7）; install.sh 校验 uname 为 armv7/armhf
- **Bark服务端** `bark-server`：已下载校验通过；SHA256 `eec2b47cc9ad74e3…`；API architectures: armv7; 安装包文件名含 armv7（bark-server-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **移动云盘** `cloud139-client`：已下载校验通过；SHA256 `d72f549428b4234a…`；API architectures: armv7; 安装包文件名含 armv7（cloud139-client-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **天翼云盘** `cloud189-client`：已下载校验通过；SHA256 `be28dbfe8077935a…`；API architectures: armv7; 安装包文件名含 armv7（cloud189-client-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **CUPS 打印服务** `cups-print`：已下载校验通过；SHA256 `16ea1f23ac1becd2…`；安装包文件名含 armhf（cups-print_ubuntu20.04_armhf_offline.tar.gz）; install.sh 含 armv7 资源
- **呆呆面板** `daidai-panel`：已下载校验通过；SHA256 `f94f759e299844c5…`；安装包文件名含 armv7（daidai-linux-armv7.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **EasyTier** `easytier`：已下载校验通过；SHA256 `93b1d2831e45db1f…`；API architectures: armv7, arm64, amd64; API packages 含 linux-armv7; 安装包文件名含 armv7（easytier-linux-armv7-v2.6.4.zip）; install.sh 校验 uname 为 armv7/armhf
- **Filebrowser 文件管理** `filebrowser`：已下载校验通过；SHA256 `abd2f3ee4d72bff5…`；安装包文件名含 armv7（linux-armv7-filebrowser-v2.63.10.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **Gitea Git 仓库** `gitea`：已下载校验通过；SHA256 `1857b14b287fac4f…`；install.sh 校验 uname 为 armv7/armhf
- **Gotify 通知服务** `gotify`：已下载校验通过；SHA256 `6d409753889bfb47…`；API architectures: armv7; 安装包文件名含 armv7（gotify-linux-armv7-v2.9.1）; install.sh 校验 uname 为 armv7/armhf
- **开心掼蛋** `happy-guandan`：已下载校验通过；SHA256 `9b1d82d01324a4c0…`；API architectures: armv7, arm64, amd64; API packages 含 linux-armv7; 安装包文件名含 armv7（happy-guandan-linux-armv7-v3）; install.sh 校验 uname 为 armv7/armhf
- **Home Assistant 智能家居** `home-assistant`：已下载校验通过；SHA256 `1bd9ca29d78ba155…`；安装包文件名含 armv7（home-assistant-armv7-offline.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **蓝奏云盘** `lanzoupan-client`：已下载校验通过；SHA256 `f4957c8a05747211…`；API architectures: armv7, arm64, amd64; API packages 含 linux-armv7; 安装包文件名含 armv7（lanzoupan-client-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **易有云** `linkease`：已下载校验通过；SHA256 `f3ae319974d940f5…`；install.sh 校验 uname 为 armv7/armhf
- **直播录制** `live-recorder`：已下载校验通过；SHA256 `a1b850be1e8dcc46…`；API architectures: armv7; 安装包文件名含 armv7（live-recorder-armv7-go-v3）; install.sh 校验 uname 为 armv7/armhf
- **Lucky万吉** `lucky`：已下载校验通过；SHA256 `a69964e74d5daf01…`；API architectures: armv7; 安装包文件名含 armv7（lucky_2.27.2_Linux_armv7.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **M3U8下载器** `m3u8-downloader`：已下载校验通过；SHA256 `9020ce179cde0971…`；API architectures: armv7, arm64, amd64; API packages 含 linux-armv7; 安装包文件名含 armv7（m3u8-downloader-linux-armv7-v3）; install.sh 校验 uname 为 armv7/armhf
- **MySQL 数据库** `mariadb-adminer`：已下载校验通过；SHA256 `fbdf55f261213aad…`；安装包文件名含 armhf（mariadb-adminer-focal-armhf-offline.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **局域网音视频广播** `minidlna`：已下载校验通过；SHA256 `368819818ffe77d5…`；安装包文件名含 armhf（minidlna-focal-armhf-offline.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **觅思文档** `mrdoc`：已下载校验通过；SHA256 `6117115e192e6238…`；安装包文件名含 armhf（mrdoc-armhf.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **New API** `new-api`：已下载校验通过；SHA256 `d76b406896c854b2…`；API architectures: armv7; 安装包文件名含 armv7（new-api-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **ntfy 通知服务** `ntfy`：已下载校验通过；SHA256 `144708ad2c1da4ba…`；API architectures: armv7; 安装包文件名含 armv7（ntfy-linux-armv7-v2.25.0）; install.sh 校验 uname 为 armv7/armhf
- **网络摄像机录像** `nvr-lite`：已下载校验通过；SHA256 `7f077deeecd0b59e…`；安装包文件名含 armhf（nvr-lite-motion-focal-armhf.tar.gz）
- **OnlyOffice Personal** `onlyoffice-personal`：已下载校验通过；SHA256 `92bcc31377092004…`；API architectures: armv7; 安装包文件名含 armv7（onlyoffice-personal-linux-armv7-v1）; install.sh 含 armv7 资源
- **OpenList 网盘目录** `openlist`：已下载校验通过；SHA256 `2eaacd187512e94e…`；安装包文件名含 armv7（openlist-linux-musleabihf-armv7l.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **盘搜** `pansou`：已下载校验通过；SHA256 `b02eaaa5c532f5e7…`；API architectures: armv7; 安装包文件名含 armv7（pansou-linux-armv7-v3）; install.sh 校验 uname 为 armv7/armhf
- **青龙面板** `qinglong`：已下载校验通过；SHA256 `dbacbfae0ead6410…`；安装包文件名含 armv7（qinglong_2.17.7_linux_armv7_docker_image.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **夸克网盘自动转存** `quark-auto-save`：已下载校验通过；SHA256 `4823254169b0a975…`；API architectures: armv7; 安装包文件名含 armv7（quark-auto-save-linux-armv7-docker-image-v1.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **夸克网盘** `quarkpan-client`：已下载校验通过；SHA256 `8780908a8225ce90…`；API architectures: armv7; 安装包文件名含 armv7（quarkpan-client-linux-armv7-v2）; install.sh 校验 uname 为 armv7/armhf
- **SQLite 数据库** `sqlite-phpliteadmin`：已下载校验通过；SHA256 `c5e00c31f4e6d65e…`；安装包文件名含 armhf（sqlite-phpliteadmin-focal-armhf-offline-wanos.4.tar.gz）; install.sh 校验 uname 为 armv7/armhf
- **sub2api** `sub2api`：已下载校验通过；SHA256 `ff5d9fc7d1cdc144…`；API architectures: armv7; 安装包文件名含 armv7（sub2api-linux-armv7-v1）; install.sh 校验 uname 为 armv7/armhf
- **Syncthing 同步** `syncthing`：已下载校验通过；SHA256 `dfcccf4855628d6b…`；install.sh 校验 uname 为 armv7/armhf
- **甜糖边缘节点** `tiantang`：已下载校验通过；SHA256 `8b58b2bf3db031d9…`；install.sh 含 armv7 资源
- **Typecho 博客** `typecho-blog`：已下载校验通过；SHA256 `c34cd65b2f944f46…`；
- **微力同步** `verysync`：已下载校验通过；SHA256 `33b33736a22c3dbf…`；安装包文件名含 armv6（verysync-linux-armv6-v2.21.3.tar.gz，armv7 兼容）; install.sh 校验 uname 为 armv7/armhf
- **WanOS 智能助手** `wanos-ai-assistant`：已下载校验通过；SHA256 `a7b2adf16b644e59…`；API architectures: linux-armv7, linux-arm64, linux-amd64; API packages 含 linux-armv7; 安装包文件名含 armv7（wanos-ai-assistant-linux-armv7-v6）; install.sh 校验 uname 为 armv7/armhf
- **Cloudflare 内网穿透** `wanos-cf-tunnel`：已下载校验通过；SHA256 `7e955a72c7f5e340…`；API architectures: armv7; 安装包文件名含 armv7（wanos-cf-tunnel-linux-armv7-v4）; install.sh 校验 uname 为 armv7/armhf
- **直播推流** `wanos-ffstreamer`：已下载校验通过；SHA256 `721bbbf09eb61759…`；API architectures: armv7; 安装包文件名含 armv7（wanos-ffstreamer-linux-armv7-v2）; install.sh 校验 uname 为 armv7/armhf
- **WanOS 壁纸** `wanos-wallpaper`：SHA 与清单不符（实测 090e697a…，服务端已更新）；SHA256 `592ef6a1d71e96f7…`；API architectures: armv7, arm64, amd64; API packages 含 linux-armv7; 安装包文件名含 armv7（wanos-wallpaper-linux-armv7-v4）; install.sh 校验 uname 为 armv7/armhf
- **USB WiFi 驱动组件** `wanos-wifi-drivers`：已下载校验通过；SHA256 `f5be80cef77dee32…`；API architectures: linux-armv7, linux-arm64; API packages 含 linux-armv7; 安装包文件名含 armv7（wanos-wifi-drivers-linux-armv7-v4.tar.gz）
- **IPTV电视直播** `webview-tv-live`：已下载校验通过；SHA256 `061762fd791a5006…`；API architectures: armv7, arm64, amd64; API packages 含 linux-armv7; 安装包文件名含 armv7（webview-tv-live-linux-armv7-v2）; install.sh 校验 uname 为 armv7/armhf
- **WOL网络唤醒** `wol-network-wakeup`：已下载校验通过；SHA256 `49ea8878853c3052…`；API architectures: armv7; 安装包文件名含 armv7（wol-app-linux-armv7）; install.sh 校验 uname 为 armv7/armhf
- **闲鱼自动发货** `xianyu-autodelivery`：已下载校验通过；SHA256 `6fa9089d9789ef1b…`；API architectures: armv7; 安装包文件名含 armv7（xianyu-autodelivery-linux-armv7-v8）; install.sh 校验 uname 为 armv7/armhf
- **小智AI服务端** `xiaozhi-server`：已下载校验通过；SHA256 `2cb33a4998070502…`；API architectures: armv7; 安装包文件名含 armv7（xiaozhi-server-linux-armv7-v2）; install.sh 校验 uname 为 armv7/armhf
- **YT-DLP 视频下载** `yt-dlp-web`：已下载校验通过；SHA256 `8d93f83e640d108b…`；安装包文件名含 armhf（yt-dlp-web-armhf-wanos.tar.gz）; install.sh 校验 uname 为 armv7/armhf

## B. .wpk 直链（1 个）

| 应用 | ID | 版本 | 端口 | 大小 | 安装包 / 安装方式 |
| --- | --- | --- | --- | --- | --- |
| 2048小游戏 | `wanos-2048` | — | 42181 | 2.0 MB | [下载 .wpk](https://wxqun988.vxjuejin.com/wanos/app-submissions/wanos-2048/wanos-2048-1784204854192/wano--2048.wpk) |


## C. 无直链，走 install.sh 安装（19 个）

| 应用 | ID | 版本 | 端口 | 大小 | 安装包 / 安装方式 |
| --- | --- | --- | --- | --- | --- |
| AdGuard Home | `adguard-home` | 0.107.76-wanos.2 | 3000 | — | [安装脚本](https://wanos.xyz/downloads/apps/adguard-home/install.sh) |
| 宝塔面板 | `bt-panel` | 1.0.0-wanos.17 | 8888 | 568.8 MB | [安装脚本](https://wanos.xyz/downloads/apps/bt-panel/install.sh) |
| Chromium 浏览器 | `chromium-headless` | 90.0.4430.212-wanos.3 | 9223 | — | [安装脚本](https://wanos.xyz/downloads/apps/chromium-headless/install.sh) |
| DDNS-GO 动态域名 | `ddns-go` | — | 9876 | — | [安装脚本](https://wanos.xyz/downloads/apps/ddns-go/install.sh) |
| FTP 服务 | `ftp-server` | 1.0.0-wanos.3 | 21210 | — | [安装脚本](https://wanos.xyz/downloads/apps/ftp-server/install.sh) |
| Gopeed 下载器 | `gopeed` | 0.0.1-wanos.1 | 9999 | — | [安装脚本](https://wanos.xyz/downloads/apps/gopeed/install.sh) |
| 节点小宝 | `jiedianxiaobao` | 0.0.1-wanos.1 | 9118 | — | [安装脚本](https://wanos.xyz/downloads/apps/jiedianxiaobao/install.sh) |
| 可道云 KodBox | `kodbox` | main-20260604-wanos.4 | 8181 | — | [安装脚本](https://wanos.xyz/downloads/apps/kodbox/install.sh) |
| Minecraft 服务端 | `minecraft-java` | 1.12.2-wanos.1 | 25566 | — | [安装脚本](https://wanos.xyz/downloads/apps/minecraft-java/install.sh) |
| UPS 电源管理 | `nut-ups` | — | 3494 | — | [安装脚本](https://wanos.xyz/downloads/apps/nut-ups/install.sh) |
| 网心云 OEC/T 指示灯 | `oec-led` | 0.1.0-wanos.1 | 18232 | — | [安装脚本](https://wanos.xyz/downloads/apps/oec-led/install.sh) |
| 玩客云指示灯 | `onecloud-led` | 0.1.2-wanos.1 | 18231 | — | [安装脚本](https://wanos.xyz/downloads/apps/onecloud-led/install.sh) |
| 花生壳内网穿透 | `phddns` | 5.1.0-wanos.2 | 16063 | — | [安装脚本](https://wanos.xyz/downloads/apps/phddns/install.sh) |
| 小龙虾AI助手 | `picoclaw` | — | 18800 | — | [安装脚本](https://wanos.xyz/downloads/apps/picoclaw/install.sh) |
| Tailscale 异地组网 | `tailscale` | — | 41642 | — | [安装脚本](https://wanos.xyz/downloads/apps/tailscale/install.sh) |
| V2Ray 代理 | `v2ray-proxy` | 5.6.0-wanos.1 | 10810 | — | [安装脚本](https://wanos.xyz/downloads/apps/v2ray-proxy/install.sh) |
| 测试应用 | `wanos-test-app` | — | 18090 | — | [安装脚本](https://wanos.xyz/downloads/apps/wanos-test-app/install.sh) |
| WebDAV 服务 | `webdav-server` | 1.0.0-wanos.2 | 21221 | — | [安装脚本](https://wanos.xyz/downloads/apps/webdav-server/install.sh) |
| 小雅 Alist | `xiaoya-alist` | 0.0.15-wanos.1 | 5678 | — | [安装脚本](https://wanos.xyz/downloads/apps/xiaoya-alist/install.sh) |


## D. 已内置，无需安装（2 个）

| 应用 | ID | 版本 | 端口 | 大小 | 安装包 / 安装方式 |
| --- | --- | --- | --- | --- | --- |
| 终端 | `terminal` | — | 7681 | — | 已内置 |
| BT 下载 | `transmission` | — | 9091 | — | 已内置 |


## 排除的 1 个

| 应用 | ID | 原因 |
| --- | --- | --- |
| 迅雷远程下载 | `xunlei` | architectures 仅 linux-arm64 / linux-amd64；install.sh 只认 aarch64/arm64 与 x86_64/amd64，其余架构直接报错；上游 cnk3x/xunlei 只有 amd64/arm64 包，群晖 SPK 也只有 x86_64/armv8，无 armv7 |

## 设备导出里另外的 10 个（不在 API 里，不计入上面 70 个）

Alist、计算器、记事本、WanOS 音乐、媒体播放、下载中心、相册（7 个内置）+ 凤凰秀直播、直播源管理、YT直播（3 个手动安装 .wpk），都在 armv7 设备上，但官方 API 里没有、无公网直链。

## 文件

- `armv7-apps.json`：本清单的机器可读版，含每个应用的端口、简介、安装包/安装脚本链接、SHA256、已下载校验状态。

- `apps.json`：81 个应用的完整合并目录（含上面 10 个设备应用 + 迅雷）。

- 克隆站 `index.html` 已加“仅 ARMv7 能用”筛选，选它就只显示这 70 个（合并目录里是 80 个，因为还含设备那 10 个）。
