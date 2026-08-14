# DSH Remote — App Store 上架文案草稿

> 状态：草稿（待用户确认后由 asc 写入 App Store Connect）
> 对应 App 记录：`com.dshremote.app`（需先在 ASC 手动创建）

---

## 1. 基础信息

| 项目 | 值 | 备注 |
|---|---|---|
| App 名称 | **掌中鲸** | 30 字符内 ✓（原名 DSH Remote 可作备用/英文显示名） |
| 副标题 (Subtitle) | 中文：**远程掌控 Mac 上的 AI 智能体** ／ 英文：**Control your Mac's AI agent from iPhone** | 各 30 字符内，按语言本地化 |
| Bundle ID | `com.dshremote.app` | 已配好 |
| 主语言 | 简体中文 | UI 为中文（zh_CN） |
| 分类 (Primary) | **Developer Tools（开发者工具）** | 建议；备选 Productivity |
| 次要分类 | 无 | 可选 |
| 年龄分级 | **4+** | 无用户生成内容、无暴力/成人内容；仅本地网络通信 |
| 价格 | **免费 (Free)** | 待用户确认 |

---

## 2. 描述（Description）✅ 已确认

### 中文版

**掌中鲸**（DSH Remote）让你用 iPhone 实时查看和控制运行在 Mac 上的 DeepSeek Harness（DSH）AI 代理——开会、通勤、躺床上，随时掌握 AI 工作进度。

**核心功能：**
- **会话随时掌控**：浏览完整对话历史，实时跟进 AI 执行进度，随时发送消息或中断任务
- **审批中心**：AI 请求执行工具操作时，在手机上点一下即可批准或拒绝；需要提问时即时回答
- **目标看板**：创建、暂停、恢复、完成 AI 任务目标，进度一目了然
- **后台任务**：查看 workflow、子代理等任务的运行状态与输出
- **扫码配对，零配置**：Mac 伴侣 App 显示二维码，iPhone 扫码即连，无需手动输入任何地址或密钥
- **实时通知**：审批请求、提问、报错第一时间推送

**安全设计：** 配对密钥仅保存在本地，通信全程 Token 认证，Mac 上的 DSH 端口不暴露给局域网。

### English Version

**掌中鲸 (DSH Remote)** lets you view and control the DeepSeek Harness (DSH) AI agent running on your Mac, right from your iPhone — in meetings, on the go, or in bed.

**Features:**
- **Sessions at a glance**: Browse full conversation history, follow AI progress in real time, send messages, or interrupt tasks anytime
- **Approval center**: Approve or deny tool-call requests and answer agent questions with one tap
- **Goals board**: Create, pause, resume, and complete agent goals at a glance
- **Background tasks**: Monitor workflow and subagent status and output
- **Zero-config pairing**: Scan the QR code shown by the Mac companion app to connect instantly — no manual setup
- **Instant notifications**: Get notified on approval requests, questions, and errors

**Security**: Pairing keys stay on your device; all communication uses token authentication, and your Mac's DSH port is never exposed to the local network.

## 3. 关键词（Keywords，≤100 字符）✅ 已确认

### 英文（97 字符 ✓）
`deepseek, harness, dsh, ai agent, remote control, mac, chat, approval, task, workflow, codex, terminal`

### 中文（可选填）
`远程控制,人工智能,AI助手,智能体,会话,审批,任务,局域网,Mac,开发工具`

## 4. 审核信息（App Review Information）

| 项目 | 值 |
|---|---|
| 联系邮箱 | **depth.carols19@icloud.com** |
| 备注说明 | **必须写**：本 App 用于控制用户自己 Mac 上运行的 DeepSeek Harness，需与 Mac 伴侣 App 配对后使用。审核建议：提供演示视频，或说明审核环境无法完整演示（需 Mac 端安装 DSH 并运行）。 |
| 演示账号 | 不适用（无账号体系） |
| 是否包含登录 | 否 |

**重要提示**：审核员没有 Mac 伴侣 App 无法完整测试连接功能，建议：
1. 在审核备注中说明配对流程（附截图/录屏链接）
2. 或准备一段 30-60 秒的演示视频（Mac 端 + iPhone 端同屏）

---

## 5. 隐私政策 URL（必需）

**最终采用（项目仓库 GitHub Pages，审核 100% 可访问）**：
- **`https://masonliworks.github.io/DSHRemote/privacy/`** ← 上架时填这个
- 项目仓库：github.com/masonliworks/DSHRemote（公开，README 项目介绍 + privacy/ 隐私政策）
- 中英双语页面，含语言切换；源码 `privacy/index.html`

> 原方案 `https://aicetus.3366999.xyz/privacy.html` 因阿里云 ICP 备案未通过被拦截，已弃用。
> 临时仓库 `dp-remote-privacy` 已弃用（待删）。

---

## 6. 截图（最终确认 ✅，6 张，1290×2796）

> 用户提供终稿（`ui设计/design/appstore-screenshots/`），全部已为官方尺寸，按顺序整理在 `screenshots/final/`：

| 上架顺序 | 文件 | 原始文件 |
|---|---|---|
| 1（首图） | `screenshots/final/01.png` | shot-s1.png |
| 2 | `screenshots/final/02.png` | shot-s2.png |
| 3 | `screenshots/final/03.png` | shot-s3.png |
| 4 | `screenshots/final/04.png` | shot-s4.png |
| 5 | `screenshots/final/05.png` | shot-s5.png |
| 6 | `screenshots/final/06.png` | shot-s6.png |

> 上架时按 01→06 顺序上传（`asc screenshots upload`）。

---

## 7. 其他待办

- [x] 确认 App 名称/副标题/分类/价格（名称=掌中鲸，免费）
- [x] 确认关键词终稿
- [x] 提供联系邮箱（depth.carols19@icloud.com）
- [x] 选定隐私政策托管方案（GitHub Pages 已上线）
- [ ] 肉眼确认截图顺序（用户稍后提供最终截图）
- [ ] 在 ASC 创建 App 记录（我可以给你填表清单）
