# DSH Remote / 掌中鲸 — 设计工作交接文档

> 写于 2026-08-14 · 供后续 Agent 接手使用
> 本工作区：`/Users/lifengzhi/WorkBuddy/2026-08-14-01-35-52/`

---

## 1. 项目背景（先读这个，避免走弯路）

存在**两个相关但定位不同的产物**，接手时务必分清：

| | DSH Remote（真实项目） | 掌中鲸 PocketWhale（概念探索） |
|---|---|---|
| 路径 | `/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/` | 本工作区 |
| 状态 | 功能与数据流已实现，有正式 UI 规范 v0.3 | 仅有品牌概念稿 |
| 设计语言 | iOS 原生、克制专业（规范强制） | 明亮渐变、品牌化组件 |
| 权威文档 | `docs/ui-design-spec.md`（v0.3） | 本工作区 design/ 下的探索稿 |

**关键约束**：做 DSH Remote 正式 UI 必须遵守其规范，不得沿用掌中鲸探索稿的视觉风格。

### DSH Remote 规范要点（v0.3 摘要）
- 平台：iPhone iOS 17+，原生 SwiftUI，设计基准 390×844 pt，浅/深双模式
- 基调：专业、可信、克制；信息密度优先，装饰从简
- 信息架构：仅「会话」「设置」两个 Tab；**审批/目标/任务不是独立页面**，是会话详情内的紧凑组件
- 颜色：accent `#0A84FF`；running `#30D158`；idle `#8E8E93`；waiting `#FF9F0A`（深 `#FFD60A`）；danger `#FF3B30`（深 `#FF453A`）；complete `#007AFF`。浅色底 `#F2F2F7`，深色底 `#000`，卡片 `#FFF`/`#1C1C1E`
- 字体：系统字体（不引自定义）；代码用 SF Mono
- 栅格/圆角：8pt 栅格（页面左右留白 16）；radius 8/12/16/pill
- 重要规则：列表卡片**不用阴影**；横幅/审批条/输入栏用 `.bar` 材质；语义色仅用于状态与徽标
- 发送模式：排队（默认）/ 插话（accent 高亮）；会话详情全屏隐藏 Tab bar

---

## 2. 产出物清单（本工作区）

### 2.1 正式设计稿（按规范 v0.3 制作，最新、以此为准）
| 文件 | 内容 |
|---|---|
| `design/dsh-remote-ios.html` | iOS 端 3 屏：①会话列表（浅色，工作区分栏+审批徽标）②会话详情全貌（浅色 P0：流式气泡/思考·工具抽屉/队列卡片/目标条/任务条/审批卡/底部信息栏/排队输入栏）③深色模式（提问卡+模型 popover+插话模式+上下文 87% 圆环变色） |
| `design/dsh-remote-ios-p1.html` | iOS 端 P1 5 屏：会话列表深色版 / 新建会话 sheet / 创建目标 sheet / 设置页（§6.4 全分组）/ 扫码配对取景页（四角框+扫描线动效） |
| `design/dsh-remote-mac.html` | Mac 伴侣 App：主窗口（概览/配对二维码 `dshremote://` 深链/设备/会话/统计/日志）+ 菜单栏下拉。克制原生风 |
| `design/swiftui/DSHRemote/` | **iOS SwiftUI 代码骨架**（8 文件）：DSTheme.swift（token 与规范 §4 同名，含双模式动态色）/ Models.swift（stub 数据）/ Components.swift（§5 全部组件）/ SessionListView / SessionDetailView / SettingsView / Sheets（新建会话/创建目标/扫码）/ ContentView（Tab + 全局横幅）。可直接拖入 Xcode 工程 |
| `design/swiftui/DSHRemoteMac/` | **Mac 伴侣 SwiftUI 骨架**（6 文件，对齐 dsh-remote-mac.html）：MacTheme.swift（token 与 iOS 端同名，NSColor 版动态色）/ MacModels.swift（BridgeService + 设备/会话/日志 stub）/ PairingQRView.swift（装饰性假二维码 Canvas 实现，真实版换 CIQRCodeGenerator）/ OverviewView.swift（概览页全量）/ SectionViews.swift（会话/设备/日志/设置骨架）/ MenuBarView.swift + DSHRemoteMacApp.swift（WindowGroup 主窗口 + 配对窗口 + MenuBarExtra 菜单栏下拉） |

### 2.2 Logo
| 文件 | 内容 |
|---|---|
| `design/icon-set-v6/` | **Logo v6（当前有效，双端分版）**：破屏鲸「皇家蓝纯色」高端开发者工具风——纯白底 + 纯色 #2563EB（无渐变）。iOS 版=鲸鱼撞穿手机边框（11 张）；Mac 版=鲸鱼压出完整 MacBook 屏幕、前后遮挡边框无损（4 张）。鲸鱼形象与 v5 一致 |
| `design/clean_logo_v6.py` | v6 清洗脚本（近白底归一纯白） |
| `design/icon-set-v5/` | Logo v5（已废弃）：同构图但蓝青渐变被评"不高端" |
| `design/clean_logo_v5.py` / `patch_mac_bezel.py` | v5 清洗 + Mac 底框程序化补丁脚本（技巧仍可复用） |
| `design/icon-set-v4/` | Logo v4（已废弃）：蓝青渐变底 + 白色主体 |
| `design/clean_logo_v4.py` | v4 清洗脚本（方裁去水印法，双 master 分别切图） |
| `design/icon-set-v3/` | Logo v3（已废弃）：破屏鲸首版，深海军蓝渐变被评"土气" |
| `design/clean_logo_v3_d1.py` | v3 清洗脚本（内嵌竖版图标的跳变检测+渐变外推法，仍可复用） |
| `design/icon-set/` | Logo v2（已废弃）：蓝青渐变 + 白鲸喷水花 |
| `design/crop_icon.py` | v2 清洗脚本（alpha 反演法，见 §4） |
| `generated-images/` | 原始生成稿（v1~v6 各方向，带水印勿直接用） |

