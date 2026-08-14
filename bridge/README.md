# dsh-remote-bridge

Token 认证的桥接服务：把 iOS 远程 App 安全地接到本地 DeepSeek Harness（`dsh web`）。

零 npm 依赖（仅用 Node ≥ 22 内置的 `fetch` / `WebSocket` / `http`）。

## 为什么需要桥

DSH 官方明确其 Web 服务**尚无认证层**（只有浏览器信任围栏：loopback / LAN IP 字面量 /
`--trusted-host`）。直接把 3080 暴露到局域网 = 同网段任何人都能控制你的 agent
（它能执行 bash）。桥接服务：

1. 增加 **Bearer Token 认证**（常量时间比较，token 自动生成于 `~/.dsh-remote-bridge/token`，600 权限）
2. **白名单转发**：只放行控制/只读方法（`session.*`、`subagent.*`、`goal.*`、`workspace.*`、
   `llm.*` 只读、`host.describe`、`host.listDirectory`）。`settings.*`、`credentials.*` 等
   敏感配置面不暴露
3. **事件流**：把 DSH 的两条 WebSocket 下行流（`events.mux` / `events.host`）转成单条 SSE
   连接（`event: mux` / `event: host`），保留帧的 `rpcId`（应答审批/提问时要回带）

## 启动

```bash
./start.sh                      # dsh 默认 http://127.0.0.1:3080，监听 0.0.0.0:3878
DSH_URL=http://127.0.0.1:3080 ./start.sh --port 8080 --token my-token
```

| 参数 / 环境变量 | 默认 | 说明 |
|---|---|---|
| `--dsh-url` / `DSH_URL` | `http://127.0.0.1:3080` | dsh web 地址 |
| `--host` / `DSH_REMOTE_HOST` | `0.0.0.0` | 监听地址 |
| `--port` / `DSH_REMOTE_PORT` | `3878` | 监听端口 |
| `--token` / `DSH_REMOTE_TOKEN` | 自动生成 | 认证 Token |

## HTTP API

| 端点 | 认证 | 说明 |
|---|---|---|
| `GET /healthz` | 无 | 存活 + dsh 可达性 |
| `POST /api/<method>` | Bearer | 转发 unary RPC（白名单内） |
| `POST /api/respond` | Bearer | 审批/提问应答（`client-response` 信封） |
| `GET /api/events` | Bearer（header 或 `?token=`） | SSE 事件流 |

报文格式与 DSH 原生协议一致（见 `dsh-client.js` 头注释的协议说明），所以
**App 侧的实现就是 DSH 浏览器客户端的子集**。

## 扩展指引：APNs 推送

要让 App 完全退出后也能收到"待审批"推送：

1. 在桥接服务加 `POST /api/push-token`（认证后登记 `deviceToken`，存 JSON 文件）
2. 监听 DSH 事件流中的 `approval/requested` / `question/requested` / `host/agent-error`，
   经 APNs（`apns` HTTP/2 接口 + 推送证书或 key）发通知
3. App 侧：`registerForRemoteNotifications` + `didRegisterForRemoteNotificationsWithDeviceToken`
   上报 token；前台事件照旧走 SSE

## 安全建议

- 只在可信网络使用；跨公网请在前面加 TLS 反向代理（如 caddy 自动 HTTPS）
- 定期轮换 token（删除 `~/.dsh-remote-bridge/token` 重启即重新生成）
- 白名单按需裁剪：编辑 `server.js` 里的 `WHITELIST`
