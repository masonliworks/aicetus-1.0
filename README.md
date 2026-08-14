# DSH Remote — 用 iPhone 远程控制 DeepSeek Harness

在手机上实时查看和控制运行在 Mac 上的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)：

- **会话**：会话列表 + 完整对话历史（`session.history` 全量重建）、发消息、中断
- **审批**：工具调用审批（允许一次 / 拒绝）、回答 Agent 提问 —— 会话内嵌 + 独立聚合 Tab
- **目标**：Goal 看板（创建 / 暂停 / 恢复 / 完成 / 清除），会话内显示目标条
- **任务**：会话内的后台任务（workflow、subagent）状态与输出
- **配对**：Mac 伴侣 App 显示二维码 → iPhone 扫码即连，零输入
- **通知**：审批请求 / Agent 提问 / 报错时本地通知

## 架构

```
┌─────────────────────┐                        ┌──────────────────┐   loopback   ┌──────────────────┐
│  iPhone App (iOS 17+)│  HTTP + Token          │  dsh-remote-bridge│ ───────────► │ dsh web (3080)   │
│  原生 SwiftUI        │ ◄─── SSE 事件流 ──────►│  (Node, 零依赖)    │ ◄── WS 下行 ──│  (DSH harness)   │
│  扫码配对 dshremote://│                        └────────▲─────────┘              └──────────────────┘
└─────────────────────┘                                 │ 内置并自动管理（启动/停止/监控）
                                                        │
                                            ┌───────────┴──────────┐
                                            │ Mac 伴侣 App          │
                                            │ (原生 SwiftUI, macOS 14+)│
                                            │ 检测/安装 DSH + 二维码   │
                                            └──────────────────────┘
```

- **`macos/DSHRemoteMac/`** — Mac 伴侣 App：检测 DSH 是否安装（一键 npm 安装）、
  内置桥接服务并自动管理、显示配对二维码（`dshremote://pair?...` 自定义 scheme）。
- **`bridge/`** — Node 桥接服务（零依赖，Node ≥ 22），被 Mac App 内置；也可独立手动运行。
  Token 认证 + 方法白名单，DSH 的 3080 端口不暴露给局域网。
- **`ios/DSHRemote/`** — 原生 SwiftUI App（iOS 17+）：扫码配对（AVFoundation）、
  会话历史重建、审批/目标/任务、通知。
- **`docs/ui-design-spec.md`** — iOS 端 UI 设计标准（tokens / 组件 / 页面 / 交互），供 UI 设计师执行。

## 快速开始（推荐路径：Mac 伴侣 App）

1. **Mac 上打开伴侣 App**：`open macos/DSHRemoteMac/DSHRemoteMac.xcodeproj`，用 Xcode 运行（⌘R）
   - App 自动检测 DSH：未安装则点「安装」一键完成（`npm install -g @deepseek-ai/dsh`）
   - 确认 DSH 在跑（终端执行 `dsh web`，或让 App 提示你启动）
   - 点「启动」桥接服务 → App 显示**配对二维码**
2. **iPhone 安装 App**：`open ios/DSHRemote/DSHRemote.xcodeproj` → Signing 选 Team → 真机 ⌘R
3. **扫码配对**：iPhone 打开 App → 设置 → **扫码配对** → 对准 Mac 屏幕二维码 → 自动连接

### 手动路径（不用 Mac App）

```bash
cd bridge && ./start.sh          # 打印 token
ipconfig getifaddr en0           # 查 Mac 局域网 IP
# iPhone 设置页手动输入 http://<IP>:3878 和 token
```

## 配对协议

二维码内容：`dshremote://pair?host=<局域网IP>&port=3878&token=<token>`

- iOS 注册了 `dshremote://` scheme：扫码或从任何地方点击该链接都会自动填充并连接。
- Token 存储于 Mac 的 `~/.dsh-remote-bridge/token`（600 权限），Mac App 与手动 bridge 共用。

## 安全说明

- 桥接服务所有接口要求 `Authorization: Bearer <token>`（常量时间比较）；`/healthz` 仅存活探针。
- 方法白名单：仅控制与只读方法（`session.*`、`subagent.*`、`goal.*`、`workspace.*`、`llm.*` 只读、
  `host.describe`、`host.listDirectory`）。`settings.*`、`credentials.*` 不暴露。
- 建议只在可信网络使用；跨公网请加 TLS 反向代理（如 caddy）。

## 项目结构

```
├── bridge/                       # Node 桥接（零依赖）
│   ├── server.js / dsh-client.js / start.sh
├── macos/DSHRemoteMac/           # Mac 伴侣 App（SwiftUI）
│   ├── gen-project.mjs           # pbxproj 生成器
│   └── DSHRemoteMac/
│       ├── Services/             # DshInstaller / BridgeManager / ProcessRunner
│       ├── Models/PairingInfo.swift  # LAN IP、scheme URL、二维码生成
│       └── Resources/bridge/     # 内置的桥接代码（与 bridge/ 同步）
├── ios/DSHRemote/                # iOS App（SwiftUI）
│   ├── gen-project.mjs
│   └── DSHRemote/
│       ├── Models/               # 协议信封、领域模型、历史重建解析器
│       ├── Networking/           # BridgeClient（REST+SSE）、ServerConfig（Keychain）
│       ├── Stores/AppState.swift # 连接、会话、审批、历史、通知
│       └── Views/                # 会话/对话/审批/目标/任务/设置/扫码
└── docs/ui-design-spec.md        # iOS 端 UI 设计标准
```

## 桥接服务 API（App 视角）

| 端点 | 说明 |
|---|---|
| `GET /healthz` | 存活探针（无需认证） |
| `POST /api/<method>` | 转发 DSH unary RPC（白名单内，含 `session.history`） |
| `POST /api/respond` | 审批 / 提问应答（rpcId 回带事件帧的 rpcId） |
| `GET /api/events` | SSE 事件流：`event: mux` / `event: host` |

## 开发备注

- 新增 Swift 文件后重跑对应目录的 `node gen-project.mjs` 再构建。
- 本仓库验证构建时因受限环境需 `OTHER_SWIFT_FLAGS='-disable-sandbox'`
  （Swift 6.4 工具链已知问题 [swift#88397](https://github.com/swiftlang/swift/issues/88397)）；
  Xcode GUI 正常构建无需任何额外参数。
- 桥接代码有两份（`bridge/` 为手动模式源，`macos/.../Resources/bridge/` 为内置副本），
  改动后需同步复制。

## 进阶：APNs 推送

当前版本在 App 运行时通过事件流触发本地通知。要做到 App 完全退出的推送：
桥接服务增加推送端点 → APNs，App 注册远程通知上报 device token。架构已预留
（`AppState.notify` 统一入口），需要 Apple Developer 账号 + 推送证书。

## 下载与授权

- **安装包下载**：见右侧 **Releases**（GitHub Releases），当前版本 `掌中鲸伴侣-0.8.0.dmg`。
- **授权声明**：本仓库代码**未采用任何开源许可证（All Rights Reserved）**。仅供浏览与学习参考；
  任何形式的使用、复制、修改、分发或商业利用，均需事先取得作者书面授权。
- **联系授权**：`depth.carols19@icloud.com`
