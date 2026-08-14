//
//  OverviewView.swift
//  DSH Remote Mac 伴侣 — 概览页
//
//  对应 dsh-remote-mac.html 主窗口右侧：
//  配对卡 + 服务状态卡 + 已连接设备 + 活跃会话 + 统计 + 最近日志
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("概览")
                    .font(DSMacFont.windowTitle)

                // 状态 + 配对
                HStack(alignment: .top, spacing: 14) {
                    PairingCard()
                        .frame(width: 280)

                    VStack(spacing: 14) {
                        serviceCard
                        devicesCard
                        activeSessionsCard
                    }
                    .frame(maxWidth: .infinity)
                }

                statsRow
                recentLogsCard
            }
            .padding(24)
        }
        .background(DSMacColor.backgroundBase)
    }

    // MARK: 服务状态卡

    private var serviceCard: some View {
        DSMacCard {
            HStack(spacing: 10) {
                StatusDot(color: bridge.running ? DSMacColor.statusRunning : DSMacColor.statusIdle,
                          pulsing: bridge.running)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bridge.running ? "桥接服务运行中" : "桥接服务已停止")
                        .font(.system(size: 14, weight: .semibold))
                    Text("ws://\(bridge.host):\(bridge.port) · Token \(bridge.tokenSet ? "已设置" : "未设置") · 局域网发现\(bridge.lanDiscovery ? "已开启" : "已关闭")")
                        .font(DSMacFont.mono())
                        .foregroundStyle(DSMacColor.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { bridge.running },
                                         set: { _ in bridge.toggleRunning() }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(13)
        }
    }

    // MARK: 已连接设备

    private var devicesCard: some View {
        DSMacCard {
            VStack(spacing: 0) {
                CardHeader("已连接设备")
                VStack(spacing: 0) {
                    ForEach(bridge.devices) { device in
                        deviceRow(device)
                            .opacity(device.online ? 1 : 0.55)
                        if device.id != bridge.devices.last?.id {
                            Divider().opacity(0.5).padding(.leading, 14)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func deviceRow(_ device: PairedDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: device.name.contains("iPad") ? "ipad" : "iphone")
                .font(.system(size: 17))
                .foregroundStyle(DSMacColor.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 13, weight: device.online ? .semibold : .medium))
                Text(device.detail)
                    .font(DSMacFont.mono())
                    .foregroundStyle(DSMacColor.textTertiary)
            }
            Spacer()
            StatusPill(text: device.online ? "已连接" : "离线",
                       color: device.online ? DSMacColor.runningText : DSMacColor.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: 活跃会话

    private var activeSessionsCard: some View {
        DSMacCard {
            VStack(spacing: 0) {
                CardHeader("活跃会话") {
                    if !bridge.pendingApprovals.isEmpty {
                        StatusPill(text: "\(bridge.pendingApprovals.count) 个待审批",
                                   color: DSMacColor.waitingText)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(bridge.sessions) { session in
                        sessionRow(session)
                        if session.id != bridge.sessions.last?.id {
                            Divider().opacity(0.5).padding(.leading, 14)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func sessionRow(_ session: MacSession) -> some View {
        HStack(spacing: 10) {
            StatusDot(color: session.status.color,
                      pulsing: session.status == .running || session.status == .waitingApproval)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(session.workspace) · \(session.detail)")
                    .font(DSMacFont.mono())
                    .foregroundStyle(DSMacColor.textTertiary)
            }
            Spacer()
            StatusPill(text: session.status.label, color: session.status.textColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: 统计

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell("今日审批", "\(bridge.stats.approvals)")
            statCell("平均响应", bridge.stats.avgResponse)
            statCell("消息往返", bridge.stats.messageRounds)
            statCell("拦截高危命令", "\(bridge.stats.blockedDanger)", valueColor: DSMacColor.statusDanger)
        }
    }

    private func statCell(_ label: String, _ value: String,
                          valueColor: Color = DSMacColor.textPrimary) -> some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DSMacFont.caption)
                    .foregroundStyle(DSMacColor.textSecondary)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(valueColor)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 最近日志

    private var recentLogsCard: some View {
        DSMacCard {
            VStack(spacing: 0) {
                CardHeader("最近日志") {
                    Text("查看全部")
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(bridge.logs.prefix(5)) { entry in
                        LogLine(entry: entry)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// 单行日志（概览与日志页共用）
struct LogLine: View {
    let entry: LogEntry
    var body: some View {
        (Text("\(entry.time)  ")
            .foregroundStyle(DSMacColor.textTertiary)
        + Text("[\(entry.tag)] ")
            .foregroundStyle(DSMacColor.textSecondary)
        + Text(entry.text)
            .foregroundStyle(entry.level == .warning
                             ? DSMacColor.statusWaiting
                             : DSMacColor.textSecondary))
            .font(DSMacFont.mono())
            .lineSpacing(3)
            .textSelection(.enabled)
    }
}

#Preview {
    OverviewView()
        .environmentObject(BridgeService())
        .frame(width: 840, height: 680)
}
