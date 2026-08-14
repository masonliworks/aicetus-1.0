// WireModels.swift — domain models decoded from the DSH wire protocol.
// Parsing is intentionally lenient: the harness evolves quickly and unknown
// fields are ignored.

import Foundation

// MARK: - Session

struct ContextPressure: Hashable {
    let pressureTokens: Int
    let projectedTokens: Int
    let contextWindow: Int

    init?(_ d: [String: Any]) {
        guard let window = Wire.int(d, "contextWindow"), window > 0 else { return nil }
        contextWindow = window
        pressureTokens = Wire.int(d, "pressureTokens") ?? 0
        projectedTokens = Wire.int(d, "projectedTokens") ?? 0
    }

    /// Fraction of the context window currently projected in use (0...1).
    var usage: Double {
        guard contextWindow > 0 else { return 0 }
        return min(1, max(0, Double(projectedTokens) / Double(contextWindow)))
    }

    var usagePercent: Int {
        Int((usage * 100).rounded())
    }
}

/// sessionStats projection (web footer metrics).
struct SessionStats: Hashable {
    var turns = 0
    var steps = 0
    var llmMs: Double = 0
    var toolMs: Double = 0
    var ttftMs: Double = 0
    var ttftSteps = 0
    var decodeMs: Double = 0
    var decodeTokens = 0

    init(_ d: [String: Any]) {
        turns = Wire.int(d, "turns") ?? 0
        steps = Wire.int(d, "steps") ?? 0
        llmMs = Wire.num(d["llmMs"]) ?? 0
        toolMs = Wire.num(d["toolMs"]) ?? 0
        ttftMs = Wire.num(d["ttftMs"]) ?? 0
        ttftSteps = Wire.int(d, "ttftSteps") ?? 0
        decodeMs = Wire.num(d["decodeMs"]) ?? 0
        decodeTokens = Wire.int(d, "decodeTokens") ?? 0
    }
}

/// tokenUsage projection (billing buckets).
struct TokenUsage: Hashable {
    var uncachedInputTokens = 0
    var outputTokens = 0
    var cacheReadTokens = 0
    var cacheWriteTokens = 0

    init(_ d: [String: Any]) {
        uncachedInputTokens = Wire.int(d, "uncachedInputTokens") ?? 0
        outputTokens = Wire.int(d, "outputTokens") ?? 0
        cacheReadTokens = Wire.int(d, "cacheReadTokens") ?? 0
        cacheWriteTokens = Wire.int(d, "cacheWriteTokens") ?? 0
    }

    /// Sum of the three disjoint prompt-side billing buckets (web formula).
    var billedInputTokens: Int {
        uncachedInputTokens + cacheReadTokens + cacheWriteTokens
    }
}

struct SessionInfo: Identifiable, Hashable {
    var id: String { sessionId }
    let sessionId: String
    var updatedAt: Date?
    var running: Bool
    var blank: Bool
    var cwd: String?
    var agentPreset: String?
    var title: String?
    var goal: GoalView?
    var jobs: [JobView] = []
    var subagents: Int?
    var context: ContextPressure?
    var parentSessionId: String?
    var origin: String?

    /// 子代理会话（origin=subagent 或有父会话）——首页列表不显示
    var isSubagent: Bool {
        origin == "subagent" || parentSessionId != nil
    }
    var stats: SessionStats?
    var usage: TokenUsage?
    /// Filled from workspace.list membership (the harness does not report it
    /// on the session row itself).
    var workspaceId: String?

