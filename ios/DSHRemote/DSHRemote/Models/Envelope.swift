// Envelope.swift — DSH wire protocol envelopes (verified against
// @deepseek-ai/dsh-client-connection 0.1.0-rc.6).
//
//   client-request  {type, rpcId, method, payload}           (we send)
//   server-response {type, rpcId, result:{ok,value|error}}   (we receive)
//   client-response {type, rpcId, result}                    (we send to /api/respond)
//   server-request  {type, rpcId, method, payload}           (event-stream frames; rpcId
//                                                             must be echoed when answering)

import Foundation

/// Convenience JSON helpers used across the wire layer. All accept optional
/// values so callers can pass through `Any?` slots without unwrapping.
enum Wire {
    static func dict(_ json: Any?) -> [String: Any]? { json as? [String: Any] }
    static func arr(_ json: Any?) -> [Any]? { json as? [Any] }
    static func str(_ json: Any?) -> String? { json as? String }
    static func num(_ json: Any?) -> Double? { (json as? NSNumber)?.doubleValue }
    static func bool(_ json: Any?) -> Bool? { (json as? NSNumber)?.boolValue }

    static func string(_ d: [String: Any]?, _ key: String) -> String? { d?[key] as? String }
    static func int(_ d: [String: Any]?, _ key: String) -> Int? { (d?[key] as? NSNumber)?.intValue }
    static func bool(_ d: [String: Any]?, _ key: String) -> Bool? { (d?[key] as? NSNumber)?.boolValue }
    static func dict(_ d: [String: Any]?, _ key: String) -> [String: Any]? { d?[key] as? [String: Any] }
    static func arr(_ d: [String: Any]?, _ key: String) -> [Any]? { d?[key] as? [Any] }
}

/// A client-request envelope we send to the bridge.
struct ClientRequest: Encodable {
    let type = "client-request"
    let rpcId: String
    let method: String
    let payload: JSONValue
}

/// A client-response envelope sent to /api/respond. `rpcId` must be the rpcId
/// of the server-request frame being answered.
struct ClientResponse: Encodable {
    let type = "client-response"
    let rpcId: String
    let result: JSONValue
}

/// A server-response envelope received from the bridge.
struct ServerResponse {
    let rpcId: String
    let ok: Bool
    /// result.value when ok
    let value: Any?
    /// result.error when !ok
    let errorCode: String?
    let errorMessage: String?

    init(_ json: [String: Any]) throws {
        guard let rpcId = Wire.string(json, "rpcId"),
              let result = Wire.dict(json, "result") else {
            throw BridgeError.badEnvelope("missing rpcId/result")
        }
        self.rpcId = rpcId
        if Wire.bool(result, "ok") == true {
            self.ok = true
            self.value = result["value"]
            self.errorCode = nil
            self.errorMessage = nil
        } else {
            self.ok = false
            self.value = nil
            let error = Wire.dict(result, "error")
            self.errorCode = Wire.string(error ?? [:], "code")
            self.errorMessage = Wire.string(error ?? [:], "message")
        }
    }
}

/// JSON value wrapper for request payloads.
enum JSONValue: Encodable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(_ any: Any) {
        switch any {
        case let d as [String: Any]: self = .object(d.mapValues { JSONValue($0) })
        case let a as [Any]: self = .array(a.map { JSONValue($0) })
        case let s as String: self = .string(s)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                self = .bool(n.boolValue)
            } else {
                self = .number(n.doubleValue)
            }
        case is NSNull: self = .null
        default: self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let d): try c.encode(d)
        case .array(let a): try c.encode(a)
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        }
    }
}

enum BridgeError: LocalizedError {
    case badEnvelope(String)
    case http(Int, String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .badEnvelope(let s): return "响应格式错误: \(s)"
        case .http(let code, let s): return "HTTP \(code): \(s)"
        case .transport(let s): return s
        }
    }
}
