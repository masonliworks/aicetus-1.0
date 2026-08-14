//
//  BridgeService.swift
//  DSH Remote Mac 伴侣 — 真实服务层（包装 DSH 检测/服务/桥接管理 + 桥接数据轮询）
//
//  UI agent 的 BridgeService stub 在此替换为真实实现：
//   - running / host / port / harnessVersion 来自 BridgeManager / DshInstaller / PairingInfo
//   - sessions 轮询桥接服务（127.0.0.1:port）的 session.list
//   - logs 聚合各服务的运行日志
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class BridgeService {
    // 服务管理器（真实实现）
    let installer = DshInstaller()
    let dshWeb = DshWebManager()
    let bridge = BridgeManager()

    // 配对信息
    var host: String { PairingInfo.lanIP() ?? "127.0.0.1" }
    var port: Int { BridgeManager.defaultPort }

    // 桥接数据（轮询）
    var sessions: [MacSession] = []
    var devices: [PairedDevice] = []
    var logs: [LogEntry] = []
    var stats = DailyStats()

    // iOS 连接状态（healthz telemetry）
    var iosConnected = false
    var iosLastSeenAt: Date?

    // 待审批/待回答条目（桥接事件流）
    var pendingItems: [PendingItem] = []

    struct PendingItem: Identifiable, Hashable {
        let id: String
        var sessionTitle: String
        var kind: String      // approval | question
        var detail: String
        var sessionId: String
    }

    /// 打开 App 时自动开启桥接服务（可在设置页关闭）。
    var autoStartBridge: Bool {
        get { UserDefaults.standard.object(forKey: "autoStartBridge") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoStartBridge")
            if newValue {
                bridge.ensureRunning()
                bridgeStartedAt = Date()
                startPolling()
                startSSE()
            }
        }
    }

    private var pollTask: Task<Void, Never>?
    private var sseTask: Task<Void, Never>?
    private var lastSessionFetch: Date?
    private var sessionTitleCache: [String: String] = [:]

    // MARK: - 派生状态（对齐 UI agent 的接口）

    var running: Bool {
        if case .running = bridge.status { return true }
        return false
    }

    var harnessVersion: String {
        if case .installed(let v) = installer.status { return v }
        return "—"
    }

    var tokenSet: Bool { !BridgeManager.resolveToken().isEmpty }
    var lanDiscovery = true

    var uptimeText: String {
        guard let started = bridgeStartedAt else { return "—" }
        let interval = max(0, Int(Date().timeIntervalSince(started)))
        if interval < 60 { return "<1m" }
        let h = interval / 3600
        let m = (interval % 3600) / 60
        if h > 0 { return "\(h)h\(m)m" }
        return "\(m)m"
    }

    private var bridgeStartedAt: Date?

    var onlineCount: Int { devices.filter(\.online).count }
    var pendingApprovals: [MacSession] { sessions.filter { $0.status == .waitingApproval } }

    var pairingDeepLink: String { "dshremote://pair?host=\(host)&port=\(port)&token=\(BridgeManager.resolveToken())" }

    // MARK: - 生命周期

    func start() {
        installer.detect()
        dshWeb.startMonitoring()
        if autoStartBridge {
            bridge.ensureRunning()
            bridgeStartedAt = Date()
        }
        startPolling()
        startSSE()
    }

    func toggleRunning() {
        switch bridge.status {
        case .stopped, .failed:
            bridge.start()
            bridgeStartedAt = Date()
            startPolling()
        case .running:
            bridge.stop()
            bridgeStartedAt = nil
            stopPolling()
            sseTask?.cancel()
            sseTask = nil
            iosConnected = false
        case .starting:
            bridge.stop()
            stopPolling()
        }
    }

    func toggleDshWeb() {
        switch dshWeb.status {
        case .running:
            dshWeb.stop()
        case .stopped, .failed:
            dshWeb.start()
        default:
            break
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchSessions()
                await self?.fetchHealth()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    /// healthz telemetry: iOS SSE connection state + last activity.
    private func fetchHealth() async {
        let url = URL(string: "http://127.0.0.1:\(port)/healthz")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let telemetry = json["telemetry"] as? [String: Any] else { return }
            let sseClients = telemetry["sseClients"] as? Int ?? 0
            let lastRequestAt = telemetry["lastRequestAt"] as? Double ?? 0
            iosConnected = sseClients > 0
            if lastRequestAt > 0 {
                iosLastSeenAt = Date(timeIntervalSince1970: lastRequestAt / 1000)
            }
        } catch {
            iosConnected = false
        }
    }

    /// Listen to the bridge event stream for approvals/questions.
    private func startSSE() {
        sseTask?.cancel()
        sseTask = Task { [weak self] in
            await self?.sseLoop()
        }
    }

    private func sseLoop() async {
        while !Task.isCancelled {
            do {
                try await openSSEOnce()
            } catch {
                // reconnect below
            }
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    private func openSSEOnce() async throws {
        let token = BridgeManager.resolveToken()
        let url = URL(string: "http://127.0.0.1:\(port)/api/events")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
        var eventName = "message"
        var dataBuffer = ""
        for try await line in bytes.lines {
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("data:") {
                dataBuffer += String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.isEmpty {
                if !dataBuffer.isEmpty, eventName == "mux",
                   let json = try? JSONSerialization.jsonObject(with: Data(dataBuffer.utf8)) as? [String: Any],
                   let payload = json["payload"] as? [String: Any] {
                    handleMuxFrame(payload)
                }
                dataBuffer = ""
                eventName = "message"
                continue
            }
            if line.hasPrefix(":") { continue }
        }
    }

    private func handleMuxFrame(_ payload: [String: Any]) {
        guard let type = payload["type"] as? String else { return }
        switch type {
        case "approval/requested":
            let sessionId = payload["sessionId"] as? String ?? ""
            let id = payload["approvalId"] as? String ?? UUID().uuidString
            let tool = payload["toolName"] as? String ?? "工具"
            let reason = payload["reason"] as? String ?? ""
            if !pendingItems.contains(where: { $0.id == id }) {
                pendingItems.append(PendingItem(id: id, sessionTitle: titleFor(sessionId),
                                                kind: "approval", detail: "\(tool): \(reason)", sessionId: sessionId))
            }
        case "approval/resolved":
            let approvalId = payload["approvalId"] as? String ?? ""
            pendingItems.removeAll { $0.id == approvalId }
        case "question/requested":
            let sessionId = payload["sessionId"] as? String ?? ""
            let id = payload["questionRpcId"] as? String ?? UUID().uuidString
            let questions = payload["questions"] as? [[String: Any]] ?? []
            let text = questions.first?["question"] as? String ?? "提问"
            if !pendingItems.contains(where: { $0.id == id }) {
                pendingItems.append(PendingItem(id: id, sessionTitle: titleFor(sessionId),
                                                kind: "question", detail: text, sessionId: sessionId))
            }
        case "question/resolved":
            let qid = payload["questionRpcId"] as? String ?? ""
            pendingItems.removeAll { $0.id == qid }
        default:
            break
        }
    }

    private func titleFor(_ sessionId: String) -> String {
        if let cached = sessionTitleCache[sessionId] { return cached }
        if let session = sessions.first(where: { $0.id == sessionId }) {
            sessionTitleCache[sessionId] = session.title
            return session.title
        }
        return String(sessionId.prefix(12))
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - 数据抓取（经本机桥接服务）

    private func fetchSessions() async {
        guard running else {
            sessions = []
            return
        }
        let token = BridgeManager.resolveToken()
        let url = URL(string: "http://127.0.0.1:\(port)/api/session.list")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["type": "client-request", "rpcId": UUID().uuidString, "method": "session.list", "payload": [:]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let value = result["value"] as? [String: Any],
                  let items = value["items"] as? [[String: Any]] else { return }
            let mapped = items.compactMap { MacSession(raw: $0) }
            if mapped != sessions {
                sessions = mapped
            }
        } catch {
            // 桥接未就绪时静默
        }
    }
}

// MARK: - MacSession 从真实 session.list 行构造

extension MacSession {
    init?(raw: [String: Any]) {
        guard let sessionId = raw["sessionId"] as? String else { return nil }
        self.id = sessionId
        let values = (raw["projections"] as? [String: Any])?["values"] as? [String: Any]
        self.title = values?["title"] as? String ?? String(sessionId.prefix(12))
        self.workspace = (raw["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—"
        self.detail = (raw["running"] as? Bool) == true ? "运行中" : "空闲"
        self.status = (raw["running"] as? Bool) == true ? .running : .idle
        self.waitingSince = nil
    }
}