    init(_ d: [String: Any]) {
        sessionId = Wire.string(d, "sessionId") ?? ""
        if let ts = Wire.num(d["updatedAt"]) { updatedAt = Date(timeIntervalSince1970: ts / 1000) }
        running = Wire.bool(d, "running") ?? false
        blank = Wire.bool(d, "blank") ?? true
        cwd = Wire.string(d, "cwd")
        agentPreset = Wire.string(d, "agentPreset")
        parentSessionId = Wire.string(d, "parentSessionId")
        origin = Wire.string(d, "origin")
        if let values = Wire.dict(Wire.dict(d, "projections"), "values") {
            title = Wire.string(values, "title")
            if let g = Wire.dict(values, "goal") { goal = GoalView(g) }
            if let jobsArr = Wire.arr(values, "jobs") {
                jobs = jobsArr.compactMap { Wire.dict($0).map(JobView.init) }
            }
            if let sub = Wire.dict(values, "subagent"), let count = Wire.int(sub, "count") {
                subagents = count
            }
            if let cp = Wire.dict(values, "contextPressure") {
                context = ContextPressure(cp)
            }
            if let st = Wire.dict(values, "sessionStats") {
                stats = SessionStats(st)
            }
            if let u = Wire.dict(values, "tokenUsage") {
                usage = TokenUsage(u)
            }
        }
    }

    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        if let cwd { return URL(fileURLWithPath: cwd).lastPathComponent }
        return String(sessionId.prefix(12))
    }

    /// Completed goals are historical — not shown in the UI.
    var activeGoal: GoalView? {
        goal.flatMap { $0.isCompleted ? nil : $0 }
    }
}

// MARK: - Job (session/jobs frame, taskView)

struct JobView: Identifiable, Hashable {
    let id: String
    let kind: String
    let label: String
    let status: String
    let detail: String?
    let startedAt: Date?
    let finishedAt: Date?

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        kind = Wire.string(d, "kind") ?? "?"
        label = Wire.string(d, "label") ?? "?"
        status = Wire.string(d, "status") ?? "?"
        detail = Wire.string(d, "detail")
        if let ts = Wire.num(d["startedAt"]) { startedAt = Date(timeIntervalSince1970: ts / 1000) } else { startedAt = nil }
        if let ts = Wire.num(d["finishedAt"]) { finishedAt = Date(timeIntervalSince1970: ts / 1000) } else { finishedAt = nil }
    }
}

// MARK: - Goal

struct GoalView: Identifiable, Hashable {
    var id: String { goalId }
    /// Local optimistic phase override (cleared by the next server snapshot).
    var phaseOverride: String?
    let goalId: String
    let revision: Int
    let objective: String
    let phase: String
    let maxGoalRounds: Int?
    let roundsStarted: Int?
    let createdAt: Date?
    let updatedAt: Date?

    init(_ d: [String: Any]) {
        let goal = Wire.dict(d, "goal") ?? d
        goalId = Wire.string(goal, "id") ?? UUID().uuidString
        revision = Wire.int(goal, "revision") ?? 0
        objective = Wire.string(goal, "objective") ?? ""
        phase = Wire.string(goal, "phase") ?? "active"
        maxGoalRounds = Wire.int(goal, "maxGoalRounds")
        roundsStarted = Wire.int(d, "roundsStarted")
        if let ts = Wire.num(d["createdAt"]) { createdAt = Date(timeIntervalSince1970: ts / 1000) } else { createdAt = nil }
        if let ts = Wire.num(d["updatedAt"]) { updatedAt = Date(timeIntervalSince1970: ts / 1000) } else { updatedAt = nil }
    }

    private var effectivePhase: String { phaseOverride ?? phase }
    var isActive: Bool { effectivePhase == "active" }
    var isPaused: Bool { effectivePhase == "paused" }
    /// 服务器 phase 值为 "complete"（不是 "completed"）——两个都认，防止横幅残留
    var isCompleted: Bool {
        effectivePhase == "completed" || effectivePhase == "complete"
    }
}

// MARK: - Approval

struct ApprovalRequest: Identifiable, Hashable {
    let id: String          // rpcId of the server-request frame (echoed on respond)
    let sessionId: String
    let approvalId: String
    let toolName: String
    let callId: String?
    let reason: String?

    init(rpcId: String, _ d: [String: Any]) {
        id = rpcId
        sessionId = Wire.string(d, "sessionId") ?? ""
        approvalId = Wire.string(d, "approvalId") ?? ""
        toolName = Wire.string(d, "toolName") ?? "?"
        callId = Wire.string(d, "callId")
        reason = Wire.string(d, "reason")
    }
}

