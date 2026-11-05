# 系统能力与 API 接口

> WanOS 后端开放了文件、存储、分享、应用、网络、Docker、计划任务等接口，可用于对接自己的脚本、面板、自动化工具或第三方应用。
>
> 整理自 <https://www.wanos.xyz/system-capabilities/>，本地离线版生成于 2026-11-05，正文与原文一致，仅做 Markdown 结构化。

| 项目 | 信息 |
| --- | --- |
| 页面来源 | <https://www.wanos.xyz/system-capabilities/> |
| 接口基地址 | `http://设备IP/api/...` |
| 认证方式 | Web 登录会话 Cookie（`Cookie: wanos_session=...`） |
| 请求格式 | GET 用 query 参数；POST 用 JSON；文件上传用 `multipart/form-data` |
| 返回格式 | 主要为 JSON；下载、导出、预览类返回文件流或代理内容 |
| 接口清单 | 159 个，分 7 组，另附 7 段调用示例 |

---

## 目录

- [接入方式](#接入方式)
- [常用能力](#常用能力)
- [悬浮窗口 API](#悬浮窗口-api)
- [系统文件预览 API](#系统文件预览-api)
- [桌面壁纸 API](#桌面壁纸-api)
- [应用商店详情打开 API](#应用商店详情打开-api)
- [应用公网访问能力](#应用公网访问能力)
- [应用文件选择能力](#应用文件选择能力)
- [完整接口清单](#完整接口清单)
  - [认证与系统（23 个）](#认证与系统)
  - [文件与存储（39 个）](#文件与存储)
  - [分享与媒体（8 个）](#分享与媒体)
  - [下载与计划任务（6 个）](#下载与计划任务)
  - [网络与远程访问（32 个）](#网络与远程访问)
  - [应用与服务（40 个）](#应用与服务)
  - [其他接口（11 个）](#其他接口)

---

WanOS 后端开放了文件、存储、分享、应用、网络、Docker、计划任务等接口。你可以用这些接口对接自己的脚本、面板、自动化工具或第三方应用。

`http://设备IP/api/status` · `Cookie: wanos_session=...`

## 接入方式

- **认证**：大多数接口需要先通过 Web 登录，浏览器会自动携带会话 Cookie。第三方脚本可先调用登录接口获取会话。
- **请求格式**：GET 接口使用 query 参数；POST 接口通常使用 JSON，文件上传使用 multipart/form-data。
- **返回格式**：接口主要返回 JSON。下载、导出和预览类接口会返回文件流或代理内容。

```sh
curl -b "wanos_session=你的会话" http://设备IP/api/status
curl -b "wanos_session=你的会话" "http://设备IP/api/list?path=/"
```

## 常用能力

- **读取设备状态** — `GET` `/api/status`：获取 CPU、内存、运行状态等基础信息，用于监控面板或自动化巡检。
- **列出存储目录** — `GET` `/api/list?path=/mnt/sda1`：读取目录、文件和存储入口，适合接入自定义文件管理器。
- **上传文件** — `POST` `/api/upload`：通过 multipart/form-data 上传文件，常用于备份、同步和资料投递。
- **创建分享** — `POST` `/api/share/create`：把指定文件或目录生成分享链接，可用于外部工作流。
- **第三方内网穿透** — `POST` `/api/tunnel/start`：填写 NPC/NPS 服务端地址和 key，启用第三方穿透服务。
- **应用商店安装** — `POST` `/api/store/install`：按应用 ID 安装应用，可用于定制装机流程。
- **Docker 容器管理** — `GET/POST` `/api/docker/containers`：读取和管理容器，扩展轻量服务编排。
- **计划任务** — `GET/POST` `/api/cron/tasks`：查看和管理计划任务，实现定时脚本、备份和自动化。
- **悬浮窗口** — `JS/API` `/api/window/open`：由系统托管第三方应用的小窗口、任务面板、迷你播放器和 AI 助手面板。
- **系统文件预览** — `JS/API` `/api/preview/open`：第三方应用可直接调用系统图片、视频、音频、PDF 和文本预览能力。
- **设置桌面壁纸** — `JS/API` `/api/wallpaper/set`：第三方壁纸应用可把 NAS 图片一键设置为 WanOS 桌面壁纸。
- **打开应用详情** — `JS/API` `WanOSAppStore.openAppDetail()`：第三方页面或系统广告可直接打开应用商店指定应用详情。
- **应用公网访问** — `POST` `/api/tunnel/app-domain`：应用声明支持公网访问后，桌面右键可开启公网入口，之后直接复制公网链接。

## 悬浮窗口 API

> WanOS 可以在桌面托管第三方应用的小窗口。应用不需要直接修改桌面 DOM，就能打开、更新、聚焦、列出或关闭一个系统悬浮 iframe。

- **打开窗口** — `POST` `/api/window/open`：创建或替换悬浮窗口。请求体支持 id、app_id、title、url、width、height、x、y、resizable、always_on_top。
- **更新窗口** — `POST` `/api/window/update`：更新位置、尺寸、标题、地址、最小化状态和是否可缩放。
- **关闭窗口** — `POST` `/api/window/close`：关闭悬浮窗口，并从桌面持久状态中移除。
- **窗口列表** — `GET` `/api/window/list`：返回已持久化的悬浮窗口，刷新桌面后可自动恢复。

```js
window.WanOS.openFloatWindow({
  id: "download-tasks",
  title: "Download Tasks",
  url: "/apps/downloader/tasks",
  width: 420,
  height: 560,
  x: "right",
  y: "bottom",
  resizable: true
});
```

> iframe 应用也可以用 postMessage 调用同一能力，消息类型为 `wanos:float-window:open`。结果消息为 `wanos:float-window-result` 或 `wanos:float-window-error`。

## 系统文件预览 API

> 第三方应用可以把 NAS 文件路径交给 WanOS，由系统统一打开图片预览、视频播放器、音频播放器、PDF 或文本预览。比如下载器下载完成后，可以直接调用系统视频预览播放视频。

- **校验并打开预览** — `POST` `/api/preview/open`：请求体传 path 和可选 name。后端校验文件存在、路径安全、类型可预览，前端随后拉起系统预览器。
- **主页面调用** — `JS` `window.WanOS.previewFile()`：同源应用可直接调用，参数为 path、name。视频会复用系统播放器和现有播放兼容逻辑。
- **iframe 调用** — `postMessage` `wanos:preview-file`：第三方 iframe 应用可向父窗口发送消息调用预览，结果返回 wanos:preview-file-result 或 wanos:preview-file-error。

```js
window.parent.postMessage({
  type: "wanos:preview-file",
  requestId: "preview-1",
  path: "/mnt/wanos/mmcblk0p1-tf/downloads/demo.mp4",
  name: "demo.mp4"
}, "*");
```

## 桌面壁纸 API

> 第三方壁纸应用可以把已保存到 NAS 的图片交给 WanOS 设为桌面壁纸。接口会校验路径、文件存在和图片格式，支持 PNG、JPG、WebP、GIF。

- **设置 NAS 图片为壁纸** — `POST` `/api/wallpaper/set`：请求体传 path。接口复用系统自定义壁纸保存逻辑，成功后返回 custom 壁纸地址。
- **主页面调用** — `JS` `window.WanOS.setWallpaper()`：同源应用可直接调用，系统会立即刷新当前桌面壁纸。
- **iframe 调用** — `postMessage` `wanos:set-wallpaper`：第三方 iframe 应用可向父窗口发送消息设置壁纸，结果返回 wanos:set-wallpaper-result 或 wanos:set-wallpaper-error。

```js
window.parent.postMessage({
  type: "wanos:set-wallpaper",
  requestId: "wallpaper-1",
  path: "/mnt/wanos/mmcblk0p1-tf/wallpapers/demo.jpg"
}, "*");
```

## 应用商店详情打开 API

> 第三方页面、系统广告和壁纸应用可以直接打开 WanOS 应用商店，并定位到指定应用详情页。

- **参数打开** — `URL` `?store_app=wanos-wallpaper`：进入 WanOS 桌面后自动打开应用商店，并展示对应应用详情页。
- **主页面调用** — `JS` `window.WanOSAppStore.openAppDetail()`：传入应用 ID，系统会打开应用商店并定位到详情页。

```js
window.WanOSAppStore.openAppDetail("wanos-wallpaper");

// 或直接访问：
http://设备IP/?store_app=wanos-wallpaper
```

## 应用公网访问能力

> 应用商店应用可以声明支持公网访问。用户在桌面或应用导航里右键应用时，WanOS 会显示“公网访问”；开启成功后系统保存公网地址，下次右键直接显示“复制公网链接”。

- **声明支持公网** — `清单字段` `public_access_supported: true`：应用必须同时提供本地服务端口 port，WanOS 才能自动创建公网入口。
- **创建应用入口** — `POST` `/api/tunnel/app-domain`：请求体传 app_id、app_name、port。接口会把公网域名转发到 127.0.0.1:port。
- **右键操作** — `菜单` `公网访问 / 复制公网链接`：未开启时显示公网访问；开启后持久保存 public_url，刷新应用列表后仍显示复制公网链接。

```js
{
  "id": "demo-web-app",
  "name": "示例网页应用",
  "port": 8787,
  "path": "/",
  "public_access_supported": true,
  "public_access": true
}

fetch("/api/tunnel/app-domain", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    app_id: "demo-web-app",
    app_name: "示例网页应用",
    port: "8787"
  })
});
```

> 公网访问依赖 WanOS 远程访问能力。用户需要先在“远程访问”里开通内网穿透；未声明公网能力的普通应用不会显示右键公网菜单。

## 应用文件选择能力

> 第三方应用在 WanOS 弹窗 iframe 内可以通过 postMessage 调用系统 NAS 文件选择器，统一实现离线包导入、保存目录选择、媒体目录选择等能力。

- **选择 NAS 文件** — `postMessage` `wanos:pick-file`：打开 NAS 文件选择器，可通过 accept / acceptExt 限制扩展名，也可通过 fileType / category 使用 video、image、audio、document、archive、subtitle 等类型。
- **选择 NAS 目录** — `postMessage` `wanos:pick-directory`：选择已有目录，可用于媒体库、相册、下载保存目录等配置。
- **选择保存目录** — `postMessage` `wanos:pick-save-directory`：引导用户选择保存位置，支持 TF 卡、USB 盘或 NAS 目录。
- **打开所在位置** — `postMessage` `wanos:open-file-location`：根据文件路径打开 WanOS 文件管理器，并定位到该文件所在目录。

```js
window.parent.postMessage({
  type: "wanos:pick-file",
  requestId: "pick-video-1",
  title: "选择视频文件",
  hint: "请选择要处理的视频文件",
  startPath: "/mnt",
  fileType: "video"
}, "*");

window.addEventListener("message", event => {
  const data = event.data || {};
  if (data.type === "wanos:pick-result" && data.requestId === "pick-video-1") {
    console.log("用户选择的文件：", data.path);
  }
});

window.parent.postMessage({
  type: "wanos:open-file-location",
  requestId: "open-location-1",
  path: "/mnt/wanos/mmcblk0p1-tf/downloads/demo.mp4"
}, "*");
```

> 回调消息为 `wanos:open-location-result` 或 `wanos:open-location-error`。路径会限制在 `/mnt`、`/media`、`/.vol`、`/srv`、`/opt/wanos-data/apps` 等 WanOS 安全目录内。

## 完整接口清单

> 以下列表由当前 WanOS 后端路由生成。带 `/api/remote/` 的远程兼容别名未重复列出，对应短路径接口可直接在本机使用。

### 认证与系统

| 方法 | 接口 | 说明 | 认证 |
| --- | --- | --- | --- |
| GET | `/api/backup/export` | backup / export | 需要 Web 登录会话 Cookie |
| GET | `/api/backup/import` | backup / import | 需要 Web 登录会话 Cookie |
| POST | `/api/backup/start` | backup / start | 需要 Web 登录会话 Cookie |
| GET | `/api/backup/status` | backup / status | 需要 Web 登录会话 Cookie |
| GET | `/api/backup/volumes` | backup / volumes | 需要 Web 登录会话 Cookie |
| GET | `/api/dashboard` | dashboard | 需要 Web 登录会话 Cookie |
| POST | `/api/diagnostics` | diagnostics | 需要 Web 登录会话 Cookie |
| GET | `/api/diagnostics/export` | diagnostics / export | 需要 Web 登录会话 Cookie |
| GET | `/api/health` | health | 需要 Web 登录会话 Cookie |
| POST | `/api/login` | 登录 | 登录前可用/会话接口 |
| POST | `/api/logout` | 退出登录 | 登录前可用/会话接口 |
| GET | `/api/me` | 当前登录与设备资料 | 登录前可用/会话接口 |
| GET | `/api/media` | media | 需要 Web 登录会话 Cookie |
| GET | `/api/media-player/` | media player / | 需要 Web 登录会话 Cookie |
| POST | `/api/power` | power | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/settings` | settings | 需要 Web 登录会话 Cookie |
| POST | `/api/settings/wallpaper` | settings / wallpaper | 需要 Web 登录会话 Cookie |
| GET | `/api/status` | 系统状态 | 需要 Web 登录会话 Cookie |
| POST | `/api/system` | system | 需要 Web 登录会话 Cookie |
| GET | `/api/system/cleanup/preview` | system / cleanup / preview | 需要 Web 登录会话 Cookie |
| POST | `/api/system/cleanup/run` | system / cleanup / run | 需要 Web 登录会话 Cookie |
| POST | `/api/system/command` | system / command | 需要 Web 登录会话 Cookie |
| POST | `/api/system/reset` | system / reset | 需要 Web 登录会话 Cookie |

### 文件与存储

| 方法 | 接口 | 说明 | 认证 |
| --- | --- | --- | --- |
| POST | `/api/cloud-mount/apply` | cloud mount / apply | 需要 Web 登录会话 Cookie |
| GET | `/api/cloud-mount/status` | cloud mount / status | 需要 Web 登录会话 Cookie |
| POST | `/api/cloud-mount/unmount` | cloud mount / unmount | 需要 Web 登录会话 Cookie |
| POST | `/api/copy` | copy | 需要 Web 登录会话 Cookie |
| POST | `/api/delete` | delete | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/eject` | disk / eject | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/format-ext4` | disk / format ext4 | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/format-partition-ext4` | disk / format partition ext4 | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/mount` | disk / mount | 需要 Web 登录会话 Cookie |
| GET | `/api/disk/operation/status` | disk / operation / status | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/partition` | disk / partition | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/partition-layout` | disk / partition layout | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/repair` | disk / repair | 需要 Web 登录会话 Cookie |
| GET | `/api/disk/sleep/apply` | disk / sleep / apply | 需要 Web 登录会话 Cookie |
| GET | `/api/disk/sleep/install-tool` | disk / sleep / install tool | 需要 Web 登录会话 Cookie |
| GET | `/api/disk/sleep/status` | disk / sleep / status | 需要 Web 登录会话 Cookie |
| POST | `/api/disk/unmount` | disk / unmount | 需要 Web 登录会话 Cookie |
| GET | `/api/disks` | 磁盘列表 | 需要 Web 登录会话 Cookie |
| GET | `/api/download` | 下载文件 | 需要 Web 登录会话 Cookie |
| POST | `/api/downloads/add` | downloads / add | 需要 Web 登录会话 Cookie |
| GET | `/api/downloads/details` | downloads / details | 需要 Web 登录会话 Cookie |
| GET | `/api/downloads/reannounce` | downloads / reannounce | 需要 Web 登录会话 Cookie |
| POST | `/api/downloads/remove` | downloads / remove | 需要 Web 登录会话 Cookie |
| GET | `/api/downloads/start` | downloads / start | 需要 Web 登录会话 Cookie |
| GET | `/api/downloads/stop` | downloads / stop | 需要 Web 登录会话 Cookie |
| GET | `/api/downloads/tasks` | downloads / tasks | 需要 Web 登录会话 Cookie |
| POST | `/api/downloads/trackers` | downloads / trackers | 需要 Web 登录会话 Cookie |
| GET | `/api/downloads/verify` | downloads / verify | 需要 Web 登录会话 Cookie |
| GET | `/api/extract` | extract | 需要 Web 登录会话 Cookie |
| GET | `/api/file/content` | file / content | 需要 Web 登录会话 Cookie |
| GET | `/api/list` | 目录列表 | 需要 Web 登录会话 Cookie |
| POST | `/api/mkdir` | mkdir | 需要 Web 登录会话 Cookie |
| POST | `/api/move` | move | 需要 Web 登录会话 Cookie |
| GET | `/api/rename` | rename | 需要 Web 登录会话 Cookie |
| POST | `/api/search` | 搜索文件 | 需要 Web 登录会话 Cookie |
| GET | `/api/thumbnail` | thumbnail | 需要 Web 登录会话 Cookie |
| POST | `/api/touch` | touch | 需要 Web 登录会话 Cookie |
| POST | `/api/upload` | 上传文件 | 需要 Web 登录会话 Cookie |
| GET | `/api/volumes` | 存储入口 | 需要 Web 登录会话 Cookie |

### 分享与媒体

| 方法 | 接口 | 说明 | 认证 |
| --- | --- | --- | --- |
| GET | `/api/music` | music | 需要 Web 登录会话 Cookie |
| GET | `/api/music/file/` | music / file / | 需要 Web 登录会话 Cookie |
| POST | `/api/share/create` | 创建分享 | 需要 Web 登录会话 Cookie |
| POST | `/api/share/delete` | share / delete | 需要 Web 登录会话 Cookie |
| GET | `/api/share/download` | share / download | 需要 Web 登录会话 Cookie |
| POST | `/api/share/info` | share / info | 需要 Web 登录会话 Cookie |
| GET | `/api/share/list` | share / list | 需要 Web 登录会话 Cookie |
| POST | `/api/share/verify` | share / verify | 需要 Web 登录会话 Cookie |

### 下载与计划任务

| 方法 | 接口 | 说明 | 认证 |
| --- | --- | --- | --- |
| POST | `/api/aria2/` | aria2 / | 需要 Web 登录会话 Cookie |
| POST | `/api/aria2/jsonrpc` | aria2 / jsonrpc | 需要 Web 登录会话 Cookie |
| POST | `/api/aria2/start` | aria2 / start | 需要 Web 登录会话 Cookie |
| POST | `/api/cron/delete` | cron / delete | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/cron/tasks` | 计划任务列表 | 需要 Web 登录会话 Cookie |
| POST | `/api/cron/toggle` | cron / toggle | 需要 Web 登录会话 Cookie |

### 网络与远程访问

| 方法 | 接口 | 说明 | 认证 |
| --- | --- | --- | --- |
| GET | `/api/backend/apply` | backend / apply | 需要 Web 登录会话 Cookie |
| GET | `/api/backend/restart` | backend / restart | 需要 Web 登录会话 Cookie |
| GET | `/api/backend/start` | backend / start | 需要 Web 登录会话 Cookie |
| GET | `/api/backend/status` | backend / status | 需要 Web 登录会话 Cookie |
| GET | `/api/backend/stop` | backend / stop | 需要 Web 登录会话 Cookie |
| POST | `/api/network/heal` | network / heal | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/network/mac` | network / mac | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/network/overview` | network / overview | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/network/status` | network / status | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/network/watchdog` | network / watchdog | 需要 Web 登录会话 Cookie |
| GET | `/api/pro/devices` | pro / devices | 需要 Web 登录会话 Cookie |
| POST | `/api/pro/order` | pro / order | 需要 Web 登录会话 Cookie |
| GET | `/api/pro/order/status` | pro / order / status | 需要 Web 登录会话 Cookie |
| GET | `/api/pro/status` | pro / status | 需要 Web 登录会话 Cookie |
| POST | `/api/samba/apply` | samba / apply | 需要 Web 登录会话 Cookie |
| GET | `/api/samba/status` | samba / status | 需要 Web 登录会话 Cookie |
| POST | `/api/site/apply` | site / apply | 需要 Web 登录会话 Cookie |
| GET | `/api/site/status` | site / status | 需要 Web 登录会话 Cookie |
| POST | `/api/terminal/` | terminal / | 需要 Web 登录会话 Cookie |
| POST | `/api/tunnel/custom-domain` | tunnel / custom domain | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/tunnel/diagnose` | tunnel / diagnose | 需要 Web 登录会话 Cookie |
| POST | `/api/tunnel/order` | tunnel / order | 需要 Web 登录会话 Cookie |
| GET | `/api/tunnel/order/status` | tunnel / order / status | 需要 Web 登录会话 Cookie |
| POST | `/api/tunnel/plans` | tunnel / plans | 需要 Web 登录会话 Cookie |
| POST | `/api/tunnel/start` | 启用第三方 NPC/NPS 穿透 | 需要 Web 登录会话 Cookie |
| GET | `/api/tunnel/status` | 内网穿透状态 | 需要 Web 登录会话 Cookie |
| POST | `/api/tunnel/stop` | tunnel / stop | 需要 Web 登录会话 Cookie |
| POST | `/api/tunnel/test` | 测试 NPC/NPS 服务端 | 需要 Web 登录会话 Cookie |
| POST | `/api/wifi/connect` | wifi / connect | 需要 Web 登录会话 Cookie |
| POST | `/api/wifi/disable` | wifi / disable | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/wifi/scan` | wifi / scan | 需要 Web 登录会话 Cookie |
| GET/POST | `/api/wifi/status` | WiFi 状态 | 需要 Web 登录会话 Cookie |

### 应用与服务

| 方法 | 接口 | 说明 | 认证 |
| --- | --- | --- | --- |
| GET | `/api/alist` | alist | 需要 Web 登录会话 Cookie |
| GET | `/api/alist/` | alist / | 需要 Web 登录会话 Cookie |
| POST | `/api/alist/start` | alist / start | 需要 Web 登录会话 Cookie |
| GET | `/api/apps` | apps | 需要 Web 登录会话 Cookie |
| GET | `/api/apps/save` | apps / save | 需要 Web 登录会话 Cookie |
| GET | `/api/apps/script/install` | apps / script / install | 需要 Web 登录会话 Cookie |
| GET | `/api/apps/script/status` | apps / script / status | 需要 Web 登录会话 Cookie |
| GET | `/api/apps/script/uninstall` | apps / script / uninstall | 需要 Web 登录会话 Cookie |
| POST | `/api/docker/action` | docker / action | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/compose` | docker / compose | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/compose-projects` | docker / compose projects | 需要 Web 登录会话 Cookie |
| POST | `/api/docker/config` | docker / config | 需要 Web 登录会话 Cookie |
| POST | `/api/docker/container-action` | docker / container action | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/container-logs` | docker / container logs | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/containers` | Docker 容器 | 需要 Web 登录会话 Cookie |
| POST | `/api/docker/image-action` | docker / image action | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/images` | docker / images | 需要 Web 登录会话 Cookie |
| POST | `/api/docker/install` | docker / install | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/logs` | docker / logs | 需要 Web 登录会话 Cookie |
| POST | `/api/docker/network-action` | docker / network action | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/networks` | docker / networks | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/registry-search` | docker / registry search | 需要 Web 登录会话 Cookie |
| POST | `/api/docker/run` | docker / run | 需要 Web 登录会话 Cookie |
| GET | `/api/docker/status` | docker / status | 需要 Web 登录会话 Cookie |
| GET | `/api/store/apps` | 应用商店列表 | 需要 Web 登录会话 Cookie |
| GET | `/api/store/casaos/apps` | store / casaos / apps | 需要 Web 登录会话 Cookie |
| GET | `/api/store/casaos/install` | store / casaos / install | 需要 Web 登录会话 Cookie |
| GET | `/api/store/casaos/uninstall` | store / casaos / uninstall | 需要 Web 登录会话 Cookie |
| GET | `/api/store/home-assistant/import` | store / home assistant / import | 需要 Web 登录会话 Cookie |
| GET | `/api/store/home-assistant/status` | store / home assistant / status | 需要 Web 登录会话 Cookie |
| GET | `/api/store/home-assistant/upload` | store / home assistant / upload | 需要 Web 登录会话 Cookie |
| GET | `/api/store/import/register` | store / import / register | 需要 Web 登录会话 Cookie |
| GET | `/api/store/import/start` | store / import / start | 需要 Web 登录会话 Cookie |
| GET | `/api/store/import/status` | store / import / status | 需要 Web 登录会话 Cookie |
| GET | `/api/store/import/upload` | store / import / upload | 需要 Web 登录会话 Cookie |
| GET | `/api/store/install` | 安装应用 | 需要 Web 登录会话 Cookie |
| GET | `/api/store/start` | store / start | 需要 Web 登录会话 Cookie |
| GET | `/api/store/stop` | store / stop | 需要 Web 登录会话 Cookie |
| GET | `/api/store/uninstall` | store / uninstall | 需要 Web 登录会话 Cookie |
| GET | `/api/store/update` | store / update | 需要 Web 登录会话 Cookie |

### 其他接口

| 方法 | 接口 | 说明 | 认证 |
| --- | --- | --- | --- |
| GET | `/api/mobile/discover` | mobile / discover | 需要 Web 登录会话 Cookie |
| POST | `/api/scrape` | scrape | 需要 Web 登录会话 Cookie |
| POST | `/api/setup` | setup | 需要 Web 登录会话 Cookie |
| POST | `/api/task-manager` | task manager | 需要 Web 登录会话 Cookie |
| POST | `/api/task-manager/kill` | task manager / kill | 需要 Web 登录会话 Cookie |
| POST | `/api/trash/empty` | trash / empty | 需要 Web 登录会话 Cookie |
| GET | `/api/trash/list` | trash / list | 需要 Web 登录会话 Cookie |
| POST | `/api/trash/restore` | trash / restore | 需要 Web 登录会话 Cookie |
| POST | `/api/update/apply` | update / apply | 需要 Web 登录会话 Cookie |
| POST | `/api/update/check` | update / check | 需要 Web 登录会话 Cookie |
| POST | `/api/update/upload` | update / upload | 需要 Web 登录会话 Cookie |

---

## 相关链接

| 内容 | 链接 |
| --- | --- |
| 系统能力原页 | <https://www.wanos.xyz/system-capabilities/> |
| WPK 应用开发文档 | <https://www.wanos.xyz/docs/wpk/> |
| 登录鉴权（OAuth） | <https://www.wanos.xyz/oauth/> |
| 使用说明 | <https://www.wanos.xyz/doc> |
| 刷机教程 | <https://www.wanos.xyz/flash/> |
| APP 下载 | <https://www.wanos.xyz/app/> |
| 交流论坛 | <https://www.wanos.xyz/forum/> |
