//
//  UIComponents.swift
//  DSH Remote — 组件库（UI agent 设计，规范 §5；数据模型已适配 WireModels）
//

import SwiftUI

// MARK: - §5.1 状态指示 StateIndicator

struct StateIndicator: View {
    var color: Color
    var text: String
    var pulsing: Bool = false

    var body: some View {
        HStack(spacing: DSSpace.s1) {
            TimelineView(.animation(minimumInterval: 0.05)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = t.truncatingRemainder(dividingBy: 1.8) / 1.8
                let opacity = pulsing ? 0.4 + 0.6 * (0.5 - 0.5 * cos(phase * 2 * .pi)) : 1.0
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .opacity(opacity)
            }
            .fixedSize()
            Text(text).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
        }
    }
}

// MARK: - §5.3 会话行 SessionRow（数据：SessionInfo + 待办数）

struct SessionRow: View {
    let session: SessionInfo
    var pendingCount: Int = 0

    private var statusColor: Color {
        if pendingCount > 0 { return DSColor.statusWaiting }
        return session.running ? DSColor.statusRunning : DSColor.statusIdle
    }
    private var statusLabel: String {
        if pendingCount > 0 { return "待审批" }
        return session.running ? "运行中" : "空闲"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSSpace.s3) {
            VStack(alignment: .leading, spacing: DSSpace.s1) {
                Text(session.displayTitle).font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: DSSpace.s1) {
                    StateIndicator(color: statusColor, text: statusLabel,
                                   pulsing: session.running || pendingCount > 0)
                    if let preset = session.agentPreset, !preset.isEmpty {
                        Text(preset)
                            .font(DSFont.caption2)
                            .foregroundStyle(DSColor.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .overlay(Capsule().stroke(DSColor.divider))
                    }
                }
                if let goal = session.activeGoal {
                    Text("🎯 \(goal.objective)").font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing) {
                if pendingCount > 0 {
                    Label("\(pendingCount)", systemImage: "exclamationmark.shield.fill")
                        .font(DSFont.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(DSColor.statusDanger, in: Capsule())
                }
                Spacer(minLength: 0)
                Text(UIStaticTime.relativeText(session.updatedAt))
                    .font(DSFont.caption2).foregroundStyle(DSColor.textTertiary)
            }
        }
        .padding(DSSpace.s3)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

/// 静态相对时间（"5 分钟前"，一次性计算，不实时跳动）。
enum UIStaticTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .full
        return f
    }()

    static func relativeText(_ date: Date?) -> String {
        guard let date else { return "" }
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - §5.5 思考过程抽屉 ReasoningDrawer

struct ReasoningDrawer: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(text)
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .padding(DSSpace.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DSColor.textTertiary.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: DSRadius.sm))
                .textSelection(.enabled)
        } label: {
            Label("思考过程", systemImage: "brain.head.profile")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .tint(DSColor.textSecondary)
    }
}

// MARK: - §5.6 工具调用抽屉 ToolCallDrawer（数据：ToolCallBlock）

struct ToolCallDrawer: View {
    let call: ToolCallBlock
    @State private var expanded = false

    private var stateIcon: some View {
        Group {
            if call.isFinished {
                if call.isError {
                    Image(systemName: "xmark").foregroundStyle(DSColor.statusDanger)
                } else {
                    Image(systemName: "checkmark").foregroundStyle(DSColor.statusRunning)
                }
            } else {
                ProgressView().controlSize(.mini).tint(DSColor.statusWaiting)
            }
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: DSSpace.s2) {
                if !call.arguments.isEmpty, call.arguments != "{}" {
                    Text(call.arguments)
                        .font(DSFont.mono(12))
                        .padding(DSSpace.s2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DSColor.textTertiary.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: DSRadius.sm))
                }
                if let result = call.resultText, !result.isEmpty {
                    Text(result)
                        .font(DSFont.mono(12))
                        .padding(DSSpace.s2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(call.isError
                                    ? DSColor.statusDanger.opacity(0.08)
                                    : DSColor.textTertiary.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: DSRadius.sm))
                }
            }
            .textSelection(.enabled)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "wrench.and.screwdriver")
                Text(call.name).font(DSFont.caption.weight(.medium))
                Text(call.summary).font(DSFont.caption2)
                    .foregroundStyle(DSColor.textSecondary).lineLimit(1)
                Spacer(minLength: 4)
                stateIcon
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textPrimary)
        }
        .tint(DSColor.textSecondary)
    }
}