// MARK: - Question

struct QuestionItem: Identifiable, Hashable {
    let id: String
    let question: String
    let header: String?
    let detail: String?
    let multiSelect: Bool
    var options: [QuestionOption]

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        question = Wire.string(d, "question") ?? ""
        header = Wire.string(d, "header")
        detail = Wire.string(d, "detail")
        multiSelect = Wire.bool(d, "multiSelect") ?? false
        options = (Wire.arr(d, "options") ?? []).compactMap { Wire.dict($0).map(QuestionOption.init) }
    }
}

struct QuestionOption: Identifiable, Hashable {
    /// 协议中选项无 id 字段（只有 label/description）——用 label 作稳定标识，
    /// 避免随机 UUID 导致 ForEach 反复重建（选项显示/选择异常）。
    var id: String { label }
    let label: String
    let detail: String?

    init(_ d: [String: Any]) {
        label = Wire.string(d, "label") ?? "?"
        detail = Wire.string(d, "description") ?? Wire.string(d, "detail")
    }
}

/// A question/requested frame — one rpcId carries one or more questions.
struct QuestionRequest: Identifiable, Hashable {
    let id: String          // rpcId of the server-request frame (echoed on respond)
    let sessionId: String
    let questionRpcId: String
    let questions: [QuestionItem]

    init(rpcId: String, _ d: [String: Any]) {
        id = rpcId
        sessionId = Wire.string(d, "sessionId") ?? ""
        questionRpcId = Wire.string(d, "questionRpcId") ?? rpcId
        questions = (Wire.arr(d, "questions") ?? []).compactMap { Wire.dict($0).map(QuestionItem.init) }
    }
}

// MARK: - Chat message (session/queue frame)

/// One tool invocation inside an assistant message, with its (optional) result.
struct ToolCallBlock: Identifiable, Hashable {
    let id: String          // callId
    let name: String
    let arguments: String   // raw JSON string
    var resultText: String?
    var isError: Bool

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        name = Wire.string(d, "name") ?? "工具"
        arguments = Wire.string(d, "arguments") ?? ""
        resultText = nil
        isError = false
    }

    /// Compact one-line summary shown in the collapsed drawer row.
    var summary: String {
        if let resultText {
            if isError { return "失败" }
            let trimmed = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "完成" }
            return trimmed.count <= 60 ? trimmed : String(trimmed.prefix(60)) + "…"
        }
        return "执行中…"
    }

    var isFinished: Bool { resultText != nil }
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let role: String
    /// Final text reply (text blocks only).
    var text: String
    /// Thinking/reasoning text (reasoning blocks), hidden behind a drawer.
    var reasoning: String
    /// Tool invocations in this message (tool-call blocks).
    var toolCalls: [ToolCallBlock]
    var blockKinds: [String]
    /// Session event sequence number (chronological order key). 本地回显在
    /// 服务器帧到达前为 Int.max（视为最新），升级后取真实 seq。
    var seq: Int

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        seq = Wire.int(d, "seq") ?? 0
        role = Wire.string(d, "role") ?? "assistant"
        var textParts: [String] = []
        var reasoningParts: [String] = []
        var calls: [ToolCallBlock] = []
        var kinds: [String] = []
        for block in Wire.arr(d, "content") ?? [] {
            guard let b = Wire.dict(block) else { continue }
            let kind = Wire.string(b, "type") ?? "unknown"
            kinds.append(kind)
            switch kind {
            case "text":
                if let t = Wire.string(b, "text") { textParts.append(t) }
            case "reasoning":
                if let t = Wire.string(b, "text") { reasoningParts.append(t) }
            case "tool-call":
                calls.append(ToolCallBlock(b))
            default:
                break
            }
        }
        text = textParts.joined(separator: "\n\n")
        reasoning = reasoningParts.joined(separator: "\n\n")
        toolCalls = calls
        blockKinds = kinds
    }
}

