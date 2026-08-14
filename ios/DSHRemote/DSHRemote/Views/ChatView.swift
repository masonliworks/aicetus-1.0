//
//  ChatView.swift
//  DSH Remote — 会话详情（UI agent 设计 §6.3，数据接 AppState）
//
//  自上而下：消息列表(含流式) → 队列卡片区 → 目标条 → 任务条 → 审批条
//           → 底部信息栏 → 输入栏
//

import SwiftUI

/// 内容底边在滚动坐标系中的 y 位置，用于判断"是否位于列表底部"。
private struct ContentBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ChatView: View {
    @Bindable var state: AppState
    let session: SessionInfo
    @State private var draft = ""
    @State private var sending = false
    @State private var errorMessage: String?
    @State private var showGoalCreate = false
    @State private var editingQueueItem: QueueItem?
    @State private var editText = ""
    @State private var lastKnownLastId: String?
    /// 用户是否位于列表底部（决定新消息/流式内容是否自动滚底）。
    /// 上翻阅读历史时为 false——新消息到达不再把视图拽回底部。
    @State private var nearBottom = true
    @FocusState private var composerFocused: Bool

    private var sessionMessages: [ChatMessage] {
        state.messages[session.sessionId] ?? []
    }

    /// 只显示最近 N 条（web 式"加载更早"分页）
    private var visibleMessages: [ChatMessage] {
        Array(sessionMessages.suffix(state.visibleCount(for: session.sessionId)))
    }

    private var sessionQueue: [QueueItem] {
        state.queueItems[session.sessionId] ?? []
    }

    private var pendingApprovals: [ApprovalRequest] {
        state.approvals.filter { $0.sessionId == session.sessionId }
    }

    private var pendingQuestions: [QuestionRequest] {
        state.questions.filter { $0.sessionId == session.sessionId }
    }

    /// The freshest session snapshot (auto-refresh updates state.sessions).
    private var liveSession: SessionInfo {
        state.sessions.first(where: { $0.sessionId == session.sessionId }) ?? session
    }

