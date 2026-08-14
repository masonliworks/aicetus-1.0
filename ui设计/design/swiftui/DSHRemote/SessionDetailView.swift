//
//  SessionDetailView.swift
//  DSH Remote — 会话详情（核心页面，规范 §6.3）
//
//  自上而下：消息列表(含流式) → 队列卡片区 → 目标条 → 任务条 → 审批条
//           → 底部信息栏 → 输入栏
//

import SwiftUI

struct SessionDetailView: View {
    let session: Session

    // --- 以下为 stub 状态，真实数据由会话 Store 驱动 ---
    @State private var messages = SampleData.messages
    @State private var streamingText = "正在升级依赖，预计改动 3 个文件"
    @State private var thinkingExcerpt = "对比 jsonwebtoken v8/v9 的 API 差异，确认废弃参数…"
    @State private var queue = SampleData.queue
    @State private var goalSummary: String? = "完成 session 服务抽离并通过测试"
    @State private var jobs = SampleData.jobs
    @State private var approval: ApprovalRequest? = SampleData.approval
    @State private var composerText = ""
    @State private var showModelPicker = false
    @State private var showCreateGoal = false

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表（完整历史 + 流式；默认滚底，新内容自动跟随）
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DSSpace.s2) {
                        ForEach(messages) { MessageBubble(message: $0) }
                        StreamingBubble(thinkingExcerpt: thinkingExcerpt,
                                        partialText: streamingText)
                            .id("streaming")
                    }
                    .padding(.horizontal, DSSpace.page)
                    .padding(.top, DSSpace.s2)
                }
                .scrollDismissesKeyboard(.interactively)     // 滚动收键盘
                .onChange(of: streamingText) {              // 新内容自动滚底
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
            }

            // 队列卡片区（.bar 材质容器，有内容才显示）
            if !queue.isEmpty {
                VStack(spacing: DSSpace.s1) {
                    ForEach(queue) { QueueCard(item: $0) }
                }
                .padding(.horizontal, DSSpace.page)
                .padding(.vertical, DSSpace.s1)
                .barMaterial()
            }

            VStack(spacing: DSSpace.s1) {
                GoalStrip(summary: goalSummary,
                          onCreate: { showCreateGoal = true })
                if !jobs.isEmpty { JobStrip(jobs: jobs) }
                if let approval {
                    ApprovalCard(request: approval,
                                 onDeny: { self.approval = nil },          // §7 审批成功即时移除 + 轻震动
                                 onAllowOnce: {
                        self.approval = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                }
            }
            .padding(.horizontal, DSSpace.page)
            .padding(.vertical, DSSpace.s1)

            SessionStatusBar(modelName: "deepseek-v4", effort: "High",
                             contextUsed: 0.62,
                             onPickModel: { showModelPicker = true })

            Composer(text: $composerText, running: session.status == .running)
        }
        .background(DSColor.backgroundBase)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)                  // §6.3 进入详情隐藏 Tab bar（全屏）
        .popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
            ModelPicker(options: [
                .init(provider: "DeepSeek", name: "deepseek-v4", effort: "High", current: true),
                .init(provider: "DeepSeek", name: "deepseek-v4-pro", effort: "Max", current: false),
                .init(provider: "DeepSeek", name: "deepseek-v4-flash", effort: "Off", current: false),
                .init(provider: "其他", name: "qwen3-max", effort: "Off", current: false),
            ])
            .presentationCompactAdaptation(.popover)     // 小气泡，非全屏
        }
        .sheet(isPresented: $showCreateGoal) {
            CreateGoalSheet { objective, maxRounds in
                goalSummary = objective
            }
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: SampleData.sessions[0])
    }
}