// MARK: - Subagent

/// subagent.list 条目（宽松解析）
struct SubagentInfo: Identifiable, Hashable {
    let id: String
    var title: String
    var running: Bool

    init(_ d: [String: Any]) {
        id = Wire.string(d, "sessionId") ?? Wire.string(d, "id") ?? UUID().uuidString
        title = Wire.string(d, "title") ?? String(id.prefix(12))
        running = Wire.bool(d, "running") ?? false
    }
}

// MARK: - Session history reconstruction

/// Rebuilds the conversation from a session.history response. The history is a
/// full event stream: real user turns arrive as `user/message` (source.kind
/// == "user"), complete assistant replies as `assistant/message` (data.message),
/// and tool outcomes as separate `tool/result` events matched by toolCallId.
enum SessionHistoryParser {
    static func messages(from value: Any) -> [ChatMessage] {
        guard let dict = value as? [String: Any],
              let events = Wire.arr(dict, "events") else { return [] }

        // Pass 1: collect tool results keyed by toolCallId.
        var toolResults: [String: (text: String, isError: Bool)] = [:]
        for raw in events {
            guard let entry = Wire.dict(raw),
                  let event = Wire.dict(entry, "event"),
                  Wire.string(event, "type") == "tool/result",
                  let data = Wire.dict(event, "data"),
                  let message = Wire.dict(data, "message") else { continue }
            for block in Wire.arr(message, "content") ?? [] {
                guard let b = Wire.dict(block),
                      Wire.string(b, "type") == "tool-result",
                      let callId = Wire.string(b, "toolCallId") else { continue }
                var text = ""
                for part in Wire.arr(b, "content") ?? [] {
                    if let p = Wire.dict(part), let t = Wire.string(p, "text") {
                        text += t
                    }
                }
                toolResults[callId] = (text, Wire.bool(b, "isError") ?? false)
            }
        }

        // Pass 2: assemble messages, attaching tool results.
        var out: [ChatMessage] = []
        for raw in events {
            guard let entry = Wire.dict(raw),
                  let event = Wire.dict(entry, "event"),
                  let type = Wire.string(event, "type") else { continue }
            let seq = Wire.int(event, "seq") ?? 0
            switch type {
            case "user/message":
                guard var data = Wire.dict(event, "data") else { continue }
                let source = Wire.dict(data, "source")
                guard Wire.string(source ?? [:], "kind") == "user" else { continue }
                if data["id"] == nil { data["id"] = "user-\(seq)" }
                data["seq"] = seq
                out.append(ChatMessage(data))
            case "assistant/message":
                guard let m = Wire.dict(event, "data") else { continue }
                guard var message = Wire.dict(m, "message") else { continue }
                if message["id"] == nil { message["id"] = "assistant-\(seq)" }
                message["seq"] = seq
                var msg = ChatMessage(message)
                msg.toolCalls = msg.toolCalls.map { call in
                    var call = call
                    if let result = toolResults[call.id] {
                        call.resultText = result.text
                        call.isError = result.isError
                    }
                    return call
                }
                out.append(msg)
            default:
                continue
            }
        }
        return out
    }

    /// 分页元数据：hasMore（服务器还有更早）与 baseSeq（本页最早事件 seq，
    /// 拉更早一页的 beforeSeq 游标）。
    static func metadata(from value: Any) -> (hasMore: Bool, baseSeq: Int?) {
        guard let dict = value as? [String: Any],
              let events = Wire.arr(dict, "events") else { return (false, nil) }
        let seqs: [Int] = events.compactMap { entry in
            guard let d = Wire.dict(entry),
                  let event = Wire.dict(d, "event") else { return nil }
            return Wire.int(event, "seq")
        }
        return (Wire.bool(dict, "hasMore") ?? false, seqs.min())
    }
}

// MARK: - Model catalog (session.models)

struct ModelEffort: Identifiable, Hashable {
    let id: String
    let name: String

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        name = Wire.string(d, "name") ?? id
    }
}