### 2.3 官网（掌中鲸品牌站，自包含静态页）
| 文件 | 内容 |
|---|---|
| `site/index.html` | 品牌落地页：Hero（破屏鲸图标+浮动气泡）/ 功能 4 条 / 三步上手 / 双端下载（iOS 引导 App Store 占位、Mac 站内 dmg 下载占位 `releases/PocketWhale-macOS.dmg`）。皇家蓝 #2563EB + 白底，对齐 v6 Logo 语言 |
| `site/privacy.html` | App Store 隐私声明页（v1.0，2026-08-14）：无账号/无埋点/局域网直连/权限逐项说明（本地网络/相机/通知），数据收集表可直接对应 App Store 隐私标签 |
| `site/assets/` | v6 图标拷贝（icon-ios / icon-mac / logo-mark） |
| 待替换 | App Store 真实链接、dmg 真实文件、support@aicetus.cn 邮箱 |

### 2.4 早期概念稿（掌中鲸探索，仅供参考，不要当规范用）
| 文件 | 内容 |
|---|---|
| `design/ios-app.html` | 掌中鲸 iOS 4 屏（明亮渐变风） |
| `design/mac-server.html` | 掌中鲸 Mac 服务端（同上风格） |

### 2.5 记忆文件
- `.workbuddy/memory/MEMORY.md` — 项目长期备忘（两个项目的关系、约束）
- `.workbuddy/memory/2026-08-14.md` — 当日工作日志

---

## 3. 本次会话操作记录（按时间线）

1. **命名探索**：产出 6 个候选名（Rein/缰、PocketHarness、DeepTether、驭、WhaleLink、DeepDeck）+ 3 个 SVG 图标概念；用户选定「掌中鲸」方向
2. **Logo v1**（已废弃）：ImageGen 扁平极简风，深蓝 #185FA5 + 手机轮廓 + 鲸鱼 → 用户反馈"死气沉沉"
3. **掌中鲸双端概念 UI**（已降级为参考）：ios-app.html + mac-server.html，自定义海洋色系（潮汐蓝 #0EA5E9 等）
4. **发现真实项目**：用户提供 `dp远程/docs/ui-design-spec.md`，确认正式产品为 DSH Remote
5. **Logo v2**（当前有效）：蓝青渐变 + 白鲸；经 crop_icon.py 清洗后导出 14 种尺寸
6. **正式双端 UI**（当前有效）：dsh-remote-ios.html + dsh-remote-mac.html，严格对齐规范 v0.3

**用户最新指令**：Logo 先搁置；双端 UI 以规范版为准。

---

## 4. 技术要点与复用方法

### 4.1 图标清洗脚本（design/crop_icon.py）
- **环境**：托管 Python venv `/Users/lifengzhi/.workbuddy/binaries/python/envs/default/bin/python`（已装 pillow + numpy；不要用系统 pip）
- **算法**：行列投影（阈值 100）定位图标主体避开"AI生成"水印 → 饱和像素（max-min>30）最小二乘拟合平面渐变 → alpha 反演 `(obs-grad)/(255-grad)` 取三通道中位数 → 对比拉伸 `clip((a-0.35)/0.55)` + smoothstep → 干净渐变 + 纯白主体重新合成
- **用法**：改 `SRC` / `OUT` 路径即可复用；尺寸表在脚本尾部 `sizes` 字典
- 同样流程已沉淀为用户级技能：`~/.workbuddy/skills/app-icon-pipeline/SKILL.md`

### 4.2 设计稿技术说明
- 两个正式稿均为**自包含 HTML**（无外部依赖，系统字体栈），直接浏览器打开即可
- iOS 稿用 CSS 变量实现浅/深双模式（`.phone.dk` 切换），token 命名与规范 §4.1 对齐，可对照翻译成 SwiftUI `Color` 资产
- 二维码为 JS 生成的装饰性假码（固定种子伪随机 + 三个定位角），非真实可扫

---

## 5. 待确认问题（需要用户拍板）

1. **品牌关系**：掌中鲸是 DSH Remote 的新品牌名，还是另一个独立产品？（影响 App Store 命名与 Logo 归属）
2. **深色版会话列表**：正式稿只做了列表浅色 + 详情深色，列表深色版未补
3. **Logo v2 是否采用**：用户说"先放一边"，未最终确认

## 6. 建议下一步（按优先级）

- **P0**：SwiftUI 骨架（`design/swiftui/DSHRemote/`）迁入真实工程，接入桥接服务 WebSocket 数据层替换 stub
- **P1**：扫码配对页接 VisionKit DataScanner / AVFoundation 真实取景；回答提问 sheet 独立弹层版（目前仅有会话内嵌提问卡）
- **P2**：队列卡片编辑弹窗（alert 多行输入）、空态/错误态细节、动效微调（流式呼吸、圆环过渡已在骨架中标注）
- **P2**：Mac 伴侣 App 的 SwiftUI 骨架已完成（`design/swiftui/DSHRemoteMac/`）；待办：迁入真实工程、二维码换 CIQRCodeGenerator 真码、接入桥接进程数据源
