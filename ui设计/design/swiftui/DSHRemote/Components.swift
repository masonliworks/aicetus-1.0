//
//  Components.swift
//  DSH Remote — 组件库（规范 §5，symbol 化单元）
//

import SwiftUI

// MARK: - §5.1 状态指示 StateIndicator

struct StateIndicator: View {
    var color: Color
    var text: String
    var pulsing: Bool = false

    @State private var breath = false

    var body: some View {
        HStack(spacing: DSSpace.s1) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(pulsing ? (breath ? 1 : 0.4) : 1)
                .animation(pulsing ? .easeInOut(duration: 0.9).repeatForever() : .default,
                           value: breath)
                .onAppear { breath = true }
            Text(text).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
        }
    }
}

// MARK: - §6.1 全局连接横幅（32pt .bar）

struct ConnectionBanner: View {
    var connected: Bool
    var runningCount: Int
    var modelName: String
    var dshReachable: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connected ? DSColor.statusRunning : DSColor.statusDanger)
                .frame(width: 8, height: 8)
            if dshReachable {
                Text("已连接 · \(runningCount) 个会话运行中 · \(modelName)")
            } else {
                Text("已连接 · DSH 无法访问").foregroundStyle(DSColor.statusDanger)
            }
        }
        .font(DSFont.caption)
        .foregroundStyle(DSColor.textSecondary)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .barMaterial()
    }
}

// MARK: - §5.3 会话行 SessionRow

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(alignment: .top, spacing: DSSpace.s3) {
            VStack(alignment: .leading, spacing: DSSpace.s1) {
                Text(session.title).font(DSFont.headline).lineLimit(1)
                HStack(spacing: DSSpace.s1) {
                    StateIndicator(color: session.status.color,
                                   text: session.status.label,
                                   pulsing: session.status == .running || session.status == .waitingApproval)
                    Text(session.preset)
                        .font(DSFont.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .overlay(Capsule().stroke(DSColor.divider))
                }
                if let goal = session.goalSummary {
                    Text("🎯 \(goal)").font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing) {
                if session.pendingApprovals > 0 {
                    Label("\(session.pendingApprovals)", systemImage: "exclamationmark.shield.fill")
                        .font(DSFont.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(DSColor.statusDanger, in: Capsule())
                }
                Spacer(minLength: 0)
                Text(session.lastActiveText)
                    .font(DSFont.caption2).foregroundStyle(DSColor.textTertiary)
            }
        }
        .padding(DSSpace.s3)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md))
        // 左滑手势：归档(红) / 分叉(蓝) / 重命名(橙) —— 在 List 中以 swipeActions 挂载
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

// MARK: - §5.6 工具调用抽屉 ToolCallDrawer

struct ToolCallDrawer: View {
    let call: ToolCall
    @State private var expanded = false

    private var stateIcon: some View {
        Group {
            switch call.state {
            case .done:    Image(systemName: "checkmark").foregroundStyle(DSColor.statusRunning)
            case .failed:  Image(systemName: "xmark").foregroundStyle(DSColor.statusDanger)
            case .running: ProgressView().controlSize(.mini).tint(DSColor.statusWaiting)
            }
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: DSSpace.s2) {
                Text(call.paramsJSON)
                    .font(DSFont.mono(12))
                    .padding(DSSpace.s2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DSColor.textTertiary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: DSRadius.sm))
                Text(call.result)
                    .font(DSFont.mono(12))
                    .padding(DSSpace.s2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(call.state == .failed
                                ? DSColor.statusDanger.opacity(0.08)
                                : DSColor.textTertiary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: DSRadius.sm))
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

// MARK: - §5.4 消息气泡 MessageBubble

struct MessageBubble: View {
    let message: Message

    var body: some View {
        Group {
            if message.role == .user {
                Text(message.text)
                    .font(DSFont.body)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(DSColor.accent.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: DSRadius.lg))
                    .frame(maxWidth: 290, alignment: .trailing)   // ≈78% of 375
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: DSSpace.s1) {
                    if let reasoning = message.reasoning {
                        ReasoningDrawer(text: reasoning)
                    }
                    ForEach(message.toolCalls) { ToolCallDrawer(call: $0) }
                    Text(message.text).font(DSFont.body)
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.lg))
                .frame(maxWidth: 320, alignment: .leading)          // ≈88%
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
        }
    }
}

// MARK: - §5.7 流式气泡 StreamingBubble

struct StreamingBubble: View {
    var thinkingExcerpt: String
    var partialText: String

    @State private var breath = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpace.s1) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                if partialText.isEmpty {
                    ProgressView().controlSize(.small)
                    Text("生成中…")
                } else {
                    Text("思考中…")
                    Text(thinkingExcerpt).lineLimit(2).foregroundStyle(DSColor.textTertiary)
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)

            if !partialText.isEmpty {
                Text(partialText).font(DSFont.body)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.lg))
        .frame(maxWidth: 320, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(breath ? 1 : 0.55)                                 // §5.7 呼吸动效
        .animation(.easeInOut(duration: 0.9).repeatForever(), value: breath)
        .onAppear { breath = true }
    }
}

// MARK: - §5.8 队列卡片 QueueCard