struct ModelEntry: Identifiable, Hashable {
    let id: String
    let name: String
    var efforts: [ModelEffort] = []
    var defaultEffort: String?

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        name = Wire.string(d, "name") ?? id
        if let r = Wire.dict(d, "reasoning") {
            efforts = (Wire.arr(r, "efforts") ?? []).compactMap { Wire.dict($0).map(ModelEffort.init) }
            defaultEffort = Wire.string(r, "defaultEffort")
        }
    }
}

struct ModelGroup: Identifiable, Hashable {
    let id: String
    let name: String
    var models: [ModelEntry] = []

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        name = Wire.string(d, "name") ?? id
        models = (Wire.arr(d, "models") ?? []).compactMap { Wire.dict($0).map(ModelEntry.init) }
    }
}

struct ModelCatalog {
    var currentProvider: String
    var currentModel: String
    var currentEffort: String
    var groups: [ModelGroup] = []

    init(_ d: [String: Any]) {
        let cur = Wire.dict(d, "current") ?? [:]
        currentProvider = Wire.string(cur, "provider") ?? ""
        currentModel = Wire.string(cur, "model") ?? ""
        currentEffort = Wire.string(cur, "reasoningEffort") ?? ""
        groups = (Wire.arr(d, "groups") ?? []).compactMap { Wire.dict($0).map(ModelGroup.init) }
    }

    var currentModelName: String {
        groups.flatMap(\.models).first(where: { $0.id == currentModel })?.name ?? currentModel
    }
}

// MARK: - Workspace + preset (creation panel)

struct WorkspaceInfo: Identifiable, Hashable {
    let id: String
    let path: String
    let title: String
    let sessionIds: [String]

    init(_ d: [String: Any]) {
        id = Wire.string(d, "workspaceId") ?? UUID().uuidString
        path = Wire.string(d, "path") ?? ""
        title = Wire.string(d, "title") ?? ""
        sessionIds = (Wire.arr(d, "sessionIds") ?? []).compactMap { Wire.str($0) }
    }

    var displayTitle: String {
        title.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : title
    }
}

struct AgentPresetInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let isDefault: Bool

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        name = Wire.string(d, "name") ?? id
        description = Wire.string(d, "description") ?? ""
        isDefault = Wire.bool(d, "isDefault") ?? false
    }
}

// MARK: - Queue item (pending/queued message card)

/// One message in the session queue — shown as a card that supports
/// edit / remove / steer (the web client's queue card actions).
struct QueueItem: Identifiable, Hashable {
    let id: String
    let placement: String
    let message: ChatMessage

    init(_ d: [String: Any]) {
        id = Wire.string(d, "id") ?? UUID().uuidString
        placement = Wire.string(d, "placement") ?? "queued"
        message = ChatMessage(Wire.dict(d, "message") ?? [:])
    }

    var isQueued: Bool { placement == "queued" }
    var isSteering: Bool { placement == "steering" }
}

/// Actions available on a queue card (session.updateQueue).
enum QueueItemAction {
    case edit(String)
    case remove
    case steer

    var kind: String {
        switch self {
        case .edit: "edit"
        case .remove: "remove"
        case .steer: "steer"
        }
    }
}

// MARK: - Event frames (server-request payloads)

/// Parsed mux-stream frames we care about.
enum MuxFrame {
    case sessionSubscribed(sessionId: String, lastSeq: Int)
    case sessionQueue(sessionId: String, items: [QueueItem])
    case sessionJobs(sessionId: String, jobs: [JobView])
    case sessionProjection(sessionId: String, key: String, value: [String: Any])
    case approvalRequested(ApprovalRequest)
    case approvalResolved(sessionId: String, approvalId: String, outcome: String)
    case questionRequested(QuestionRequest)
    case questionResolved(sessionId: String, questionRpcId: String, outcome: String)
    case sessionEvent(sessionId: String, event: [String: Any])
    case streamError(String)