    private var catalog: ModelCatalog? {
        state.modelCatalogs[session.sessionId]
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            queueSection
            interactionSection
            Composer(
                text: $draft,
                running: liveSession.running,
                focused: $composerFocused,
                onSend: { mode in
                    send(mode: mode == .steer ? "steer" : "queue")
                },
                onStop: { cancel() }
            )
            .simultaneousGesture(DragGesture(minimumDistance: 20).onChanged { value in
                if value.translation.height > 30 {
                    composerFocused = false
                }
            })

            // 会话信息栏固定在屏幕最底部（输入框下方）
            SessionStatusBar(
                modelName: catalog?.currentModelName ?? "模型",
                effort: catalog?.currentEffort ?? "",
                contextUsed: liveSession.context?.usage ?? 0,
                statsLines: liveSession.stats.map { SessionStatsBar.lines(for: $0, usage: liveSession.usage ?? TokenUsage([:])) } ?? [],
                modelOptions: modelOptions,
                onPickModel: { opt in applyModel(opt) },
                commands: [
                    ("/compact — 压缩上下文", "/compact"),
                    ("/feedback — 反馈", "/feedback"),
                    ("/goal — 目标", "/goal"),
                ],
                onCommand: { cmd in sendCommand(cmd) },
                subagents: state.subagents[session.sessionId] ?? [],
                onInterruptSubagent: { subId in
                    Task {
                        try? await state.interruptSubagentOf(parentSessionId: session.sessionId, subagentId: subId)
                    }
                },
                contextDetail: liveSession.context.map {
                    "\(SessionStatsBar.formatTokens(Double($0.projectedTokens))) / \(SessionStatsBar.formatTokens(Double($0.contextWindow)))"
                } ?? ""
            )
        }
        .background(DSColor.backgroundBase)
        .navigationTitle(liveSession.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            // 新建的空白会话没有历史，跳过拉取直接显示空态
            if !session.blank {
                await state.loadHistory(sessionId: session.sessionId)
            } else {
                state.markHistoryLoaded(sessionId: session.sessionId)
            }
            await state.loadModels(sessionId: session.sessionId)
            await state.loadSubagents(sessionId: session.sessionId)
        }
        .sheet(isPresented: $showGoalCreate) {
            GoalCreateSheet(state: state, fixedSessionId: session.sessionId)
        }
        .alert("编辑消息", isPresented: Binding(
            get: { editingQueueItem != nil },
            set: { if !$0 { editingQueueItem = nil } }
        )) {
            TextField("消息内容", text: $editText, axis: .vertical)
                .lineLimit(2...6)
            Button("保存") {
                let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let item = editingQueueItem else { return }
                queueAction(item, .edit(trimmed))
            }
            Button("取消", role: .cancel) {}
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - queue card section

    private var queueSection: some View {
        Group {
            if !sessionQueue.isEmpty {
                VStack(spacing: DSSpace.s1) {
                    ForEach(sessionQueue) { item in
                        QueueCard(item: item,
                                  onEdit: { beginEdit(item) },
                                  onSteer: { queueAction(item, .steer) },
                                  onDelete: { queueAction(item, .remove) })
                    }
                }
                .padding(.horizontal, DSSpace.page)
                .padding(.vertical, DSSpace.s1)
                .barMaterial()
            }
        }
    }

    // MARK: - goal / job / approval section

    private var interactionSection: some View {
        VStack(spacing: DSSpace.s1) {
            if let goal = liveSession.activeGoal {
                GoalStrip(summary: goal.objective,
                          paused: goal.isPaused,
                          onPause: { goalAction("pause") },
                          onResume: { goalAction("resume") },
                          onComplete: { goalAction("complete") },
                          onCreate: { showGoalCreate = true })
            }
            JobStrip(jobs: liveSession.jobs)
            ForEach(pendingApprovals) { approval in
                ApprovalCard(request: approval,
                             onDeny: { respond(approval, "rejected") },
                             onAllowOnce: { respond(approval, "allowed-once") })
            }
            ForEach(pendingQuestions) { question in
                QuestionInlineCard(state: state, question: question)
            }
        }
        .padding(.horizontal, DSSpace.page)
        .padding(.vertical, DSSpace.s1)
    }

    // MARK: - message list (history + streaming)

    private var messageList: some View {
        Group {
            if sessionMessages.isEmpty {
                if let live = state.streaming[session.sessionId], live.active {
                    // 新会话第一次对话：没有历史，但流式输出必须可见
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: DSSpace.s2) {
                                StreamingBubble(
                                    thinkingExcerpt: String(live.reasoning.suffix(120)),
                                    partialText: live.text,
                                    phase: live.currentBlock,
                                    startTime: live.startedAt
                                )
                                .id("streaming")
                            }
                            .padding(.horizontal, DSSpace.page)
                            .padding(.top, DSSpace.s2)
                            .padding(.bottom, DSSpace.s2)
                        }
                        .defaultScrollAnchor(.bottom)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: state.streaming[session.sessionId]?.text) {
                            withAnimation {
                                proxy.scrollTo("streaming", anchor: .bottom)
                            }
                        }
                    }
                } else if !state.historyLoaded.contains(session.sessionId) {
                    ContentUnavailableView {
                        Label("加载历史…", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("正在拉取会话历史")
                    }
                } else {
                    ContentUnavailableView(
                        "还没有消息",
                        systemImage: "text.bubble",
                        description: Text("发送第一条消息开始对话")
                    )
                }
            } else {
                ScrollViewReader { proxy in
                    GeometryReader { viewport in
                        ScrollView {
                            LazyVStack(spacing: DSSpace.s2) {
                                if state.hasMoreMessages(sessionId: session.sessionId) {
                                    Button {
                                        state.loadMoreHistory(sessionId: session.sessionId)
                                    } label: {
                                        Label("加载更早的消息", systemImage: "arrow.up.circle")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.accent)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                ForEach(visibleMessages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                if let live = state.streaming[session.sessionId], live.active {
                                    StreamingBubble(
                                        thinkingExcerpt: String(live.reasoning.suffix(120)),
                                        partialText: live.text,
                                        phase: live.currentBlock,
                                        startTime: live.startedAt
                                    )
                                    .id("streaming")
                                }
                            }
                            .padding(.horizontal, DSSpace.page)
                            .padding(.top, DSSpace.s2)
                            .padding(.bottom, DSSpace.s2)
                            .background(
                                GeometryReader { content in
                                    Color.clear.preference(
                                        key: ContentBottomKey.self,
                                        value: content.frame(in: .named("chatScroll")).maxY
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "chatScroll")
                        .onPreferenceChange(ContentBottomKey.self) { bottomY in
                            // 内容底边距视口底部的距离 ≤ 40pt 视为"在底部"
                            nearBottom = bottomY - viewport.size.height <= 40
                        }
                        .defaultScrollAnchor(.bottom)
                        .scrollDismissesKeyboard(.interactively)
                        .simultaneousGesture(TapGesture().onEnded {
                            composerFocused = false
                        })
                        .onChange(of: visibleMessages.last?.id) { _, newLastId in
                            // 只有"尾部新增消息"且用户在底部时才滚底；
                            // 上翻阅读历史时新消息到达不拽回底部。
                            if let newLastId, newLastId != lastKnownLastId {
                                lastKnownLastId = newLastId
                                if nearBottom, let last = visibleMessages.last {
                                    withAnimation {
                                        proxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: state.streaming[session.sessionId]?.text) {
                            if nearBottom {
                                withAnimation {
                                    proxy.scrollTo("streaming", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - actions

    private func send(mode: String) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        sending = true
        Task {
            defer { sending = false }
            do {
                try await state.sendMessage(sessionId: session.sessionId, text: text, mode: mode)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cancel() {
        Task {
            do {
                try await state.cancelSession(sessionId: session.sessionId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendCommand(_ command: String) {
        Task {
            do {
                try await state.sendCommand(sessionId: session.sessionId, command: command)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func beginEdit(_ item: QueueItem) {
        editText = item.message.text
        editingQueueItem = item
    }

    private func queueAction(_ item: QueueItem, _ action: QueueItemAction) {
        Task {
            do {
                try await state.updateQueueItem(sessionId: session.sessionId, itemId: item.id, action: action)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func goalAction(_ action: String) {
        Task {
            do {
                try await state.goalAction(sessionId: session.sessionId, action: action)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func respond(_ approval: ApprovalRequest, _ outcome: String) {
        Task {
            do {
                if outcome == "allowed-once" {
                    try await state.approve(approval)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    try await state.reject(approval)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - model picker options

    private var modelOptions: [ModelPicker.ModelOption] {
        var options: [ModelPicker.ModelOption] = []
        for group in catalog?.groups ?? [] {
            for model in group.models {
                if model.efforts.isEmpty {
                    options.append(.init(provider: group.name, name: model.name, effort: "",
                                         current: catalog?.currentModel == model.id))
                } else {
                    for effort in model.efforts {
                        options.append(.init(provider: group.name, name: model.name, effort: effort.name,
                                             current: catalog?.currentModel == model.id
                                                && catalog?.currentEffort == effort.id))
                    }
                }
            }
        }
        return options
    }

    private func applyModel(_ opt: ModelPicker.ModelOption) {
        Task {
            do {
                // find the matching catalog entry
                guard let catalog else { return }
                for group in catalog.groups {
                    for model in group.models where model.name == opt.name {
                        let effortId = model.efforts.first(where: { $0.name == opt.effort })?.id
                        try await state.selectModel(
                            sessionId: session.sessionId,
                            provider: group.id,
                            model: model.id,
                            effort: effortId
                        )
                        return
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
// MARK: - 内联提问卡（选项直接在消息界面显示，不跳页）

struct QuestionInlineCard: View {
    @Bindable var state: AppState
    let question: QuestionRequest
    @State private var selections: [String: Set<String>] = [:]
    @State private var submitting = false
    @State private var errorMessage: String?

    private var hasMultiSelect: Bool {
        question.questions.contains(where: \.multiSelect)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(DSColor.statusWaiting)
                Text("Agent 提问")
                    .font(DSFont.footnote.weight(.semibold))
                    .foregroundStyle(DSColor.statusWaiting)
                Spacer()
            }
            ForEach(question.questions) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.question)
                        .font(DSFont.subheadline.weight(.medium))
                        .foregroundStyle(DSColor.textPrimary)
                    if let detail = item.detail {
                        Text(detail)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    ForEach(item.options) { option in
                        optionRow(item: item, option: option)
                    }
                }
            }
            if hasMultiSelect {
                Button {
                    submit()
                } label: {
                    if submitting {
                        ProgressView()
                    } else {
                        Text("提交")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColor.accent)
                .disabled(submitting)
            }
        }
        .padding(DSSpace.s3)
        .background(DSColor.waitingSurface, in: RoundedRectangle(cornerRadius: DSRadius.md))
        .alert("提交失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func optionRow(item: QuestionItem, option: QuestionOption) -> some View {
        let selected = selections[item.id]?.contains(option.id) ?? false
        return Button {
            if item.multiSelect {
                var set = selections[item.id] ?? []
                if selected { set.remove(option.id) } else { set.insert(option.id) }
                selections[item.id] = set
            } else {
                // 单选：点击即提交
                submitSingle(item: item, optionId: option.id)
            }
        } label: {
            HStack(spacing: DSSpace.s2) {
                Image(systemName: item.multiSelect
                      ? (selected ? "checkmark.square.fill" : "square")
                      : (selected ? "largecircle.fill.circle" : "circle"))
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? DSColor.accent : DSColor.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                    if let detail = option.detail {
                        Text(detail)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(DSColor.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: DSRadius.sm))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(submitting)
    }

    private func submitSingle(item: QuestionItem, optionId: String) {
        submit(fixed: [(id: item.id, selected: [optionId])])
    }

    private func submit() {
        let answers = question.questions.map { item in
            (id: item.id, selected: Array(selections[item.id] ?? []))
        }
        submit(fixed: answers)
    }

    private func submit(fixed answers: [(id: String, selected: [String])]) {
        submitting = true
        Task {
            defer { submitting = false }
            do {
                try await state.answer(question, answers: answers)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Question sheet

struct QuestionSheet: View {
    @Bindable var state: AppState
    let question: QuestionRequest
    @Environment(\.dismiss) private var dismiss
    @State private var selections: [String: Set<String>] = [:]
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            ForEach(question.questions) { item in
                Section(item.header ?? "问题") {
                    Text(item.question)
                        .font(.subheadline)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(item.options) { option in
                        OptionToggle(
                            item: item,
                            option: option,
                            isOn: Binding(
                                get: { selections[item.id]?.contains(option.id) ?? false },
                                set: { on in
                                    toggle(option.id, in: item, on: on)
                                }
                            )
                        )
                    }
                }
            }
        }
        .navigationTitle("回答提问")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("跳过") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if submitting {
                            ProgressView()
                        } else {
                            Text("提交")
                        }
                    }
                    .disabled(submitting)
                }
            }
            .alert("提交失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private func toggle(_ optionId: String, in item: QuestionItem, on: Bool) {
        var set = selections[item.id] ?? []
        if item.multiSelect {
            if on { set.insert(optionId) } else { set.remove(optionId) }
        } else {
            set = on ? [optionId] : []
        }
        selections[item.id] = set
    }

    private func submit() {
        submitting = true
        let answers = question.questions.map { item in
            (id: item.id, selected: Array(selections[item.id] ?? []))
        }
        Task {
            defer { submitting = false }
            do {
                try await state.answer(question, answers: answers)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct OptionToggle: View {
    let item: QuestionItem
    let option: QuestionOption
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: item.multiSelect
                ? (isOn ? "checkmark.square.fill" : "square")
                : (isOn ? "largecircle.fill.circle" : "circle"))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(option.label)
                if let detail = option.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