// MARK: - §5.4 消息气泡 MessageBubble（数据：ChatMessage）

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        Group {
            if message.role == "user" {
                // 我的消息：气泡右对齐，复制按钮在气泡左侧底部（固定槽位，间距恒定）
                HStack(alignment: .bottom, spacing: 6) {
                    copyButton.frame(width: 22, alignment: .bottom)
                    Text(message.text)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(DSColor.accent.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: DSRadius.lg))
                        .frame(maxWidth: 290, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // 你的消息：气泡左对齐，复制按钮在气泡右侧底部（固定槽位，间距恒定）
                HStack(alignment: .bottom, spacing: 6) {
                    VStack(alignment: .leading, spacing: DSSpace.s1) {
                        if !message.reasoning.isEmpty {
                            ReasoningDrawer(text: message.reasoning)
                        }
                        ForEach(message.toolCalls) { ToolCallDrawer(call: $0) }
                        if !message.text.isEmpty {
                            Text(message.text).font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                        }
                    }
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.lg))
                    .frame(maxWidth: 320, alignment: .leading)
                    .textSelection(.enabled)
                    copyButton.frame(width: 22, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = message.text
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 13))
                .foregroundStyle(DSColor.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(message.text.isEmpty)
        .opacity(message.text.isEmpty ? 0.3 : 1)
    }
}

// MARK: - §5.7 流式气泡 StreamingBubble

struct StreamingBubble: View {
    var thinkingExcerpt: String
    var partialText: String
    var phase: String = ""   // ""=等待 | "reasoning"=思考中 | "text"=生成中
    var startTime: Date?

    @State private var breath = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpace.s1) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                ProgressView().controlSize(.small)
                Text(statusText)
                if let startTime {
                    // Deep diving 计时：≥15 秒后显示（与 web 端一致）
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = max(0, context.date.timeIntervalSince(startTime))
                        if elapsed >= 15 {
                            Text(SessionStatsBar.formatDuration(elapsed * 1000))
                                .font(DSMacFontLike.mono())
                                .foregroundStyle(DSColor.textTertiary)
                        }
                    }
                }
                if !thinkingExcerpt.isEmpty {
                    Text(thinkingExcerpt).lineLimit(2).foregroundStyle(DSColor.textTertiary)
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)

            if !partialText.isEmpty {
                Text(partialText).font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.lg))
        .frame(maxWidth: 320, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(breath ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.9).repeatForever(), value: breath)
        .onAppear { breath = true }
    }

    private var statusText: String {
        if !partialText.isEmpty { return "Deep diving..." }
        switch phase {
        case "reasoning": return "Deep diving..."
        case "text": return "Deep diving..."
        default: return "Deep diving..."
        }
    }
}

// MARK: - §5.8 队列卡片 QueueCard（数据：WireModels.QueueItem）

struct QueueCard: View {
    let item: QueueItem
    var onEdit: () -> Void = {}
    var onSteer: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: DSSpace.s2) {
            Text(item.isQueued ? "⏱ 排队中" : "↗ 引导发送中")
                .font(DSFont.caption2.weight(.semibold))
                .foregroundStyle(item.isQueued ? DSColor.statusWaiting : DSColor.accent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background((item.isQueued ? DSColor.statusWaiting : DSColor.accent).opacity(0.15),
                            in: Capsule())
            Text(item.message.text)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: DSSpace.s3) {
                Button(action: onEdit) { Image(systemName: "pencil") }
                    .foregroundStyle(DSColor.textSecondary)
                Button(action: onSteer) { Image(systemName: "arrow.up.right.circle") }
                    .foregroundStyle(item.isQueued ? DSColor.accent : DSColor.textTertiary)
                    .disabled(!item.isQueued)
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .foregroundStyle(DSColor.statusDanger)
            }
            .font(DSFont.body)
        }
        .padding(DSSpace.s3)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - §5.9 审批卡 ApprovalCard（数据：WireModels.ApprovalRequest）