    static func parse(_ d: [String: Any], rpcId: String) -> MuxFrame? {
        guard let type = Wire.string(d, "type") else { return nil }
        switch type {
        case "session/subscribed":
            return .sessionSubscribed(sessionId: Wire.string(d, "sessionId") ?? "", lastSeq: Wire.int(d, "lastSeq") ?? 0)
        case "session/queue":
            let items = (Wire.arr(d, "items") ?? []).compactMap { Wire.dict($0).map(QueueItem.init) }
            return .sessionQueue(sessionId: Wire.string(d, "sessionId") ?? "", items: items)
        case "session/jobs":
            let jobs = (Wire.arr(d, "jobs") ?? []).compactMap { Wire.dict($0).map(JobView.init) }
            return .sessionJobs(sessionId: Wire.string(d, "sessionId") ?? "", jobs: jobs)
        case "session/projection":
            return .sessionProjection(
                sessionId: Wire.string(d, "sessionId") ?? "",
                key: Wire.string(d, "key") ?? "",
                value: Wire.dict(d, "value") ?? [:]
            )
        case "approval/requested":
            return .approvalRequested(ApprovalRequest(rpcId: rpcId, d))
        case "approval/resolved":
            return .approvalResolved(
                sessionId: Wire.string(d, "sessionId") ?? "",
                approvalId: Wire.string(d, "approvalId") ?? "",
                outcome: Wire.string(d, "outcome") ?? "?"
            )
        case "question/requested":
            return .questionRequested(QuestionRequest(rpcId: rpcId, d))
        case "question/resolved":
            return .questionResolved(
                sessionId: Wire.string(d, "sessionId") ?? "",
                questionRpcId: Wire.string(d, "questionRpcId") ?? "",
                outcome: Wire.string(d, "outcome") ?? "?"
            )
        case "session/event":
            return .sessionEvent(
                sessionId: Wire.string(d, "sessionId") ?? "",
                event: Wire.dict(d, "event") ?? [:]
            )
        case "stream/error":
            let err = Wire.dict(d, "error")
            return .streamError(Wire.string(err ?? [:], "message") ?? "stream error")
        default:
            return nil
        }
    }
}

/// Parsed host-stream frames.
enum HostFrame {
    case sessionAdded(sessionId: String, blank: Bool, parentSessionId: String?, cwd: String?)
    case sessionRemoved(sessionId: String)
    case sessionStatus(sessionId: String, running: Bool)
    case agentError(sessionId: String, message: String)
    case workspaceChanged
    case archivedSessionsChanged([String])
    case remoteEvent(event: String, args: [Any])
    case streamError(String)

    static func parse(_ d: [String: Any]) -> HostFrame? {
        guard let type = Wire.string(d, "type") else { return nil }
        switch type {
        case "host/session-added":
            return .sessionAdded(
                sessionId: Wire.string(d, "sessionId") ?? "",
                blank: Wire.bool(d, "blank") ?? true,
                parentSessionId: Wire.string(d, "parentSessionId"),
                cwd: Wire.string(d, "cwd")
            )
        case "host/session-removed":
            return .sessionRemoved(sessionId: Wire.string(d, "sessionId") ?? "")
        case "host/session-status":
            return .sessionStatus(sessionId: Wire.string(d, "sessionId") ?? "", running: Wire.bool(d, "running") ?? false)
        case "host/agent-error":
            return .agentError(sessionId: Wire.string(d, "sessionId") ?? "", message: Wire.string(d, "message") ?? "")
        case "host/workspace-changed", "host/workspace-removed", "host/workspace-order-changed":
            return .workspaceChanged
        case "host/archived-sessions-changed":
            return .archivedSessionsChanged((Wire.arr(d, "archivedSessionIds") ?? []).compactMap { Wire.str($0) })
        case "host/remote-event":
            return .remoteEvent(event: Wire.string(d, "event") ?? "", args: Wire.arr(d, "args") ?? [])
        case "stream/error":
            let err = Wire.dict(d, "error")
            return .streamError(Wire.string(err ?? [:], "message") ?? "stream error")
        default:
            return nil
        }
    }
}
