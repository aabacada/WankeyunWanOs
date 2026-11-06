# WanOS 教程与文档合集（离线版）

把 [wanos.xyz](https://www.wanos.xyz/) 官网上与玩客云刷机、系统使用、APP 下载、开发接入相关的六个页面，整理成了**可离线阅读**的 Markdown 文档。所有配图、二维码已下载到本地，断网、换设备、传到手机上都能正常显示。另外收录了官方应用市场的离线镜像（见下表最后一行）。

- 整理时间：2026-11-05
- 内容来源：<https://www.wanos.xyz/>
- 文档数量：6 份，共约 1600 行，28 张本地配图；另有应用市场镜像 1 个

---

## 文档一览

| 文档 | 讲什么 | 规模 |
| --- | --- | --- |
| [玩客云 S805 刷入 WanOS](玩客云刷WanOS教程/玩客云S805刷入WanOS教程.md) | 拆机、短接、USB Burning Tool 线刷全流程，附 16 张实拍图与网盘下载地址 | 261 行 · 12 KB |
| [WanOS 使用说明](WanOS使用说明/WanOS使用说明.md) | 系统里每个模块怎么用：文件、媒体、下载中心、网络共享、系统维护、应用中心 | 153 行 · 8 KB |
| [WanOS APP 下载](WanOS%20APP下载页/WanOS-APP下载.md) | 安卓 / iOS / TV / 鸿蒙 / Mac / 同步盘 / 小程序的下载入口与二维码 | 179 行 · 8 KB |
| [系统能力与 API 接口](WanOS系统能力与API/WanOS系统能力与API.md) | 159 个后端接口清单，含悬浮窗口、文件预览、壁纸、公网访问等扩展能力 | 417 行 · 28 KB |
| [WPK 应用开发文档](WPK应用开发文档/WPK应用开发文档.md) | 把应用打包成 `.wpk` 的完整流程：manifest 字段、脚本规则、打包测试、上架审核 | 478 行 · 20 KB |
| [WanOS ID 登录鉴权](WanOS-登录鉴权OAuth/WanOS-登录鉴权OAuth.md) | OAuth 授权码接入，含换取 Token、扣积分、用户信息返回示例 | 150 行 · 8 KB |
| [WanOS 应用市场（镜像）](WanOS-app-store/README.md) | 官方应用市场克隆：78 个应用的名称、介绍、图标与版本，安装包走 [Release](https://github.com/aabacada/wankeyunwanos/releases/tag/wanos-armv7-20261106)，安装脚本走改写后的 raw 地址，官网下线后仍可安装 | 78 个应用 · 61 个有安装包 · 67 个有安装脚本 · Release 129 个文件约 1.77 GiB |

---

## 阅读顺序建议

**只是想用起来**（按设备情况选）

1. 设备是没刷过的玩客云 → 先看 [刷机教程](玩客云刷WanOS教程/玩客云S805刷入WanOS教程.md)，刷完拿到 IP
2. 已经能进 Web 面板 → 看 [使用说明](WanOS使用说明/WanOS使用说明.md) 熟悉各模块
3. 手机/电视上想用 → 按 [APP 下载](WanOS%20APP下载页/WanOS-APP下载.md) 装客户端
4. 想给设备装应用 → 看 [应用市场（镜像）](WanOS-app-store/README.md)，按应用目录里的安装包或安装脚本装

**想接自己的脚本或做开发**

1. 先看 [系统能力与 API](WanOS系统能力与API/WanOS系统能力与API.md) 了解能调什么
2. 要做带 Web 面板的应用 → [WPK 开发文档](WPK应用开发文档/WPK应用开发文档.md)
3. 要拿用户身份或积分 → [登录鉴权](WanOS-登录鉴权OAuth/WanOS-登录鉴权OAuth.md)

---

## 目录结构

```
教程/
├── README.md                                  ← 本文件
├── 玩客云刷WanOS教程/
│   ├── 玩客云S805刷入WanOS教程.md
│   ├── 玩客云刷WanOS视频教程.mp4              (45 MB)
│   └── images/                                (16 张)
├── WanOS使用说明/
│   └── WanOS使用说明.md
├── WanOS APP下载页/
│   ├── WanOS-APP下载.md
│   └── images/                                (12 张)
├── WanOS系统能力与API/
│   └── WanOS系统能力与API.md
├── WPK应用开发文档/
│   └── WPK应用开发文档.md
├── WanOS-登录鉴权OAuth/
│   └── WanOS-登录鉴权OAuth.md
└── WanOS-app-store/                           ← 官方应用市场镜像（78 个应用目录 + 离线安装包）
    ├── README.md                              ← 应用目录：名称、介绍、图标、版本、Release 安装包、安装脚本
    ├── index.html                             ← 静态应用市场页
    └── github-mirror/                         ← 改写后安装脚本、Release 文件清单（128 个文件约 1.76 GiB）
```

---

## 整理说明

**做了哪些处理**

- 网页里藏在 JavaScript 里的真实下载链接（网盘、直链、SHA256）已提取出来，写进对应文档，不用再点弹窗找
- 原文的代码块、字段表、步骤列表按结构转成 Markdown，不是纯文字堆砌，复制即可用
- 每份文档都逐条比对过原文的小标题、表格单元格、代码块，确认无遗漏
- 原文自身的小瑕疵（如字段在表格里漏列、按钮文案与弹窗不一致）在文档中如实标注，未擅自修改

**没做什么**

- 未改动任何原文表述，除极少数标注「整理补充」的地方（仅 [登录鉴权](WanOS-登录鉴权OAuth/WanOS-登录鉴权OAuth.md) 中的参数表一处）
- 未收录网页底部的赞赏码、QQ 群二维码等打赏入口

---

---

## 声明

以上内容均整理自 WanOS 官网（<https://www.wanos.xyz/>），版权归原作者所有，此处仅作离线存档与个人查阅之用。网盘链接、版本号、接口可能随官网更新而变化，失效时请以官网为准。

WanOS 官方联系：QQ 1546912750 · [交流论坛](https://www.wanos.xyz/forum/)
