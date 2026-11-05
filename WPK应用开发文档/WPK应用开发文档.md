# WPK 应用开发文档

> WanOS 应用安装包（`.wpk`）的开发、打包、调试与上架指南。整理自 <https://www.wanos.xyz/docs/wpk/>，本地离线版生成于 2026-11-05，正文与原文一致，仅做 Markdown 结构化。

| 项目 | 信息 |
| --- | --- |
| 文档来源 | <https://www.wanos.xyz/docs/wpk/> |
| 适用平台 | WanOS（玩客云 / 赚钱宝 / ARMv7 低功耗设备） |
| 推荐技术栈 | Go 静态编译单文件 + 内嵌 HTML |
| 安装包格式 | `.wpk`（本质是 zip） |
| 开发者工具 | [WanOS-WPK-Developer-Tool.exe](https://www.wanos.xyz/downloads/tools/WanOS-WPK-Developer-Tool.exe) · [SHA256 校验文件](https://www.wanos.xyz/downloads/tools/WanOS-WPK-Developer-Tool.exe.sha256) |
| 工具 SHA256 | `a9103ffb5fb66fa0bd51994afd2b903788a75e45f858dfcf46747b6e358288a6` |
| 应用上架 | <https://www.wanos.xyz/app-store/publish/> |

---

## 目录

- [应用必须满足什么条件](#应用必须满足什么条件)
- [WanOS 会帮你做什么](#wanos-会帮你做什么)
- [快速开始](#快速开始)
- [WPK 包结构](#wpk-包结构)
- [manifest.json 完整说明](#manifestjson-完整说明)
- [第三方应用开启公网访问](#第三方应用开启公网访问)
- [运行环境变量](#运行环境变量)
- [完整案例：Go + HTML 单文件应用](#完整案例go--html-单文件应用)
- [脚本规则](#脚本规则)
- [打包和本地校验](#打包和本地校验)
- [发布到应用商店](#发布到应用商店)
- [常见问题和排错](#常见问题和排错)

---

因为 Go 可以编译为二进制机器码，在低性能的盒子里面也可以流畅运行，这是 WPK 应用选择 Go 的主要优势，所以 WPK 应用推荐使用 Go + HTML 的单文件包装。WPK 是 WanOS 的应用安装包格式，开发者可以把一个带 Web 面板的应用打包成 `.wpk`，用户在 WanOS 文件管理器或应用商店中点击即可安装；静态页面、CSS、JS、图标和依赖都可以嵌入二进制或随包释放，适合玩客云、赚钱宝等 ARMv7 低功耗设备。

> 📌 **说明**：开发者工具是 Windows 绿色版，双击即可打开，也支持命令行创建模板、配置参数、打包 `.wpk` 和校验安装包。SHA256：`a9103ffb5fb66fa0bd51994afd2b903788a75e45f858dfcf46747b6e358288a6`

## 应用必须满足什么条件

- 必须提供 Web 前端，用户能通过浏览器打开应用面板。
- 必须监听一个 HTTP 端口，建议读取 `WANOS_APP_PORT`。
- 必须支持 ARMv7 Linux，Go 应用建议用 `GOOS=linux GOARCH=arm GOARM=7` 编译。
- 必须带图标，推荐 `icon.png`，尺寸 256x256 或 512x512。
- 不能要求用户手动执行命令，安装、启动、停止都要由包内脚本完成。

## WanOS 会帮你做什么

- 解压 WPK 到用户选择的安装目录。
- 创建应用数据目录，传入运行环境变量。
- 有 systemd 时创建并启动 service；没有 systemd 时用后台进程兼容启动。
- 把应用加入桌面和应用商店已安装列表。
- 读取包内图标，让文件管理器和安装界面显示应用自己的图标。

## 快速开始

**第 1 步：准备 Go 环境。**

Windows 安装 Go 后，在 PowerShell 中能执行下面命令即可。

```sh
go version
```

**第 2 步：创建一个 Web 应用。**

应用启动后监听 `0.0.0.0:$WANOS_APP_PORT`，不要只监听 `127.0.0.1`，否则局域网和 WanOS 反代可能访问不到。

**第 3 步：编译 ARMv7 二进制。**

使用下面参数交叉编译，尽量静态编译，减少系统依赖。

```sh
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o bin/your-app .
```

**第 4 步：写 manifest.json 和 scripts。**

告诉 WanOS 应用名称、端口、入口路径、启动脚本和停止脚本，让安装、启动、停止、卸载都能自动完成。

**第 5 步：打包成 .wpk。**

WPK 本质是 zip 包，扩展名是 `.wpk`。上传到 WanOS 后点击即可安装。

## WPK 包结构

推荐使用 WPK v1 结构，根目录必须有 `manifest.json`。压缩时不要把外层项目目录多套一层；如果多套一层，WanOS 会尝试自动识别，但不建议依赖这个兼容逻辑。

```text
hello-wpk.wpk
├─ manifest.json
├─ icon.png
├─ bin/
│  └─ hello-wpk
├─ web/
│  └─ index.html
└─ scripts/
   ├─ install.sh
   ├─ start.sh
   ├─ stop.sh
   └─ uninstall.sh
```

> ⚠️ **注意**：不要把 x86 Windows 程序、exe、amd64 Linux 程序直接改名成 `.wpk`。WanOS 设备是 ARMv7，二进制架构不对会安装失败或启动失败。

## manifest.json 完整说明

```json
{
  "wpk_version": 1,
  "id": "hello-wpk",
  "name": "Hello WPK",
  "version": "1.0.0",
  "description": "第一个 WanOS WPK 示例应用",
  "arch": ["armv7"],
  "permissions": ["storage.readwrite"],
  "type": "web",
  "icon": "icon.png",
  "entry": {
    "port": 42181,
    "path": "/",
    "open_mode": "new_page"
  },
  "public_access_supported": true,
  "public_access": true,
  "service": {
    "name": "hello-wpk",
    "start": "scripts/start.sh",
    "stop": "scripts/stop.sh"
  },
  "install": {
    "install_dir": "/opt/wanos/apps/hello-wpk",
    "data_dir": "/opt/wanos-data/apps/hello-wpk",
    "scripts": {
      "install": "scripts/install.sh",
      "uninstall": "scripts/uninstall.sh"
    }
  }
}
```

| 字段 | 是否必填 | 说明 |
| --- | --- | --- |
| `wpk_version` | 必填 | 当前填 `1`。WanOS 用它识别新格式 WPK。 |
| `id` | 必填 | 应用唯一 ID，只用小写字母、数字、`-`、`_`，例如 `cloudflare-tunnel`。 |
| `name` | 必填 | 用户看到的应用名称，例如 `Cloudflare 内网穿透`。 |
| `version` | 必填 | 应用版本号，建议语义化版本，例如 `1.0.0`。 |
| `description` | 建议填写 | 应用简介，会在安装和应用商店中展示。 |
| `arch` | 建议填写 | 支持架构。玩客云、赚钱宝常用 `armv7`。 |
| `permissions` | 按需填写 | 应用请求的系统权限。安装前 WanOS 会弹窗让用户确认，例如 `storage.readwrite` 表示存储读写权限。 |
| `icon` | 必填 | 包内图标路径，支持 PNG/JPG/WebP，推荐 `icon.png`。 |
| `entry.port` | 必填 | Web 面板端口。安装后 WanOS 会把这个端口写入 `WANOS_APP_PORT`。 |
| `entry.path` | 必填 | 打开应用时的路径，通常是 `/`。 |
| `entry.open_mode` | 必填 | `new_page` 表示新页面打开；`popup` 表示弹窗打开。完整 Web 应用建议用 `new_page`。 |
| `public_access_supported` | 按需填写 | 设为 `true` 后，应用右键菜单会出现公网访问能力。应用必须有 `entry.port`，WanOS 才能把公网域名转发到本地端口。 |
| `public_access` | 按需填写 | 兼容应用商店字段，设为 `true` 表示该应用允许用户开启公网入口。未声明的应用不会显示右键公网菜单。 |
| `service.start` | 必填 | 启动脚本路径。脚本必须能以前台方式启动应用。 |
| `service.stop` | 建议填写 | 停止脚本路径。没有特殊清理逻辑时可直接 `exit 0`。 |
| `install.scripts.install` | 建议填写 | 安装脚本。用于创建目录、复制文件、初始化数据。 |
| `install.scripts.uninstall` | 建议填写 | 卸载脚本。用于清理临时文件，用户数据是否删除要谨慎。 |

## 第三方应用开启公网访问

如果 WPK 应用是网页服务，并且希望用户可以从外网打开，需要在 `manifest.json` 里声明公网访问能力。声明后，用户在桌面或应用导航里右键应用，会看到“公网访问”；开启成功后 WanOS 会保存公网地址，下次右键直接显示“复制公网链接”。

```json
{
  "id": "demo-web-app",
  "name": "示例网页应用",
  "entry": {
    "port": 8787,
    "path": "/",
    "open_mode": "new_page"
  },
  "public_access_supported": true,
  "public_access": true
}
```

### 工作流程

1. 应用监听 `0.0.0.0:$WANOS_APP_PORT`，并保证 `entry.port` 和实际端口一致。
2. 用户先在 WanOS “远程访问”里开通内网穿透。
3. 用户右键应用选择“公网访问”。
4. WanOS 调用 `/api/tunnel/app-domain` 创建应用公网入口，转发到 `127.0.0.1:entry.port`。
5. 成功后保存 `public_url`，刷新页面或应用列表后仍可直接复制公网链接。

```js
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

> ⚠️ **注意**：不要给所有应用默认开启公网能力。只有明确需要外网访问、并且对外暴露页面没有安全风险的应用，才在 manifest 里声明 `public_access_supported`。

## 运行环境变量

WanOS 启动应用时会注入以下变量。应用代码和脚本都应该优先读取这些变量，不要写死路径。

| 变量 | 说明 | 示例 |
| --- | --- | --- |
| `WANOS_APP_ID` | 应用 ID | `hello-wpk` |
| `WANOS_APP_NAME` | 应用名称 | `Hello WPK` |
| `WANOS_APP_PORT` | Web 服务端口 | `42181` |
| `WANOS_APP_PATH` | Web 入口路径 | `/` |
| `WANOS_APP_ROOT` | 应用安装目录 | `/mnt/wanos/.../hello-wpk/app` |
| `WANOS_APP_DATA` | 应用数据目录 | `/mnt/wanos/.../hello-wpk/data` |
| `APP_DIR` | 兼容变量，等同安装目录 | `$WANOS_APP_ROOT` |
| `DATA_DIR` | 兼容变量，等同数据目录 | `$WANOS_APP_DATA` |

## 完整案例：Go + HTML 单文件应用

下面这个案例可以直接复制。它会启动一个 HTTP 服务，显示应用名称、数据目录和当前时间。HTML 嵌入到 Go 二进制里，不依赖外部前端框架。

### 1. 创建目录

```sh
mkdir hello-wpk
cd hello-wpk
mkdir bin scripts
```

### 2. main.go

```go
package main

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"time"
)

const page = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{{.Name}}</title>
  <style>
    body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f6f8fb;color:#111827}
    main{min-height:100vh;display:grid;place-items:center;padding:24px}
    section{max-width:620px;background:white;border:1px solid #e5e7eb;border-radius:12px;padding:28px;box-shadow:0 18px 50px rgba(15,23,42,.08)}
    h1{margin:0 0 10px;font-size:28px}
    p{line-height:1.7;color:#64748b}
    code{background:#eef2ff;border-radius:6px;padding:2px 6px}
  </style>
</head>
<body>
  <main>
    <section>
      <h1>{{.Name}}</h1>
      <p>这是一个 WanOS WPK 示例应用。</p>
      <p>应用 ID：<code>{{.ID}}</code></p>
      <p>数据目录：<code>{{.Data}}</code></p>
      <p>当前时间：{{.Now}}</p>
    </section>
  </main>
</body>
</html>`

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	id := env("WANOS_APP_ID", "hello-wpk")
	name := env("WANOS_APP_NAME", "Hello WPK")
	dataDir := env("WANOS_APP_DATA", "./data")
	port := env("WANOS_APP_PORT", "42181")

	if err := os.MkdirAll(dataDir, 0755); err != nil {
		log.Fatal(err)
	}

	tpl := template.Must(template.New("page").Parse(page))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		_ = tpl.Execute(w, map[string]string{
			"ID": id,
			"Name": name,
			"Data": dataDir,
			"Now": time.Now().Format("2006-01-02 15:04:05"),
		})
	})

	addr := "0.0.0.0:" + port
	fmt.Println("listen", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```

### 3. manifest.json

```json
{
  "wpk_version": 1,
  "id": "hello-wpk",
  "name": "Hello WPK",
  "version": "1.0.0",
  "description": "WanOS WPK 入门示例应用",
  "arch": ["armv7"],
  "permissions": ["storage.readwrite"],
  "type": "web",
  "icon": "icon.png",
  "entry": {
    "port": 42181,
    "path": "/",
    "open_mode": "new_page"
  },
  "service": {
    "name": "hello-wpk",
    "start": "scripts/start.sh",
    "stop": "scripts/stop.sh"
  },
  "install": {
    "install_dir": "/opt/wanos/apps/hello-wpk",
    "data_dir": "/opt/wanos-data/apps/hello-wpk",
    "scripts": {
      "install": "scripts/install.sh",
      "uninstall": "scripts/uninstall.sh"
    }
  }
}
```

### 4. scripts/install.sh

```sh
#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_ROOT:-${APP_DIR:-/opt/wanos/apps/hello-wpk}}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-${DATA_DIR:-/opt/wanos-data/apps/hello-wpk}}"
mkdir -p "$APP_DIR" "$DATA_DIR"
cp -R bin scripts manifest.json "$APP_DIR/"
[ -f icon.png ] && cp icon.png "$APP_DIR/icon.png"
chmod +x "$APP_DIR/bin/hello-wpk" "$APP_DIR/scripts/"*.sh 2>/dev/null || true
echo "installed to $APP_DIR"
```

### 5. scripts/start.sh

```sh
#!/bin/sh
set -eu
APP_DIR="${WANOS_APP_INSTALL_ROOT:-${APP_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}}"
cd "$APP_DIR"
exec "$APP_DIR/bin/hello-wpk"
```

### 6. scripts/stop.sh 和 scripts/uninstall.sh

```sh
#!/bin/sh
set -eu
exit 0
```

### 7. 编译 ARMv7

```text
# PowerShell
$env:GOOS='linux'
$env:GOARCH='arm'
$env:GOARM='7'
$env:CGO_ENABLED='0'
go build -trimpath -ldflags='-s -w' -o bin/hello-wpk .

# Linux/macOS shell
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o bin/hello-wpk .
```

## 脚本规则

- `install.sh` 在安装时执行，超时时间约 2 分钟，不要做长时间下载任务。
- `start.sh` 必须以前台方式启动应用，最后一行建议用 `exec`。
- `stop.sh` 只做必要清理，WanOS 会负责停止 systemd 服务或后台进程。
- `uninstall.sh` 不建议默认删除用户数据，除非用户明确选择清理数据。
- 脚本必须兼容 `/bin/sh`，不要依赖 Bash 专属语法。

> ✅ **提示**：低配 ARMv7 设备 CPU 和内存都有限，安装脚本要短，运行服务要轻。大型依赖建议由应用首次打开后按需下载，并在 UI 上显示进度。

## 打包和本地校验

### 方式一：使用 WPK 开发者工具

1. 打开 `WanOS-WPK-Developer-Tool.exe`。
2. 填写应用 ID、名称、版本、端口、入口路径和图标。
3. 选择项目目录，点击一键打包。
4. 工具会生成 `.wpk` 和 SHA256。

### 方式二：命令行打包

```ps1
# 在项目目录内执行，把内容压成 zip，但扩展名用 .wpk
powershell Compress-Archive -Path manifest.json,icon.png,bin,scripts -DestinationPath hello-wpk.zip -Force
ren hello-wpk.zip hello-wpk.wpk
```

### 使用开发者工具命令行

```sh
python tools/wpk_dev_tool.py init ./hello-wpk --id hello-wpk --name "Hello WPK" --port 42181
python tools/wpk_dev_tool.py pack ./hello-wpk --out ./dist/hello-wpk.wpk
python tools/wpk_dev_tool.py validate ./dist/hello-wpk.wpk
```

### 在 WanOS 上测试

1. 把 `hello-wpk.wpk` 上传到文件管理器。
2. 点击安装包，选择安装目录。
3. 确认弹窗显示应用名称和图标。
4. 安装完成后，在桌面或应用商店已安装里打开。
5. 如果打不开，先看安装日志，再检查端口是否监听。

## 发布到应用商店

应用商店不是直接上传就上架。开发者提交 WPK 后会进入官方审核，通过后才会进入商店列表。

- 必须上传 `.wpk` 单文件包。
- 必须上传应用图标。
- 必须填写应用名称、ID、版本、端口、说明和联系方式。
- 必须带 Web 前端，审核时会安装并打开测试。
- 不能包含挖矿、恶意下载、破坏系统、未经说明的远程控制逻辑。

## 常见问题和排错

### 提示“未找到 Go 单文件二进制”

通常是包里没有 ARMv7 Linux 可执行文件，或者只放了 Windows exe。用 `GOOS=linux GOARCH=arm GOARM=7` 重新编译。

### 安装完成但打不开

- 检查应用是否监听 `0.0.0.0:$WANOS_APP_PORT`。
- 检查 `entry.port` 是否和程序实际监听端口一致。
- 检查 `scripts/start.sh` 是否有 `exec "$APP_DIR/bin/xxx"`。
- 检查程序是否依赖设备上没有的 glibc 或动态库。Go 建议 `CGO_ENABLED=0`。

### 图标不显示

确认 `manifest.json` 的 `icon` 路径正确，文件在包内，格式为 PNG/JPG/WebP。推荐直接放根目录 `icon.png`。

### 端口被占用

换一个大于 1024 的端口，例如 `42181`、`42182`。不要使用 WanOS 面板端口、80、443、22 等系统端口。

### systemd 不存在怎么办

WanOS 安装器会兼容没有 systemd 的轻量系统，无法写入 systemd 服务时会退回后台进程方式启动。应用自己不要强依赖 systemctl。

### 可以打包 Node、Python、PHP 应用吗

可以，但不推荐让用户设备临时安装一堆依赖。最稳的是 Go 单文件。如果必须用 Node/Python/PHP，需要把运行时和依赖做成按需离线包，并在应用 UI 中明确提示安装组件。

---

## 附录：相关链接

| 内容 | 链接 |
| --- | --- |
| WPK 文档原页 | <https://www.wanos.xyz/docs/wpk/> |
| 开发者工具下载 | <https://www.wanos.xyz/downloads/tools/WanOS-WPK-Developer-Tool.exe> |
| 开发者工具 SHA256 | <https://www.wanos.xyz/downloads/tools/WanOS-WPK-Developer-Tool.exe.sha256> |
| 提交 WPK 应用审核 | <https://www.wanos.xyz/app-store/publish/> |
| WanOS 系统能力 | <https://www.wanos.xyz/system-capabilities/> |
| 刷机教程 | <https://www.wanos.xyz/flash/> |
| 交流论坛 | <https://www.wanos.xyz/forum/> |
| 官方联系 QQ | 1546912750 |