struct QueueCard: View {
    let item: QueueItem
    var onEdit: () -> Void = {}
    var onSteer: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: DSSpace.s2) {
            Text(item.state == .queued ? "⏱ 排队中" : "↗ 引导发送中")
                .font(DSFont.caption2.weight(.semibold))
                .foregroundStyle(item.state == .queued ? DSColor.statusWaiting : DSColor.accent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background((item.state == .queued ? DSColor.statusWaiting : DSColor.accent).opacity(0.15),
                            in: Capsule())
            Text(item.text)
                .font(DSFont.subheadline)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: DSSpace.s3) {
                Button(action: onEdit) { Image(systemName: "pencil") }
                    .foregroundStyle(DSColor.textSecondary)
                Button(action: onSteer) { Image(systemName: "arrow.up.right.circle") }
                    .foregroundStyle(item.state == .queued ? DSColor.accent : DSColor.textTertiary)
                    .disabled(item.state != .queued)                // 引导中置灰
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .foregroundStyle(DSColor.statusDanger)
            }
            .font(DSFont.body)
        }
        .padding(DSSpace.s3)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - §5.9 审批卡 ApprovalCard

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

            Text(request.reason)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .lineLimit(3)

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

// MARK: - §5.10 目标条 GoalStrip / 任务条 JobStrip

struct GoalStrip: View {
    var summary: String?
    var onPause: () -> Void = {}
    var onResume: () -> Void = {}
    var onComplete: () -> Void = {}
    var onCreate: () -> Void = {}

    var body: some View {
        HStack(spacing: DSSpace.s2) {
            if let summary {
                Text("🎯")
                Text(summary).font(DSFont.caption).lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onPause) { Image(systemName: "pause") }
                Button(action: onComplete) { Image(systemName: "checkmark") }
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
    let jobs: [Job]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpace.s1) {
            ForEach(jobs.prefix(3)) { job in
                HStack(spacing: DSSpace.s2) {
                    Image(systemName: icon(for: job.state))
                        .foregroundStyle(color(for: job.state))
                    Text(job.name).font(DSFont.caption)
                    Spacer(minLength: 0)
                    Text(label(for: job.state)).font(DSFont.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .padding(.horizontal, DSSpace.s3).padding(.vertical, DSSpace.s2)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md))
    }

    private func icon(for s: Job.State) -> String {
        switch s { case .todo: "circle"; case .doing: "hammer"; case .done: "checkmark" }
    }
    private func color(for s: Job.State) -> Color {
        switch s { case .todo: return DSColor.statusIdle; case .doing: return DSColor.statusComplete; case .done: return DSColor.statusRunning }
    }
    private func label(for s: Job.State) -> String {
        switch s { case .todo: "待开始"; case .doing: "进行中"; case .done: "完成" }
    }
}

// MARK: - §5.11 底部信息栏 SessionStatusBar（含上下文圆环）

struct SessionStatusBar: View {
    var modelName: String
    var effort: String
    var contextUsed: Double          // 0...1
    var onPickModel: () -> Void = {}
    var onCommand: () -> Void = {}

    var body: some View {
        HStack(spacing: DSSpace.s3) {
            Button(action: onPickModel) {
                HStack(spacing: 5) {
                    Image(systemName: "desktopcomputer")
                    Text("\(modelName) · \(effort)")
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .font(DSFont.caption)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(DSColor.surfaceRaised, in: Capsule())
                .overlay(Capsule().stroke(DSColor.divider))
            }
            .foregroundStyle(DSColor.textPrimary)

            HStack(spacing: 5) {
                ContextRing(progress: contextUsed)
                    .frame(width: 16, height: 16)
                Text("上下文 \(Int(contextUsed * 100))%")
                    .font(DSFont.caption)
                    .foregroundStyle(contextUsed > 0.85 ? DSColor.statusDanger : DSColor.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onCommand) {
                Label("命令", systemImage: "plus").font(DSFont.caption.weight(.semibold))
            }
            .tint(DSColor.accent)
        }
        .padding(.horizontal, DSSpace.page).padding(.vertical, DSSpace.s2)
        .barMaterial()
    }
}

/// 上下文圆环（>85% 红色，用量变化平滑动画，§5.11）
struct ContextRing: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(DSColor.divider, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress > 0.85 ? DSColor.statusDanger : DSColor.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)
        }
    }
}

// MARK: - §5.13 输入栏 Composer

struct Composer: View {
    enum Mode { case queue, steer }
    @State var mode: Mode = .queue
    @Binding var text: String
    var running: Bool
    var onSend: () -> Void = {}
    var onStop: () -> Void = {}

    var body: some View {
        HStack(alignment: .bottom, spacing: DSSpace.s2) {
            // 模式胶囊（40pt 宽，图标+文字竖排）
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
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(DSColor.divider))

            Button(action: running ? onStop : onSend) {
                Image(systemName: running ? "stop.fill" : "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(running ? DSColor.statusDanger : DSColor.accent, in: Circle())
            }
            .disabled(!running && text.isEmpty)
        }
        .padding(.horizontal, DSSpace.s3)
        .padding(.top, DSSpace.s2).padding(.bottom, DSSpace.s4)
        .barMaterial()
    }
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
        .frame(maxWidth: 340)        // §5.12 max-width 340 / max-height 420
        .background(DSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.lg))
    }

    private var groupedProviders: [String] {
        var seen: [String] = []
        for o in options where !seen.contains(o.provider) { seen.append(o.provider) }
        return seen
    }
}
