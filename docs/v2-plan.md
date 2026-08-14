# 掌中鲸 2.0 开发计划

版本 2.0.0。已确认的产品决策：

- 分发：iOS App Store 上架（订阅走苹果 IAP）
- 登录：仅 Apple 登录（Sign in with Apple）
- 后端：自建轻量服务（Node + SQLite，部署国内 VPS）
- 付费墙：免费 = 局域网控制；付费 = 仪表 + 广域网 + 多设备

## 一、仪表（数据链路，纯本地，先行）

五项指标的数据源与归属：

| 指标 | 数据源 | 收集者 |
|---|---|---|
| 连接状态 | bridge healthz（DSH 可达）+ iOS 本地链路状态 | 桥接 + iOS |
| 活跃会话数 | `session.list` 的 `running` | 桥接（已有） |
| 今日 token | 事件流 `session/projection`（tokenUsage 增量累计 + 每日落盘基线） | 桥接 |
| 今日使用金额 | 今日 token × 模型单价（`bridge/pricing.json` 价格表） | 桥接 |
| API 余额 | DeepSeek `GET /user/balance`（key 来自 `~/.dsh/.credentials.yaml`，仅 Mac 本机调用） | 桥接 |

- 桥接新增 `dashboard.summary` 方法（白名单内），iOS/Mac 均经 POST 轮询获取（30s 低频）。
- 约束：API key 不出 Mac；金额为估算值（DeepSeek 无日账单公开 API）。
- 已知偏差：桥接停机期间的 token 用量无法回填（首观测建立基线，不重复计入）。

## 二、Apple 登录（自建后端）

- 后端目录 `backend/`：Node 零依赖起步，SQLite（`users`、`sessions`、`entitlements` 表）。
- Apple 登录流程：iOS 用 AuthenticationServices 取 identity token → 后端经 Apple JWKS 验签 → 建/查用户 → 签发自有 access token（iOS 存 Keychain）。
- 权益模型：`entitlements.tier` ∈ {free, pro}，2.0 先占位（仪表未解锁时显示锁定态）。
- 本地控制面不依赖登录：未登录/断网时局域网控制、会话、审批照常可用。

## 三、订阅（App Store IAP）

- App Store Connect：订阅组 + 产品配置（用户后台操作，`asc` 工具辅助）。
- iOS：StoreKit 2 购买/恢复/订阅状态；收据信息上报后端。
- 后端：App Store Server Notifications v2 webhook + App Store Server API 票据校验，校验通过下发 pro 权益。
- 沙盒联调走 TestFlight + StoreKit 沙盒。

## 四、付费墙联动（仪表 gating / 广域网 / 多设备）

- 2.0 后期：仪表页未订阅显示锁定；广域网需中继服务器（独立工程，可延至 2.1）；多设备 = 同账号 Mac 伴侣登录 + 用量/配置云端同步。

## 五、里程碑

1. M1 仪表数据链路：桥接 dashboard.summary + iOS 仪表页 + Mac 概览接入（本轮）
2. M2 登录：backend auth + iOS 登录页 + 权益占位
3. M3 订阅：IAP + 服务端校验 + 付费墙
4. M4 版本 2.0.0 收尾 + 发布前审核

## 六、版本与工程

- 版本号 2.0.0 落两工程（gen-project.mjs MARKETING_VERSION）+ bridge package.json。
- 桥接双副本同步（bridge/ ↔ Mac Resources/bridge）。
