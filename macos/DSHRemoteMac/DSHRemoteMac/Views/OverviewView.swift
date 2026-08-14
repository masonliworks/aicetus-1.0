//
//  OverviewView.swift
//  DSH Remote Mac 伴侣 — 概览（状态仪表盘）
//
//  参考 AirBuddy 仪表盘模式：顶部三张服务状态卡（DSH / 桥接 / iOS 连接），
//  中部关键数据指标，底部待审批与最近日志。
//

import SwiftUI
import AppKit

struct OverviewView: View {
    @Environment(BridgeService.self) private var bridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("概览")
                    .font(DSMacFont.windowTitle)
                    .padding(.top, 4)

                // 三张状态卡
                HStack(alignment: .top, spacing: 12) {
                    harnessCard
                    bridgeCard
                    iosCard
                }

                // 关键数据
                metricsRow

                // 待审批
                if !bridge.pendingItems.isEmpty {
                    pendingSection
                }

                // 最近日志
                logSection
            }
            .padding(20)
        }
        .background(DSMacColor.backgroundBase)
    }

    // MARK: - 状态卡

    private var harnessCard: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("DeepSeek Harness").font(DSMacFont.cardHeader)
                    Spacer(minLength: 0)
                    StatusDot(color: harnessRunning ? DSMacColor.accent : DSMacColor.statusDanger,
                              pulsing: harnessRunning)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(harnessStatusText)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text("版本 \(bridge.harnessVersion)")
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack {
                    if harnessRunning {
                        Button("停止") { bridge.toggleDshWeb() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Button("启动") { bridge.toggleDshWeb() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    Button("Web UI") {
                        NSWorkspace.shared.open(DshWebManager.defaultURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!harnessRunning)
                    .help("在浏览器中打开 DeepSeek Harness Web 界面")
                    Spacer(minLength: 0)
                }
                .frame(height: 22)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var bridgeCard: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("桥接服务").font(DSMacFont.cardHeader)
                    Spacer(minLength: 0)
                    StatusDot(color: bridge.running ? DSMacColor.accent : DSMacColor.statusDanger,
                              pulsing: bridge.running)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(bridge.running ? "运行中" : "已停止")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text("\(bridge.host):\(bridge.port) · 已运行 \(bridge.uptimeText)")
                        .font(DSMacFont.mono())
                        .foregroundStyle(DSMacColor.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack {
                    if bridge.running {
                        Button("停止") { bridge.toggleRunning() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Button("启动") { bridge.toggleRunning() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 22)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var iosCard: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("iPhone 连接").font(DSMacFont.cardHeader)
                    Spacer(minLength: 0)
                    StatusDot(color: bridge.iosConnected ? DSMacColor.accent : DSMacColor.statusDanger,
                              pulsing: bridge.iosConnected)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(bridge.iosConnected ? "已连接" : "等待连接")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if let seen = bridge.iosLastSeenAt {
                        Text("最近活跃 \(seen.formatted(date: .omitted, time: .shortened))")
                            .font(DSMacFont.caption)
                            .foregroundStyle(DSMacColor.textTertiary)
                            .lineLimit(1)
                    } else {
                        Text("扫描「连接」页二维码完成配对")
                            .font(DSMacFont.caption)
                            .foregroundStyle(DSMacColor.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                }
                .frame(height: 22)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - 关键数据

    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricCard(value: "\(bridge.sessions.filter { $0.status == .running }.count)", label: "运行中会话",
                       icon: "bolt.fill", color: DSMacColor.statusRunning)
            metricCard(value: "\(bridge.pendingItems.count)", label: "待审批",
                       icon: "exclamationmark.shield.fill", color: DSMacColor.statusWaiting)
            metricCard(value: "\(bridge.sessions.filter { $0.status == .idle }.count)", label: "空闲会话",
                       icon: "moon.zzz.fill", color: DSMacColor.statusIdle)
        }
    }

    private func metricCard(value: String, label: String, icon: String, color: Color) -> some View {
        DSMacCard {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .frame(height: 24, alignment: .leading)
                    Text(label)
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.textSecondary)
                        .frame(height: 14, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(minHeight: 86)
    }

    // MARK: - 待审批

    private var pendingSection: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader("待审批") {
                    Text("\(bridge.pendingItems.count) 项")
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.textTertiary)
                }
                ForEach(bridge.pendingItems) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.kind == "approval" ? "exclamationmark.shield.fill" : "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(DSMacColor.statusWaiting)
                        Text(item.sessionTitle)
                            .font(.system(size: 12.5, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(item.detail)
                            .font(DSMacFont.caption)
                            .foregroundStyle(DSMacColor.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
                Text("请在 iPhone 端处理这些请求")
                    .font(DSMacFont.caption)
                    .foregroundStyle(DSMacColor.textTertiary)
            }
            .padding(14)
        }
    }

    // MARK: - 日志

    private var logSection: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 6) {
                CardHeader("最近日志")
                let lines = (bridge.bridge.logLines + bridge.dshWeb.lastLog).suffix(8)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(DSMacFont.mono(10))
                        .foregroundStyle(DSMacColor.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if lines.isEmpty {
                    Text("暂无日志")
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.textTertiary)
                }
            }
            .padding(14)
        }
    }

    private var harnessRunning: Bool {
        if case .running = bridge.dshWeb.status { return true }
        return false
    }

    private var harnessColor: Color {
        switch bridge.dshWeb.status {
        case .running: DSMacColor.statusRunning
        case .starting: DSMacColor.statusWaiting
        case .failed: DSMacColor.statusDanger
        default: DSMacColor.statusIdle
        }
    }

    private var harnessStatusText: String {
        switch bridge.dshWeb.status {
        case .running: "运行中"
        case .starting: "启动中…"
        case .stopped: "未运行"
        case .failed: "启动失败"
        default: "检测中…"
        }
    }
}

#Preview {
    OverviewView()
        .environment(BridgeService())
        .frame(width: 800, height: 620)
}
