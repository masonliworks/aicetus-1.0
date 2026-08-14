//
//  Models.swift
//  DSH Remote — 数据模型（骨架 stub，真实数据来自桥接服务 WebSocket）
//

import Foundation
import SwiftUI

// MARK: - 会话状态（§4.1 语义色映射）

enum SessionStatus {
    case running, idle, waitingApproval, complete, failed

    var color: Color {
        switch self {
        case .running:         return DSColor.statusRunning
        case .idle:            return DSColor.statusIdle
        case .waitingApproval: return DSColor.statusWaiting
        case .complete:        return DSColor.statusComplete
        case .failed:          return DSColor.statusDanger
        }
    }
    var label: String {
        switch self {
        case .running:         return "运行中"
        case .idle:            return "空闲"
        case .waitingApproval: return "待审批"
        case .complete:        return "已完成"
        case .failed:          return "失败"
        }
    }
}

struct Workspace: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var path: String
}

struct Session: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var workspace: Workspace?
    var preset: String
    var status: SessionStatus
    var pendingApprovals: Int = 0
    var goalSummary: String? = nil
    var lastActiveText: String = "刚刚"
}

// MARK: - 消息与会话详情组件数据

struct ToolCall: Identifiable, Hashable {
    enum State { case running, done, failed }
    let id = UUID()
    var name: String
    var summary: String
    var paramsJSON: String
    var result: String
    var state: State
}

struct Message: Identifiable, Hashable {
    enum Role { case user, agent }
    let id = UUID()
    var role: Role
    var text: String
    var reasoning: String? = nil
    var toolCalls: [ToolCall] = []
}

struct QueueItem: Identifiable, Hashable {
    enum State { case queued, steering }
    let id = UUID()
    var text: String
    var state: State
}

struct Job: Identifiable, Hashable {
    enum State { case todo, doing, done }
    let id = UUID()
    var name: String
    var state: State
}

struct ApprovalRequest: Identifiable, Hashable {
    let id = UUID()
    var toolName: String
    var reason: String
}

// MARK: - 示例数据（预览与骨架联调用）

enum SampleData {
    static let harness = Workspace(name: "harness", path: "~/Projects/harness")
    static let crawler = Workspace(name: "wechat-crawler", path: "~/Projects/wechat-crawler")

    static let sessions: [Session] = [
        Session(title: "重构 auth 模块", workspace: harness, preset: "code-reviewer",
                status: .waitingApproval, pendingApprovals: 1,
                goalSummary: "完成 session 服务抽离并通过测试", lastActiveText: "2分钟前"),
        Session(title: "修复 CI 流水线", workspace: harness, preset: "default",
                status: .running, lastActiveText: "18分钟前"),
        Session(title: "给爬虫加代理池", workspace: crawler, preset: "default",
                status: .running, pendingApprovals: 2,
                goalSummary: "支持按地区轮换出口 IP", lastActiveText: "5分钟前"),
        Session(title: "整理周报素材", workspace: nil, preset: "writer",
                status: .idle, lastActiveText: "1小时前"),
    ]

    static let messages: [Message] = [
        Message(role: .user, text: "把 session 管理抽成独立服务，别动 .env"),
        Message(role: .agent,
                text: "方案：新建 SessionService，jwt 升到 v9。需要重装依赖。",
                reasoning: "先盘点 jwt 引用面，再评估 v8→v9 的破坏性变更……",
                toolCalls: [
                    ToolCall(name: "Bash", summary: "找到 14 处引用，集中在 session.ts",
                             paramsJSON: #"{"cmd":"grep -rn jwt src/auth/"}"#,
                             result: "14 matches", state: .done),
                    ToolCall(name: "Read", summary: "src/auth/session.ts",
                             paramsJSON: #"{"path":"src/auth/session.ts"}"#,
                             result: "export class SessionManager …", state: .done),
                ]),
    ]

    static let queue: [QueueItem] = [
        QueueItem(text: "顺便把登录页的报错提示也统一成 toast", state: .queued),
    ]

    static let jobs: [Job] = [
        Job(name: "抽取 SessionService", state: .doing),
        Job(name: "升级 jsonwebtoken v9", state: .done),
        Job(name: "补充单测", state: .todo),
    ]

    static let approval = ApprovalRequest(
        toolName: "Bash",
        reason: "需要执行 npm install 以升级 jsonwebtoken 到 v9（工作目录 ~/Projects/harness）")
}
