# UI 设计交付规范（给 UI 设计师/Agent）

> 设计完成后，请把所有交付物放到 `design/` 目录，并严格遵循本文件的格式要求。
> **最重要的一点**：执行落地的主 Agent 不能查看图片，只能读取文本。
> 因此**所有视觉决策必须以文本形式完整表达**——图片只是辅助，不能承载唯一信息。

## 必须交付（缺一不可）

### 1. 设计标注文档（决定落地成败）
文件名：`design/spec-annotations.md`

按组件逐个标注，格式示例：

```markdown
### 会话行 SessionRow
- 背景：surface（浅 #FFFFFF / 深 #1C1C1E）
- 高度：自适应，上下 padding 12
- 布局：HStack，左列标题+状态行，右侧徽标/时间
- 标题：headline（17 semibold，text.primary），1 行截断
- 状态点：8pt 圆，运行中 #30D158，空闲 #8E8E93
- preset 胶囊：caption2，padding H6 V1，background quaternary
- 待审批徽标：红色盾牌 exclamationmark.shield.fill + 数字（caption2 bold #FF3B30）
- 相对时间：caption2 tertiary，静态文本"5 分钟前"
- 间距：标题与状态行间距 3，列间距 12
```

要求：
- 覆盖全部组件（对照 ui-design-spec.md 第 5 节 14 个组件 + 第 6 节页面）
- 每个视觉决策给出**具体数值**：字号/字重/颜色 hex（或语义 token 名）/间距 pt/圆角/图标名
- 颜色用语义 token 名（如 `status.waiting`）或明暗两套 hex
- 动效描述：时长/曲线/触发条件

### 2. 设计稿图片（参考用）
目录：`design/previews/`
- 命名：`<页面名>-<light|dark>.png`（如 `chat-light.png`）
- 用户会查看这些图，但落地以 spec-annotations.md 为准

### 3. 图标与切图（如有自定义）
目录：`design/assets/`
- 优先使用 SF Symbols（给出 symbol 名即可，无需切图）
- 自定义图标交付 SVG（主 Agent 可读源码）或 3x PNG

## 禁止事项

- ❌ 不要只在图片里标注尺寸/颜色（主 Agent 看不到）
- ❌ 不要引用"参考 Figma 链接"作为唯一信息源
- ❌ 不要设计 SwiftUI 无法还原的自定义控件（详见 ui-design-spec.md §9）
