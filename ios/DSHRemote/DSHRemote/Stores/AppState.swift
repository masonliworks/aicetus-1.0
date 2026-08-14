// AppState.swift — global app state: connection, sessions, approvals,
// questions, chat caches, and local notifications.

import Foundation
import Observation
@preconcurrency import UserNotifications

@MainActor
@Observable
final class AppState {
    /// Live instance for app-delegate callbacks (notification taps). Written
    /// once at app start, read from the notification delegate (main thread).
    nonisolated(unsafe) static var live: AppState?

    enum ConnectionPhase: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    // MARK: - Published state

    var config: ServerConfig? {
        didSet { persistConfig() }
    }
    private(set) var phase: ConnectionPhase = .disconnected
    private(set) var hostVersion: String?
    private(set) var hostModel: String?
    /// Whether the last probe reached DSH through the bridge (drives the banner).
    private(set) var dshReachable = false
    private(set) var sessions: [SessionInfo] = []
    private(set) var approvals: [ApprovalRequest] = []
    private(set) var questions: [QuestionRequest] = []
    /// Chat message cache, keyed by sessionId.
    private(set) var messages: [String: [ChatMessage]] = [:]
    /// Queued/steering messages per session (web-style queue cards).
    private(set) var queueItems: [String: [QueueItem]] = [:]
    /// Sessions whose full history has been pulled.
    private(set) var historyLoaded: Set<String> = []
    /// How many messages are shown per session (web-style "load earlier" paging).
    private(set) var visibleCounts: [String: Int] = [:]
    /// 服务器还有更早的历史页可拉（session.history 尾部页 hasMore）。
    private(set) var historyHasMore: [String: Bool] = [:]
    /// 当前已加载最早事件的 seq（拉更早页的 beforeSeq 游标，不包含该 seq）。
    private(set) var historyBaseSeq: [String: Int] = [:]
    /// 正在拉取更早历史页的会话（防重复点击）。
    private(set) var loadingOlder: Set<String> = []

    static let initialVisibleMessages = 60
    static let historyPageSize = 60

    func visibleCount(for sessionId: String) -> Int {
        min(visibleCounts[sessionId] ?? Self.initialVisibleMessages,
            (messages[sessionId] ?? []).count)
    }

    func hasMoreMessages(sessionId: String) -> Bool {
        visibleCount(for: sessionId) < (messages[sessionId] ?? []).count
            || historyHasMore[sessionId] == true
    }

    func loadMoreHistory(sessionId: String) {
        // 1) 本地已加载但被隐藏的：先直接放出更多。
        if visibleCount(for: sessionId) < (messages[sessionId] ?? []).count {
            visibleCounts[sessionId] = visibleCount(for: sessionId) + Self.historyPageSize
            return
        }
        // 2) 全部显示且服务器还有更早 → 拉上一页（web 式 beforeSeq 分页）。
        guard let client,
              historyHasMore[sessionId] == true,
              !loadingOlder.contains(sessionId) else { return }
        loadingOlder.insert(sessionId)
        Task {
            defer { loadingOlder.remove(sessionId) }
            do {
                let value = try await client.sessionHistory(
                    sessionId: sessionId,
                    beforeSeq: historyBaseSeq[sessionId],
                    maxMessages: 50
                )
                let meta = SessionHistoryParser.metadata(from: value)
                let older = SessionHistoryParser.messages(from: value)
                var newMessages = messages
                var cache = newMessages[sessionId] ?? []
                let seen = Set(cache.map(\.id))
                let add = older.filter { !seen.contains($0.id) }
                // 更早的消息插到头部（seq 严格更小，保持升序）。
                cache.insert(contentsOf: add, at: 0)
                newMessages[sessionId] = cache
                messages = newMessages
                historyHasMore[sessionId] = meta.hasMore
                if let baseSeq = meta.baseSeq { historyBaseSeq[sessionId] = baseSeq }
                // 底部锚定：suffix 窗口随之扩大，新增内容出现在上方。
                visibleCounts[sessionId] = visibleCount(for: sessionId) + add.count
            } catch {
                lastError = "加载更早消息失败: \(error.localizedDescription)"
            }
        }
    }
    private(set) var lastError: String?
    /// Set when a notification is tapped; the session list consumes it to push.
    var selectedSessionId: String?
    /// Workspaces and agent presets (loaded lazily for the creation panel).
    private(set) var workspaces: [WorkspaceInfo] = []
    private(set) var presets: [AgentPresetInfo] = []
    /// Model catalogs per session (session.models).
    private(set) var modelCatalogs: [String: ModelCatalog] = [:]
    /// 子代理列表 per parent session (subagent.list)
    private(set) var subagents: [String: [SubagentInfo]] = [:]
    /// Archived session ids (hidden from the list; workspace.list + host frames).
    private(set) var archivedSessionIds: Set<String> = []
    /// Live streaming assistant output per session (chunk deltas).
    private(set) var streaming: [String: StreamingMessage] = [:]

