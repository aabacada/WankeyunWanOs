# WanOS ID OAuth 登录

> 第三方网页应用可以接入 WanOS ID，使用授权码模式获取用户基础身份信息。
>
> 整理自 <https://www.wanos.xyz/oauth/>，本地离线版生成于 2026-11-05。正文与原文一致；仅标注「整理补充」的两处为便于阅读所加，原文并无。

| 项目 | 信息 |
| --- | --- |
| 页面来源 | <https://www.wanos.xyz/oauth/> |
| 授权模式 | Authorization Code（授权码） |
| 授权域名 | `https://wanos.xyz` |
| 示例 scope | `openid profile points`（空格分隔） |
| 客户端类型 | 公开应用无需 `client_secret`；可信应用可直接按 `order_id` 扣积分 |

---

## 目录

- [接口](#接口)
- [授权地址示例](#授权地址示例)
- [换取 Token](#换取-token)
- [扣积分示例](#扣积分示例)
- [跳转确认扣积分](#跳转确认扣积分)
- [无回调地址](#无回调地址)
- [用户信息返回示例](#用户信息返回示例)

---

## 接口

| 地址 | 说明 |
| --- | --- |
| `GET /oauth/authorize` | 跳转 WanOS ID 授权页，公开应用不用预先创建 `client_secret` |
| `POST /oauth/token` | 授权码换 `access_token` / `id_token`；公开应用不需要 `client_secret` |
| `GET /oauth/userinfo` | Bearer token 获取用户信息，授权 `points` 时返回积分 |
| `GET /oauth/points` | 查询当前授权用户积分余额，需要 `points` scope |
| `POST /oauth/points` | 可信应用直接按 `order_id` 扣积分；公开应用请走确认页 |
| `GET /oauth/points/authorize` | 普通第三方应用跳转到官网确认扣积分，支持不传回调地址 |

---

## 授权地址示例

```text
https://wanos.xyz/oauth/authorize?client_id=my-lan-app&app_name=局域网应用&redirect_uri=http%3A%2F%2F192.168.1.10%3A8080%2Fcallback&response_type=code&scope=openid%20profile%20points&state=random
```

**参数说明（整理补充，原文未逐项解释，据示例链接推导）**

| 参数 | 示例值 | 说明 |
| --- | --- | --- |
| `client_id` | `my-lan-app` | 应用标识，公开应用自行约定 |
| `app_name` | `局域网应用` | 授权页展示的应用名称 |
| `redirect_uri` | `http://192.168.1.10:8080/callback` | 回调地址，需 URL 编码；可省略 |
| `response_type` | `code` | 固定为授权码模式 |
| `scope` | `openid profile points` | 以空格分隔，需 URL 编码为 `%20` |
| `state` | `random` | 随机串，回调时原样带回 |

---

## 换取 Token

```text
POST https://wanos.xyz/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
client_id=my-lan-app&
redirect_uri=https://example.com/callback&
code=AUTH_CODE
```

---

## 扣积分示例

```json
POST https://wanos.xyz/oauth/points
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{
  "amount": 5,
  "order_id": "app-order-10001",
  "reason": "下载附件"
}
```

---

## 跳转确认扣积分

```text
https://wanos.xyz/oauth/points/authorize?
client_id=my-lan-app&
app_name=局域网应用&
amount=5&
order_id=app-order-10001&
reason=下载附件&
redirect_uri=https%3A%2F%2Fexample.com%2Fpoints-callback&
state=random
```

---

## 无回调地址

局域网应用不方便回调时，可以不传 `redirect_uri`。登录授权会在官网页面显示一次性授权码；扣积分确认会在官网页面直接显示扣除结果。

```text
https://wanos.xyz/oauth/points/authorize?
client_id=my-lan-app&
app_name=局域网应用&
amount=5&
order_id=app-order-10001&
reason=下载附件
```

---

## 用户信息返回示例

授权范围包含 `profile` 时，`/oauth/userinfo` 和 `id_token` 都会返回头像字段。第三方应用可优先使用 `picture`，也可使用 `avatar`。

```json
GET https://wanos.xyz/oauth/userinfo
Authorization: Bearer ACCESS_TOKEN

{
  "sub": "wanos_id",
  "wanos_id": "wanos_id",
  "name": "WanOS 用户",
  "avatar": "https://wxqun988.vxjuejin.com/forum/images/20260724/avatar.png",
  "picture": "https://wxqun988.vxjuejin.com/forum/images/20260724/avatar.png",
  "device_count": 1
}
```

---

## 相关链接

| 内容 | 链接 |
| --- | --- |
| 登录鉴权原页 | <https://www.wanos.xyz/oauth/> |
| 系统能力与 API | <https://www.wanos.xyz/system-capabilities/> |
| WPK 应用开发文档 | <https://www.wanos.xyz/docs/wpk/> |
| 使用说明 | <https://www.wanos.xyz/doc> |
| 交流论坛 | <https://www.wanos.xyz/forum/> |
| 官方联系 QQ | 1546912750 |