struct ApprovalCard: View {
    let request: ApprovalRequest
    var onDeny: () -> Void = {}
    var onAllowOnce: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpace.s2) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill")
                Text("工具调用待审批")
                Text(request.toolName)
                    .font(DSFont.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(Capsule().stroke(DSColor.divider))
            }
            .font(DSFont.footnote.weight(.semibold))
            .foregroundStyle(DSColor.statusWaiting)

            if let reason = request.reason, !reason.isEmpty {
                Text(reason)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: DSSpace.s3) {
                Button("拒绝", action: onDeny)
                    .buttonStyle(.bordered)
                    .tint(DSColor.statusDanger)
                Button("允许一次", action: onAllowOnce)
                    .buttonStyle(.borderedProminent)
                    .tint(DSColor.accent)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DSSpace.s3)
        .background(DSColor.waitingSurface, in: RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - §5.10 目标条 GoalStrip / 任务条 JobStrip（数据：GoalView / JobView）

struct GoalStrip: View {
    var summary: String?
    var paused: Bool = false
    var onPause: () -> Void = {}
    var onResume: () -> Void = {}
    var onComplete: () -> Void = {}
    var onCreate: () -> Void = {}

    var body: some View {
        HStack(spacing: DSSpace.s2) {
            if let summary {
                Text("🎯")
                Text(summary).font(DSFont.caption).lineLimit(1)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer(minLength: 0)
                Button(action: paused ? onResume : onPause) {
                    Image(systemName: paused ? "play" : "pause")
                }
                .foregroundStyle(DSColor.textSecondary)
                Button(action: onComplete) { Image(systemName: "checkmark") }
                    .foregroundStyle(DSColor.statusRunning)
            } else {
                Button(action: onCreate) {
                    Label("创建目标", systemImage: "plus")
                        .font(DSFont.caption)
                }
                .tint(DSColor.accent)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(DSColor.textPrimary)
        .padding(.horizontal, DSSpace.s3).padding(.vertical, DSSpace.s2)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

struct JobStrip: View {
    let jobs: [JobView]

    /// 只显示进行中/失败的作业——已完成、已终止的作业不再突然出现
    private var visibleJobs: [JobView] {
        jobs.filter { $0.status == "running" || $0.status == "stopping" || $0.status == "failed" }
    }

    var body: some View {
        Group {
            if !visibleJobs.isEmpty {
                VStack(alignment: .leading, spacing: DSSpace.s1) {
                    ForEach(visibleJobs.prefix(3)) { job in
                        HStack(spacing: DSSpace.s2) {
                            Image(systemName: icon(for: job.status))
                                .foregroundStyle(color(for: job.status))
                            Text(job.label).font(DSFont.caption)
                                .foregroundStyle(DSColor.textPrimary)
                            Spacer(minLength: 0)
                            Text(label(for: job.status)).font(DSFont.caption2)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, DSSpace.s3).padding(.vertical, DSSpace.s2)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md))
            }
        }
    }

    private func icon(for s: String) -> String {
        switch s {
        case "running": "arrow.triangle.2.circlepath"
        case "completed": "checkmark"
        case "failed": "xmark"
        case "stopping": "pause.circle"
        default: "circle"
        }
    }
    private func color(for s: String) -> Color {
        switch s {
        case "running": return DSColor.statusComplete
        case "completed": return DSColor.statusRunning
        case "failed": return DSColor.statusDanger
        case "stopping": return DSColor.statusWaiting
        default: return DSColor.statusIdle
        }
    }
    private func label(for s: String) -> String {
        switch s {
        case "running": "进行中"
        case "completed": "完成"
        case "failed": "失败"
        case "stopping": "停止中"
        default: "待开始"
        }
    }
}

// MARK: - §5.11 底部信息栏 SessionStatusBar（含上下文圆环）

struct SessionStatusBar: View {
    var modelName: String
    var effort: String
    var contextUsed: Double          // 0...1
    var statsLines: [String] = []    // 第二/三排：步数/LLM/首token + tok/s/缓存/输入输出
    var modelOptions: [ModelPicker.ModelOption] = []
    var onPickModel: (ModelPicker.ModelOption) -> Void = { _ in }
    var commands: [(label: String, value: String)] = []
    var onCommand: (String) -> Void = { _ in }
    var subagents: [SubagentInfo] = []
    var onInterruptSubagent: (String) -> Void = { _ in }
    /// 上下文详情（点击圆环弹出）："96.5K / 1M"
    var contextDetail: String = ""

    @State private var showModelPopover = false
    @State private var showCommandPopover = false
    @State private var showSubagentPopover = false
    @State private var showContextPopover = false

    var body: some View {
        VStack(spacing: 4) {
            firstRow
            ForEach(statsLines, id: \.self) { line in
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(line)
                        .font(DSFont.caption2)
                        .foregroundStyle(DSColor.textTertiary)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, DSSpace.page)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .barMaterial()
    }

    /// 极简平面机器人图标；有运行中子代理时蓝色呼吸（TimelineView 驱动，不参与布局动画）
struct RobotIcon: View {
    var running: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 1.8) / 1.8
            let opacity = running ? 0.4 + 0.6 * (0.5 - 0.5 * cos(phase * 2 * .pi)) : 1.0
            Image(systemName: "person.2.fill")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(running ? DSColor.accent : DSColor.textPrimary)
                .opacity(opacity)
        }
        .fixedSize()
    }
}

/// 模型显示名：去掉 "DeepSeek-" 等 provider 前缀
    private var displayModelName: String {
        var name = modelName
        let prefixes = ["deepseek-", "DeepSeek-"]
        for p in prefixes where name.hasPrefix(p) {
            name = String(name.dropFirst(p.count))
            break
        }
        return name
    }

    private var firstRow: some View {
        HStack(spacing: DSSpace.s3) {
            Button {
                showModelPopover = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "brain.filled.head.profile")
                    Text(effort.isEmpty ? displayModelName : "\(displayModelName) · \(effort)")
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .font(DSFont.caption)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(DSColor.surfaceRaised, in: Capsule())
                .overlay(Capsule().stroke(DSColor.divider))
            }
            .foregroundStyle(DSColor.textPrimary)
            .popover(isPresented: $showModelPopover, arrowEdge: .bottom) {
                ModelPicker(
                    options: modelOptions,
                    onPick: { opt in
                        onPickModel(opt)
                    },
                    onClose: { showModelPopover = false }
                )
                .presentationCompactAdaptation(.popover)
            }

            // 子代理入口：模型选择右边
            Button {
                showSubagentPopover = true
            } label: {
                RobotIcon(running: subagents.contains(where: { $0.running }))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(DSColor.surfaceRaised, in: Capsule())
                    .overlay(Capsule().stroke(DSColor.divider))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSubagentPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("子代理").font(DSFont.footnote.weight(.semibold))
                            .foregroundStyle(DSColor.textPrimary)
                        Spacer()
                        Button {
                            showSubagentPopover = false
                        } label: {
                            Image(systemName: "xmark").foregroundStyle(DSColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DSSpace.s3)
                    if subagents.isEmpty {
                        Text("当前没有运行中的子代理")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textTertiary)
                            .padding(.horizontal, DSSpace.s3)
                            .padding(.bottom, DSSpace.s3)
                    } else {
                        ForEach(subagents) { sub in
                            HStack(spacing: DSSpace.s2) {
                                Circle()
                                    .fill(sub.running ? DSColor.statusRunning : DSColor.statusIdle)
                                    .frame(width: 7, height: 7)
                                Text(sub.title)
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if sub.running {
                                    Button {
                                        onInterruptSubagent(sub.id)
                                    } label: {
                                        Image(systemName: "stop.circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(DSColor.statusDanger)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, DSSpace.s3).padding(.vertical, DSSpace.s2)
                        }
                    }
                }
                .padding(.bottom, DSSpace.s2)
                .frame(maxWidth: 260)
                .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.lg))
                .presentationCompactAdaptation(.popover)
            }

            Button {
                if !contextDetail.isEmpty {
                    showContextPopover = true
                }
            } label: {
                HStack(spacing: 4) {
                    ContextRing(progress: contextUsed, centerText: "\(Int(contextUsed * 100))")
                        .frame(width: 22, height: 22)
                    Text("上下文")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showContextPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("上下文长度").font(DSFont.footnote.weight(.semibold))
                        .foregroundStyle(DSColor.textPrimary)
                    Text(contextDetail)
                        .font(DSFont.mono())
                        .foregroundStyle(DSColor.textSecondary)
                }
                .padding(DSSpace.s3)
                .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.md))
                .presentationCompactAdaptation(.popover)
            }

            Spacer(minLength: 0)

            Button {
                showCommandPopover = true
            } label: {
                Label("命令", systemImage: "plus").font(DSFont.caption.weight(.semibold))
            }
            .tint(DSColor.accent)
            .popover(isPresented: $showCommandPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("原版命令").font(DSFont.footnote.weight(.semibold))
                            .foregroundStyle(DSColor.textPrimary)
                        Spacer()
                        Button {
                            showCommandPopover = false
                        } label: {
                            Image(systemName: "xmark").foregroundStyle(DSColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DSSpace.s3)
                    ForEach(commands, id: \.label) { cmd in
                        Button {
                            showCommandPopover = false
                            onCommand(cmd.value)
                        } label: {
                            HStack(spacing: DSSpace.s2) {
                                Image(systemName: "command")
                                    .foregroundStyle(DSColor.accent)
                                Text(cmd.label).font(DSFont.body)
                                    .foregroundStyle(DSColor.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, DSSpace.s3).padding(.vertical, DSSpace.s2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, DSSpace.s2)
                .frame(maxWidth: 260)
                .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.lg))
                .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.horizontal, DSSpace.page)
    }
}

/// 上下文圆环（>85% 红色，用量变化平滑动画；中心可显示百分比数字）
struct ContextRing: View {
    var progress: Double
    var centerText: String = ""

    var body: some View {
        ZStack {
            Circle().stroke(DSColor.divider, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress > 0.85 ? DSColor.statusDanger : DSColor.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)
            if !centerText.isEmpty {
                Text(centerText)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - §5.13 输入栏 Composer（排队/插话模式胶囊）

struct Composer: View {
    enum Mode { case queue, steer }
    @State var mode: Mode = .queue
    @Binding var text: String
    var running: Bool
    var focused: FocusState<Bool>.Binding
    var onSend: (Mode) -> Void = { _ in }
    var onStop: () -> Void = {}

    var body: some View {
        HStack(alignment: .bottom, spacing: DSSpace.s2) {
            Button {
                mode = mode == .queue ? .steer : .queue
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: mode == .queue
                          ? "text.line.last.and.arrowtriangle.forward"
                          : "arrow.up.right.circle")
                        .font(.system(size: 14))
                    Text(mode == .queue ? "排队" : "插话").font(.system(size: 10))
                }
                .frame(width: 40, height: 36)
                .background(mode == .steer ? DSColor.accent : DSColor.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: DSRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.sm).stroke(DSColor.divider))
                .foregroundStyle(mode == .steer ? .white : DSColor.textSecondary)
            }

            TextField("发消息…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .font(DSFont.body)
                .focused(focused)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(DSColor.divider))
                .onChange(of: text) { _, newValue in
                    // 键盘回车 = 发送
                    if newValue.contains("\n") {
                        text = newValue.replacingOccurrences(of: "\n", with: "")
                        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                            onSend(mode)
                        }
                    }
                }

            // 有输入 → 发送（accent）；空输入且运行中 → 停止（红）；空输入且空闲 → 发送置灰
            Button(action: {
                if hasText {
                    onSend(mode)
                } else if running {
                    onStop()
                }
            }) {
                Image(systemName: hasText ? "arrow.up" : (running ? "stop.fill" : "arrow.up"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(hasText ? DSColor.accent : (running ? DSColor.statusDanger : DSColor.accent), in: Circle())
            }
            .disabled(!running && !hasText)
        }
        .padding(.horizontal, DSSpace.s3)
        .padding(.top, DSSpace.s2).padding(.bottom, DSSpace.s4)
        .barMaterial()
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// iOS 端等宽字体工具（Deep diving 计时用）
enum DSMacFontLike {
    static func mono(_ size: CGFloat = 12) -> Font { .system(size: size, design: .monospaced) }
}

// MARK: - §5.12 模型选择 popover 内容 ModelPicker

struct ModelPicker: View {
    struct ModelOption: Identifiable, Hashable {
        let id = UUID()
        var provider: String
        var name: String
        var effort: String
        var current: Bool
    }

    let options: [ModelOption]
    var onPick: (ModelOption) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("模型与思考强度").font(DSFont.footnote.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(DSSpace.s3)

            ForEach(groupedProviders, id: \.self) { provider in
                Text(provider.uppercased())
                    .font(DSFont.caption2.weight(.semibold))
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.horizontal, DSSpace.s3).padding(.top, DSSpace.s1)
                ForEach(options.filter { $0.provider == provider }) { opt in
                    Button { onPick(opt); onClose() } label: {
                        HStack(spacing: DSSpace.s2) {
                            Image(systemName: opt.current ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(opt.current ? DSColor.accent : DSColor.textTertiary)
                            Text(opt.name).font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                            Spacer()
                            Text("思考强度 · \(opt.effort)").font(DSFont.caption2)
                                .foregroundStyle(DSColor.textTertiary)
                        }
                        .padding(.horizontal, DSSpace.s3).padding(.vertical, DSSpace.s2)
                    }
                    .foregroundStyle(DSColor.textPrimary)
                }
            }
        }
        .padding(.bottom, DSSpace.s2)
        .frame(maxWidth: 340)
        .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.lg))
    }

    private var groupedProviders: [String] {
        var seen: [String] = []
        for o in options where !seen.contains(o.provider) { seen.append(o.provider) }
        return seen
    }
}

// MARK: - 会话统计栏（web 页面底部 metrics，公式与 web 端一致）

struct SessionStatsBar: View {
    let stats: SessionStats
    let usage: TokenUsage

    var body: some View {
        Group {
            if !groups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(groups.joined(separator: " | "))
                        .font(DSFont.caption2)
                        .foregroundStyle(DSColor.textTertiary)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, DSSpace.page)
                }
                .frame(height: 28)
                .barMaterial()
            }
        }
    }

    /// 三排布局：
    ///   第一排 = 模型/上下文/命令（SessionStatusBar 自身）
    ///   第二排 = 步数 + LLM 时长
    ///   第三排 = 首 token 平均 + tok/s + 缓存命中 + 输入/输出
    static func lines(for stats: SessionStats, usage: TokenUsage) -> [String] {
        var line1: [String] = []
        if stats.turns > 0 || stats.steps > 0 {
            line1.append("\(stats.turns) 轮 · \(stats.steps) 步")
        }
        var durations: [String] = []
        if stats.llmMs > 0 { durations.append("LLM \(Self.formatDuration(stats.llmMs))") }
        if stats.toolMs > 0 { durations.append("工具调用 \(Self.formatDuration(stats.toolMs))") }
        if !durations.isEmpty { line1.append(durations.joined(separator: " · ")) }

        var line2: [String] = []
        if stats.ttftSteps > 0 {
            line2.append("首 token 平均 \(Self.formatDuration(stats.ttftMs / Double(stats.ttftSteps)))")
        }
        if stats.decodeMs > 0 {
            let tps = Double(stats.decodeTokens) / (stats.decodeMs / 1000)
            line2.append("\(Self.formatTokensPerSecond(tps)) tok/s")
        }
        if usage.billedInputTokens > 0 || usage.outputTokens > 0 {
            let cacheHit = usage.billedInputTokens > 0
                ? Int((Double(usage.cacheReadTokens) / Double(usage.billedInputTokens) * 100).rounded())
                : nil
            if let cacheHit {
                line2.append("缓存命中 \(cacheHit)%")
            }
            line2.append("输入 \(Self.formatTokens(Double(usage.billedInputTokens))) · 输出 \(Self.formatTokens(Double(usage.outputTokens)))")
        }

        var out: [String] = []
        if !line1.isEmpty { out.append(line1.joined(separator: " | ")) }
        if !line2.isEmpty { out.append(line2.joined(separator: " | ")) }
        return out
    }

    /// 单行文本（兼容旧调用）
    static func text(for stats: SessionStats, usage: TokenUsage) -> String {
        lines(for: stats, usage: usage).joined(separator: " | ")
    }

    private var groups: [String] {
        var g: [String] = []
        if stats.turns > 0 || stats.steps > 0 {
            g.append("\(stats.turns) 轮 · \(stats.steps) 步")
        }
        var durations: [String] = []
        if stats.llmMs > 0 { durations.append("LLM \(Self.formatDuration(stats.llmMs))") }
        if stats.toolMs > 0 { durations.append("工具调用 \(Self.formatDuration(stats.toolMs))") }
        if !durations.isEmpty { g.append(durations.joined(separator: " · ")) }
        var speeds: [String] = []
        if stats.ttftSteps > 0 {
            speeds.append("首 token 平均 \(Self.formatDuration(stats.ttftMs / Double(stats.ttftSteps)))")
        }
        if stats.decodeMs > 0 {
            let tps = Double(stats.decodeTokens) / (stats.decodeMs / 1000)
            speeds.append("\(Self.formatTokensPerSecond(tps)) tok/s")
        }
        if !speeds.isEmpty { g.append(speeds.joined(separator: " · ")) }
        if usage.billedInputTokens > 0 || usage.outputTokens > 0 {
            let cacheHit = usage.billedInputTokens > 0
                ? Int((Double(usage.cacheReadTokens) / Double(usage.billedInputTokens) * 100).rounded())
                : nil
            if let cacheHit {
                g.append("缓存命中 \(cacheHit)%")
            }
            g.append("输入 \(Self.formatTokens(Double(usage.billedInputTokens))) · 输出 \(Self.formatTokens(Double(usage.outputTokens)))")
        }
        return g
    }

    static func formatDuration(_ ms: Double) -> String {
        let s = ms / 1000
        if s < 60 { return String(format: "%.1fs", s) }
        let whole = Int(s.rounded())
        return "\(whole / 60)m\(whole % 60)s"
    }

    static func formatTokens(_ n: Double) -> String {
        func scaled(_ v: Double) -> String {
            v >= 100 ? String(Int(v.rounded())) : String((v * 10).rounded() / 10)
        }
        if n < 1e3 { return String(Int(n)) }
        if n < 1e6 { return "\(scaled(n / 1e3))K" }
        return "\(scaled(n / 1e6))M"
    }

    static func formatTokensPerSecond(_ tps: Double) -> String {
        let clamped = max(0, tps)
        return clamped >= 10 ? String(Int(clamped.rounded())) : String((clamped * 10).rounded() / 10)
    }
}
