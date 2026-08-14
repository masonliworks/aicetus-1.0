// BridgeClient.swift — speaks the dsh-remote-bridge HTTP surface:
//   POST /api/<method>   unary RPC (client-request envelope)
//   POST /api/respond    interaction answer (client-response envelope)
//   GET  /api/events     SSE stream (mux + host frames)

import Foundation

@MainActor
final class BridgeClient {
    let baseURL: String
    let token: String

    init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: - Unary RPC

    /// Perform a unary call; returns the server-response value (result.value).
    func call(_ method: String, payload: [String: Any] = [:]) async throws -> Any {
        let request = ClientRequest(
            rpcId: UUID().uuidString,
            method: method,
            payload: .object(payload.mapValues { JSONValue($0) })
        )
        var data: Data
        do {
            data = try JSONEncoder().encode(request)
        } catch {
            throw BridgeError.transport("请求编码失败: \(error.localizedDescription)")
        }
        let response = try await post("/api/\(method)", body: data)
        let envelope = try ServerResponse(response)
        guard envelope.ok else {
            throw BridgeError.transport("\(method) 失败: \(envelope.errorMessage ?? envelope.errorCode ?? "unknown")")
        }
        return envelope.value ?? [:]
    }

    /// Generic typed variant.
    func callValue<T>(_ method: String, payload: [String: Any] = [:], as type: T.Type) async throws -> T
        where T: Decodable
    {
        let value = try await call(method, payload: payload)
        guard let dict = value as? [String: Any] else {
            throw BridgeError.badEnvelope("\(method): unexpected value shape")
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }

    /// POST-poll event frames (reliable across networks where SSE dies).
    /// Returns (frames, latestIdx); each frame is {idx, which, frame}.
    func pollEvents(after: Int) async throws -> (frames: [[String: Any]], latestIdx: Int) {
        let payload: [String: Any] = ["after": after]
        let envelope = try await call("events-poll", payload: payload)
        guard let value = envelope as? [String: Any] else {
            throw BridgeError.badEnvelope("events-poll: unexpected shape")
        }
        let frames = (Wire.arr(value, "frames") ?? []).compactMap { Wire.dict($0) }
        let latestIdx = Wire.int(value, "latestIdx") ?? 0
        return (frames, latestIdx)
    }

    /// Pull session history. No cursor = 尾部页（最新 N 条）;
    /// beforeSeq = 拉取该 seq 之前的更早一页。
    func sessionHistory(sessionId: String, beforeSeq: Int? = nil, maxMessages: Int = 50) async throws -> Any {
        var payload: [String: Any] = ["sessionId": sessionId]
        if let beforeSeq { payload["beforeSeq"] = beforeSeq }
        payload["maxMessages"] = maxMessages
        return try await call("session.history", payload: payload)
    }

    // MARK: - Interaction answers

    /// Answer an approval frame. outcome: "allowed-once" | "rejected".
    @discardableResult
    func respondApproval(rpcId: String, sessionId: String, approvalId: String, outcome: String) async throws -> Bool {
        let value: [String: Any] = [
            "sessionId": sessionId,
            "approvalId": approvalId,
            "outcome": outcome,
        ]
        return try await respond(rpcId: rpcId, value: value)
    }

    /// Answer a question frame. `answers`: [(questionId, [selectedOptionIds])]
    @discardableResult
    func respondQuestion(rpcId: String, sessionId: String, answers: [(id: String, selected: [String])]) async throws -> Bool {
        let answerList: [[String: Any]] = answers.map { ["id": $0.id, "selected": $0.selected] }
        let value: [String: Any] = [
            "sessionId": sessionId,
            "answer": ["answers": answerList],
        ]
        return try await respond(rpcId: rpcId, value: value)
    }

    @discardableResult
    private func respond(rpcId: String, value: [String: Any]) async throws -> Bool {
        let response = ClientResponse(rpcId: rpcId, result: .object([
            "ok": .bool(true),
            "value": .object(value.mapValues { JSONValue($0) }),
        ]))
        let data = try JSONEncoder().encode(response)
        let json = try await post("/api/respond", body: data)
        if Wire.bool(json["accepted"]) == true { return true }
        let reason = Wire.string(json, "reason") ?? "unknown"
        throw BridgeError.transport("应答未接受: \(reason)")
    }

    // MARK: - Transport

    private func post(_ path: String, body: Data) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + path) else {
            throw BridgeError.transport("无效的服务器地址: \(baseURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BridgeError.transport("无响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw BridgeError.http(http.statusCode, text.isEmpty ? "桥接服务错误" : text)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BridgeError.badEnvelope("响应不是 JSON 对象")
        }
        return json
    }

    /// Open the SSE event stream. Frames are delivered to `onFrame` on a
    /// background queue; reconnects with backoff until the task is cancelled.
    func streamEvents(onFrame: @escaping (String, [String: Any]) -> Void) async {
        var attempt = 0
        while !Task.isCancelled {
            do {
                try await openEventStreamOnce(onFrame: onFrame)
            } catch {
                // fall through to reconnect
            }
            if Task.isCancelled { return }
            attempt += 1
            let delay = min(15.0, 1.0 * pow(2.0, Double(min(attempt, 4))))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    /// SSE 专用会话：ephemeral（无缓存、不复用死连接）、不等待网络。
    /// 共享 URLSession 对长 SSE 流存在缓冲/假死问题——iOS 收不到帧但
    /// TCP 仍 ESTABLISHED，正是共享会话连接池的坑。
    private static let sseSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = false
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpAdditionalHeaders = ["Accept": "text/event-stream"]
        return URLSession(configuration: config)
    }()

    private func openEventStreamOnce(onFrame: @escaping (String, [String: Any]) -> Void) async throws {
        guard let url = URL(string: baseURL + "/api/events") else {
            throw BridgeError.transport("无效的服务器地址")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 300
        let (bytes, response) = try await Self.sseSession.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BridgeError.http((response as? HTTPURLResponse)?.statusCode ?? 0, "事件流打开失败")
        }
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
                if !dataBuffer.isEmpty {
                    if let json = try? JSONSerialization.jsonObject(with: Data(dataBuffer.utf8)) as? [String: Any] {
                        onFrame(eventName, json)
                    }
                    dataBuffer = ""
                }
                eventName = "message"
                continue
            }
            if line.hasPrefix(":") {
                continue // comment / heartbeat
            }
        }
    }
}
