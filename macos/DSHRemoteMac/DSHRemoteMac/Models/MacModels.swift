//
//  MacModels.swift
//  DSH Remote Mac 伴侣 — 数据模型与状态（骨架 stub）
//
//  真实实现中 BridgeService 由桥接进程（WebSocket :7820）驱动，
//  这里用 ObservableObject + 示例数据撑起整个 UI。
//

import Foundation
import SwiftUI

// MARK: - 桥接服务

// MARK: - 设备

struct PairedDevice: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var detail: String          // 例 "iOS 19.2 · 延迟 12ms · 刚刚活跃"
    var online: Bool
}

// MARK: - 会话（Mac 侧是只读看管视角，状态色与 iOS 端 Models.swift 一致）

enum MacSessionStatus {
    case running, waitingApproval, idle, complete

    var color: Color {
        switch self {
        case .running:         return DSMacColor.statusRunning
        case .waitingApproval: return DSMacColor.statusWaiting
        case .idle:            return DSMacColor.statusIdle
        case .complete:        return DSMacColor.accent
        }
    }
    var textColor: Color {
        switch self {
        case .running:         return DSMacColor.runningText
        case .waitingApproval: return DSMacColor.waitingText
        default:               return DSMacColor.textSecondary
        }
    }
    var label: String {
        switch self {
        case .running:         return "运行中"
        case .waitingApproval: return "待审批"
        case .idle:            return "空闲"
        case .complete:        return "已完成"
        }
    }
}

struct MacSession: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var workspace: String       // 例 "harness"
    var detail: String          // 例 "等待 iPhone 审批 npm install"
    var status: MacSessionStatus
    var waitingSince: String? = nil   // 菜单栏用 "2分钟"
}

// MARK: - 日志

struct LogEntry: Identifiable, Hashable {
    enum Level { case info, warning }
    let id = UUID()
    var time: String
    var tag: String             // bridge / harness / push / guard
    var text: String
    var level: Level = .info
}

// MARK: - 统计

struct DailyStats: Hashable {
    var approvals = 14
    var avgResponse = "26s"
    var messageRounds = "1.2k"
    var blockedDanger = 3
}

// MARK: - 示例数据

enum MacSampleData {
    static let devices: [PairedDevice] = [
        PairedDevice(name: "Lifeng 的 iPhone 15 Pro",
                     detail: "iOS 19.2 · 延迟 12ms · 刚刚活跃", online: true),
        PairedDevice(name: "iPad Air",
                     detail: "上次连接 · 3 天前", online: false),
    ]

    static let sessions: [MacSession] = [
        MacSession(title: "重构 auth 模块", workspace: "harness",
                   detail: "等待 iPhone 审批 npm install",
                   status: .waitingApproval, waitingSince: "2分钟"),
        MacSession(title: "给爬虫加代理池", workspace: "wechat-crawler",
                   detail: "正在编辑 proxy_pool.py", status: .running),
    ]

    static let logs: [LogEntry] = [
        LogEntry(time: "12:04:31", tag: "bridge",  text: "iPhone 15 Pro 已连接 (12ms)"),
        LogEntry(time: "12:04:47", tag: "harness", text: "session「重构 auth 模块」请求批准: Bash npm install"),
        LogEntry(time: "12:04:47", tag: "push",    text: "已向 1 台设备推送审批请求"),
        LogEntry(time: "12:05:02", tag: "harness", text: "session「给爬虫加代理池」Edit proxy_pool.py +86 行"),
        LogEntry(time: "12:05:19", tag: "guard",   text: "拦截高危命令 rm -rf ~/（需手机端确认）", level: .warning),
    ]

    static let stats = DailyStats()
}