    /// The assistant message currently being generated in one session.
    struct StreamingMessage {
        var turn = 0
        var step = 0
        var reasoning = ""
        var text = ""
        var currentBlock = ""
        /// turn/start 后即为活跃（即使尚无任何输出 → 显示"生成中"）
        var active = false
        /// 轮次开始时间（Deep diving 计时用）
        var startedAt: Date?

        var isEmpty: Bool { reasoning.isEmpty && text.isEmpty }
    }

    private var client: BridgeClient?
    private var streamTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?
    /// 最近一次事件帧到达时间（SSE 心跳看门狗）
    private var lastFrameAt: Date?

    // MARK: - Connection

    var isConnected: Bool { phase == .connected }

    init() {
        config = ServerConfigStore.config
    }

    func connect() {
        guard let config, config.isValid else {
            phase = .failed("请先在设置中配置服务器地址和 Token")
            return
        }
        let client = BridgeClient(baseURL: config.normalizedBaseURL, token: config.token)
        self.client = client
        phase = .connecting
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            await self?.streamLoop(client: client)
        }
        Task { [weak self] in
            await self?.refresh()
        }
        Task { [weak self] in
            await self?.loadWorkspaces()
        }
        startAutoRefresh()
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        client = nil
        phase = .disconnected
        dshReachable = false
    }

    /// App 回到前台或 SSE 疑似假死时强制重建事件流（iOS 后台挂起会
    /// 让 URLSession.bytes 流静默失效——不报错也不返回，必须主动重连）。
    /// 重建事件流。backfill=true 时重拉历史补齐错过的消息
    ///（假死恢复用）；发送消息后的重连不拉历史（避免列表跳动）。
    func reconnectStream(backfill: Bool = true) {
        guard let client else { return }
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            await self?.streamLoop(client: client)
        }
        if backfill {
            Task { [weak self] in
                await self?.reloadAllHistory()
            }
        }
    }

    /// 重拉所有已打开会话的历史，补齐假死期间错过的消息。
    private func reloadAllHistory() async {
        let opened = historyLoaded
        for sessionId in opened {
            historyLoaded.remove(sessionId)
            await loadHistory(sessionId: sessionId)
        }
    }

    /// Keep the session list fresh without manual pull-to-refresh: running
    /// states, titles, and goals update on a timer (the event stream already
    /// pushes real-time deltas in between). Workspace membership + archived
    /// ids refresh every 5th cycle so grouping/archival self-heal.
    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self, !Task.isCancelled else { return }
                await self.refresh()
                tick += 1
                if tick % 5 == 0 {
                    await self.loadWorkspaces()
                }
                // SSE 心跳看门狗：20 秒无任何事件帧 → 强制重连事件流
                //（桥接心跳每 15 秒一次，正常流绝不会触发）
                if let last = self.lastFrameAt,
                   Date().timeIntervalSince(last) > 20 {
                    self.reconnectStream()
                }
            }
        }
    }

    /// Number of sessions currently running an agent.
    var runningSessions: Int {
        sessions.filter(\.running).count
    }

    func refresh() async {
        guard let client else { return }
        do {
            let value = try await client.call("session.list")
            guard let items = Wire.arr(value as? [String: Any], "items") else {
                lastError = "session.list 返回格式异常"
                return
            }
            sessions = items.compactMap { Wire.dict($0).map(SessionInfo.init) }
            applyWorkspaceMembership()
            dshReachable = true
            if phase != .connected { phase = .connected }
            lastError = nil
            if hostModel == nil {
                Task { [weak self] in await self?.loadHostInfo(client: client) }
            }
        } catch {
            dshReachable = false
            if phase == .connecting {
                phase = .failed(error.localizedDescription)
            }
            lastError = error.localizedDescription
        }
    }

    private func loadHostInfo(client: BridgeClient) async {
        guard let raw = try? await client.call("host.describe"),
              let value = raw as? [String: Any] else { return }
        hostVersion = Wire.string(value, "version")
        hostModel = Wire.string(value, "model")
    }

    /// 空白会话（无历史）直接标记已加载，跳过拉取。
    func markHistoryLoaded(sessionId: String) {
        historyLoaded.insert(sessionId)
    }

    /// Load the full conversation history for a session (idempotent).
    func loadHistory(sessionId: String) async {
        guard let client, !historyLoaded.contains(sessionId) else { return }
        do {
            let value = try await client.sessionHistory(sessionId: sessionId)
            let meta = SessionHistoryParser.metadata(from: value)
            let history = SessionHistoryParser.messages(from: value)
            guard !history.isEmpty else { return }
            var merged = history
            let seen = Set(merged.map(\.id))
            let seenUserTexts = Set(history.filter { $0.role == "user" }.map(\.text))
            for msg in messages[sessionId] ?? [] where !seen.contains(msg.id) {
                // 本地回显若已被历史（服务器版本）覆盖，按文本去重跳过
                if msg.id.hasPrefix("local-") && seenUserTexts.contains(msg.text) { continue }
                merged.append(msg)
            }
            // session.history 返回的是"尾部页"（最新 N 条，hasMore=true 表示
            // 还有更早的）。缓存中未被历史覆盖的更早消息必须按 seq 插回前面，
            // 否则老消息会被追加到最新消息之后（"历史跑到最新前面"）。
            let indexed = merged.enumerated().map { ($0.element, $0.offset) }
            merged = indexed
                .sorted { a, b in
                    if a.0.seq != b.0.seq { return a.0.seq < b.0.seq }
                    return a.1 < b.1
                }
                .map(\.0)
            var newMessages = messages
            newMessages[sessionId] = merged
            messages = newMessages
            historyHasMore[sessionId] = meta.hasMore
            if let baseSeq = meta.baseSeq { historyBaseSeq[sessionId] = baseSeq }
            historyLoaded.insert(sessionId)
        } catch {
            lastError = "加载历史失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Event stream

    /// 事件循环：POST 轮询桥接的帧缓冲（2 秒一次）。
    /// 你所在网络下 SSE 长连接不通，但 POST 稳定——轮询完全绕开长连接问题。
    private func streamLoop(client: BridgeClient) async {
        var after = 0
        var failures = 0
        while !Task.isCancelled {
            do {
                let (frames, latestIdx) = try await client.pollEvents(after: after)
                failures = 0
                for f in frames {
                    guard let which = Wire.string(f, "which"),
                          let frame = Wire.dict(f, "frame") else { continue }
                    handleFrame(event: which, json: frame)
                    if let idx = Wire.int(f, "idx") { after = max(after, idx) }
                }
                after = max(after, latestIdx)
            } catch {
                failures += 1
            }
            if Task.isCancelled { return }
            let delay: UInt64 = failures > 3 ? 5_000_000_000 : 2_000_000_000
            try? await Task.sleep(nanoseconds: delay)
        }
    }

    private func handleFrame(event: String, json: [String: Any]) {
        lastFrameAt = Date()
        let payload = Wire.dict(json, "payload") ?? json
        switch event {
        case "mux":
            handleMuxFrame(payload, envelopeRpcId: Wire.string(json, "rpcId") ?? "")
        case "host":
            handleHostFrame(payload)
        default:
            break
        }
    }

    private func handleMuxFrame(_ d: [String: Any], envelopeRpcId: String) {
        guard let frame = MuxFrame.parse(d, rpcId: envelopeRpcId) else { return }
        switch frame {
        case .sessionQueue(let sessionId, let items):
            let pending = items.filter { $0.isQueued || $0.isSteering }
            var newQueue = queueItems
            newQueue[sessionId] = pending
            queueItems = newQueue
            // 消息已在发送时本地回显，这里只维护队列卡片
        case .sessionJobs(let sessionId, let jobs):
            if let idx = sessions.firstIndex(where: { $0.sessionId == sessionId }) {
                sessions[idx].jobs = jobs
            }
        case .sessionProjection(let sessionId, let key, let value):
            if key == "goal", let idx = sessions.firstIndex(where: { $0.sessionId == sessionId }) {
                sessions[idx].goal = GoalView(value)
            }
        case .approvalRequested(let approval):
            if !approvals.contains(where: { $0.id == approval.id }) {
                approvals.append(approval)
                notify(title: "工具调用待审批", body: "\(approval.toolName): \(approval.reason ?? "需要你批准")",
                       sessionId: approval.sessionId)
            }
        case .approvalResolved(let sessionId, let approvalId, _):
            approvals.removeAll { $0.approvalId == approvalId }
            if let idx = sessions.firstIndex(where: { $0.sessionId == sessionId }) {
                refreshSessionSoon(idx: idx)
            }
        case .questionRequested(let question):
            if !questions.contains(where: { $0.id == question.id }) {
                questions.append(question)
                let first = question.questions.first?.question ?? "问题"
                notify(title: "Agent 提问", body: first, sessionId: question.sessionId)
            }
        case .questionResolved(_, let questionRpcId, _):
            questions.removeAll { $0.questionRpcId == questionRpcId }
        case .sessionEvent(let sessionId, let event):
            handleSessionEvent(sessionId: sessionId, event: event)
        case .sessionSubscribed:
            break
        case .streamError(let message):
            lastError = "事件流错误: \(message)"
        }
    }

    /// Live event stream: assistant chunks stream into `streaming`, complete
    /// assistant messages finalize into the message cache.
    private func handleSessionEvent(sessionId: String, event: [String: Any]) {
        guard let type = Wire.string(event, "type") else { return }
        let data = Wire.dict(event, "data") ?? [:]
        switch type {
        case "assistant/chunk":
            guard let chunk = Wire.dict(data, "chunk") else { return }
            var s = streaming[sessionId] ?? StreamingMessage()
            s.active = true
            s.startedAt = s.startedAt ?? Date()
            s.turn = Wire.int(data, "turn") ?? s.turn
            s.step = Wire.int(data, "step") ?? s.step
            switch Wire.string(chunk, "type") {
            case "block-start":
                s.currentBlock = Wire.string(chunk, "blockType") ?? ""
            case "reasoning-delta":
                s.reasoning += Wire.string(chunk, "text") ?? ""
            case "text-delta":
                s.text += Wire.string(chunk, "text") ?? ""
            default:
                break
            }
            var newStreaming = streaming
            newStreaming[sessionId] = s
            streaming = newStreaming
        case "assistant/message":
            guard var message = Wire.dict(data, "message") else { return }
            let seq = Wire.int(event, "seq") ?? 0
            if message["id"] == nil { message["id"] = "assistant-\(seq)" }
            message["seq"] = seq
            let msg = ChatMessage(message)
            var newMessages = messages
            var cache = newMessages[sessionId] ?? []
            if !cache.contains(where: { $0.id == msg.id }) {
                cache.append(msg)
                newMessages[sessionId] = cache
                messages = newMessages
            }
            var newStreaming = streaming
            newStreaming[sessionId] = nil
            streaming = newStreaming
        case "turn/start":
            // 轮次开始：立即进入流式活跃状态（首 token 前显示"生成中"）
            var newStreaming = streaming
            var s = newStreaming[sessionId] ?? StreamingMessage()
            s.active = true
            s.startedAt = s.startedAt ?? Date()
            s.turn = Wire.int(data, "turn") ?? s.turn
            newStreaming[sessionId] = s
            streaming = newStreaming
        case "turn/end":
            var newStreaming = streaming
            newStreaming[sessionId] = nil
            streaming = newStreaming
        case "user/message":
            // Real-time user echo (steer): append once.
            guard let source = Wire.dict(data, "source"),
                  Wire.string(source, "kind") == "user" else { break }
            var m = data
            let seq = Wire.int(event, "seq") ?? 0
            if m["id"] == nil { m["id"] = "user-\(seq)" }
            let msg = ChatMessage(m)
            var newMessages = messages
            var cache = newMessages[sessionId] ?? []
            // 本地回显保持稳定 id；若已有同文本本地回显，只升级其 seq
            //（服务器帧即本地回显内容），不新增行，避免列表重排。
            if let idx = cache.firstIndex(where: { $0.role == "user" && $0.text == msg.text && $0.id.hasPrefix("local-") }) {
                cache[idx].seq = msg.seq
                newMessages[sessionId] = cache
                messages = newMessages
                break
            }
            if !cache.contains(where: { $0.id == msg.id }) {
                cache.append(msg)
                newMessages[sessionId] = cache
                messages = newMessages
            }
        default:
            break
        }
    }

    private func handleHostFrame(_ d: [String: Any]) {
        guard let frame = HostFrame.parse(d) else { return }
        switch frame {
        case .sessionStatus(let sessionId, let running):
            if let idx = sessions.firstIndex(where: { $0.sessionId == sessionId }) {
                sessions[idx].running = running
            }
        case .sessionAdded(let sessionId, _, _, _):
            if !sessions.contains(where: { $0.sessionId == sessionId }) {
                Task { await self.refresh() }
            }
        case .sessionRemoved:
            Task { await self.refresh() }
        case .agentError(let sessionId, let message):
            lastError = "Agent 错误: \(message)"
            notify(title: "Agent 报错", body: message, sessionId: sessionId)
            if let idx = sessions.firstIndex(where: { $0.sessionId == sessionId }) {
                sessions[idx].running = false
            }
        case .workspaceChanged:
            Task { await self.refresh() }
        case .archivedSessionsChanged(let ids):
            archivedSessionIds = Set(ids)
        case .remoteEvent, .streamError:
            break
        }
    }

    private func refreshSessionSoon(idx: Int) {
        // Pull the freshest session snapshot after an interaction resolves.
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }
            await self.refresh()
        }
    }

    // MARK: - Actions

    func createSession(workspaceId: String? = nil, agentPreset: String? = nil) async throws -> String {
        guard let client else { throw BridgeError.transport("未连接") }
        var payload: [String: Any] = [:]
        if let workspaceId { payload["workspaceId"] = workspaceId }
        if let agentPreset { payload["agentPreset"] = agentPreset }
        let value = try await client.call("session.create", payload: payload)
        let sessionId = Wire.string(Wire.dict(value) ?? [:], "sessionId")
            ?? Wire.string(value as? [String: Any] ?? [:], "id")
            ?? ""
        await refresh()
        return sessionId
    }

    func loadWorkspaces() async {
        guard let client else { return }
        if let value = try? await client.call("workspace.list") as? [String: Any] {
            workspaces = (Wire.arr(value, "items") ?? []).compactMap { Wire.dict($0).map(WorkspaceInfo.init) }
            archivedSessionIds = Set((Wire.arr(value, "archivedSessionIds") ?? []).compactMap { Wire.str($0) })
            applyWorkspaceMembership()
        }
    }

    /// Map sessions into their workspaces via workspace.list membership.
    private func applyWorkspaceMembership() {
        for i in sessions.indices {
            sessions[i].workspaceId = workspaces.first(where: { $0.sessionIds.contains(sessions[i].sessionId) })?.id
        }
    }

    func loadPresets() async {
        guard let client else { return }
        if let value = try? await client.call("agentPreset.list") as? [String: Any] {
            presets = (Wire.arr(value, "presets") ?? []).compactMap { Wire.dict($0).map(AgentPresetInfo.init) }
        }
    }

    func renameSession(sessionId: String, title: String) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.call("session.rename", payload: ["sessionId": sessionId, "title": title])
        await refresh()
    }

    func forkSession(sessionId: String) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.call("session.fork", payload: ["sessionId": sessionId])
        await refresh()
    }

    func archiveSession(sessionId: String) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.call("workspace.archiveSession", payload: ["sessionId": sessionId])
        archivedSessionIds.insert(sessionId)
        await refresh()
    }

    /// 拉取父会话的子代理列表（subagent.list）。
    func loadSubagents(sessionId: String) async {
        guard let client else { return }
        if let value = try? await client.call("subagent.list", payload: ["parentSessionId": sessionId]) as? [String: Any] {
            subagents[sessionId] = (Wire.arr(value, "entries") ?? []).compactMap { Wire.dict($0).map(SubagentInfo.init) }
        }
    }

    /// 中断某个子代理。
    func interruptSubagentOf(parentSessionId: String, subagentId: String) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.call("subagent.interrupt", payload: [
            "parentSessionId": parentSessionId,
            "childSessionId": subagentId,
        ])
        await loadSubagents(sessionId: parentSessionId)
    }

    /// Pull the model/effort catalog for a session (session.models).
    func loadModels(sessionId: String) async {
        guard let client else { return }
        if let value = try? await client.call("session.models", payload: ["sessionId": sessionId]) as? [String: Any] {
            modelCatalogs[sessionId] = ModelCatalog(value)
        }
    }

    func selectModel(sessionId: String, provider: String, model: String, effort: String?) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        var payload: [String: Any] = ["sessionId": sessionId, "provider": provider, "model": model]
        if let effort { payload["reasoningEffort"] = effort }
        _ = try await client.call("session.selectModel", payload: payload)
        await loadModels(sessionId: sessionId)
    }

    /// Send a slash command (/compact, /feedback, /goal ...) — dispatched as a
    /// queued message so the harness parses the command slot.
    func sendCommand(sessionId: String, command: String) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        let content: [[String: Any]] = [["type": "text", "text": command]]
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "mode": "queue",
            "content": content,
        ]
        _ = try await client.call("session.prompt", payload: payload)
    }

    func sendMessage(sessionId: String, text: String, mode: String = "queue") async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        let content: [[String: Any]] = [["type": "text", "text": text]]
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "mode": mode,          // "queue" = 排队发送（默认）; "steer" = 插话引导
            "content": content,
        ]
        _ = try await client.call("session.prompt", payload: payload)
        // 发送后立即重建事件流：若旧流已假死，回复帧不会错过。
        // 不拉历史——避免合并后列表跳动/滚动被拽走。
        reconnectStream(backfill: false)
        // 无条件本地回显（web 端发送后消息立即出现在对话流）；
        // 事件帧到达时按内容替换为服务器版本。
        var newMessages = messages
        var cache = newMessages[sessionId] ?? []
        cache.append(ChatMessage([
            "id": "local-\(UUID().uuidString)",
            "role": "user",
            "seq": Int.max,   // 服务器帧到达前视为最新；帧到达后升级为真实 seq
            "content": [["type": "text", "text": text]],
        ]))
        newMessages[sessionId] = cache
        messages = newMessages
    }

    /// Web-style queue card actions: edit / remove / steer a queued message.
    func updateQueueItem(sessionId: String, itemId: String, action: QueueItemAction) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        var actionPayload: [String: Any] = ["kind": action.kind]
        switch action {
        case .edit(let text):
            actionPayload["content"] = [["type": "text", "text": text]]
        case .remove, .steer:
            break
        }
        _ = try await client.call("session.updateQueue", payload: [
            "sessionId": sessionId,
            "itemId": itemId,
            "action": actionPayload,
        ])
    }

    func cancelSession(sessionId: String) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.call("session.cancel", payload: ["sessionId": sessionId])
    }

    func interruptSubagent(sessionId: String) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.call("subagent.interrupt", payload: ["sessionId": sessionId])
    }

    func approve(_ approval: ApprovalRequest) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.respondApproval(
            rpcId: approval.id,
            sessionId: approval.sessionId,
            approvalId: approval.approvalId,
            outcome: "allowed-once"
        )
    }

    func reject(_ approval: ApprovalRequest) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.respondApproval(
            rpcId: approval.id,
            sessionId: approval.sessionId,
            approvalId: approval.approvalId,
            outcome: "rejected"
        )
    }

    func answer(_ question: QuestionRequest, answers: [(id: String, selected: [String])]) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        _ = try await client.respondQuestion(
            rpcId: question.id,
            sessionId: question.sessionId,
            answers: answers
        )
    }

    // MARK: - Goals

    func createGoal(sessionId: String, objective: String, maxRounds: Int?) async throws {
        guard let client else { throw BridgeError.transport("未连接") }
        var payload: [String: Any] = ["sessionId": sessionId, "objective": objective]
        if let maxRounds { payload["maxGoalRounds"] = maxRounds }
        _ = try await client.call("goal.create", payload: payload)
        await refresh()
    }

    func goalAction(sessionId: String, action: String) async throws {
        guard let client, let session = sessions.first(where: { $0.sessionId == sessionId }),
              let goal = session.goal else { return }
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "ref": ["id": goal.goalId, "revision": goal.revision],
        ]
        do {
            _ = try await client.call("goal.\(action)", payload: payload)
            // Optimistic local update so the strip hides immediately.
            if let idx = sessions.firstIndex(where: { $0.sessionId == sessionId }) {
                if action == "complete" {
                    sessions[idx].goal = nil
                } else if action == "pause" {
                    sessions[idx].goal?.phaseOverride = "paused"
                } else if action == "resume" {
                    sessions[idx].goal?.phaseOverride = "active"
                }
            }
        } catch {
            // The goal may have changed elsewhere (completed by the agent or
            // another client). Refresh and treat "no longer active" as success —
            // the user's intent (finish/pause/resume) is already satisfied.
            await refresh()
            if let current = sessions.first(where: { $0.sessionId == sessionId }),
               current.activeGoal == nil {
                return
            }
            // 服务器拒绝但快照可能过期：本地强制隐藏横幅，下次刷新以服务器为准
            if let idx = sessions.firstIndex(where: { $0.sessionId == sessionId }) {
                sessions[idx].goal = nil
            }
            throw BridgeError.transport("目标操作未生效，请稍后重试")
        }
        await refresh()
    }

    // MARK: - Notifications

    private func notify(title: String, body: String, sessionId: String? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let sessionId {
                content.userInfo = ["sessionId": sessionId]
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            Task { @MainActor in
                try? await center.add(request)
            }
        }
    }

    private func persistConfig() {
        ServerConfigStore.config = config
    }
}
