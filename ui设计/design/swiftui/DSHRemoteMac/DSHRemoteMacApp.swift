//
//  DSHRemoteMacApp.swift
//  DSH Remote Mac 伴侣 — App 入口与主窗口
//
//  结构（对应 dsh-remote-mac.html）：
//  - WindowGroup "main"：NavigationSplitView 主窗口
//    侧边栏：概览 / 会话(徽标) / 设备 / 日志 / 设置 + HARNESS 分组 + 服务状态脚卡
//  - Window "pairing"：独立配对二维码窗口（菜单栏可唤起）
//  - MenuBarExtra：菜单栏常驻下拉
//

import SwiftUI

@main
struct DSHRemoteMacApp: App {
    @StateObject private var bridge = BridgeService()

    var body: some Scene {
        WindowGroup("DSH Remote 伴侣", id: "main") {
            MainWindow()
                .environmentObject(bridge)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1060, height: 720)

        Window("配对二维码", id: "pairing") {
            PairingCard()
                .environmentObject(bridge)
                .frame(width: 300)
                .padding(16)
                .background(DSMacColor.backgroundBase)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(bridge)
        } label: {
            // 有待审批时图标加角标提示（真实实现可换 warning 图标）
            Image(systemName: bridge.pendingApprovals.isEmpty
                  ? "antenna.radiowaves.left.and.right"
                  : "antenna.radiowaves.left.and.right.circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - 主窗口

enum MacSection: String, CaseIterable, Identifiable {
    case overview, sessions, devices, logs, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "概览"
        case .sessions: return "会话"
        case .devices:  return "设备"
        case .logs:     return "日志"
        case .settings: return "设置"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "rectangle.grid.2x2"
        case .sessions: return "bubble.left.and.bubble.right"
        case .devices:  return "iphone"
        case .logs:     return "terminal"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindow: View {
    @EnvironmentObject var bridge: BridgeService
    @State private var selection: MacSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(MacSection.allCases) { section in
                    Label {
                        HStack {
                            Text(section.title)
                            Spacer()
                            // 会话待审批徽标（对应设计稿侧边栏红色 1）
                            if section == .sessions && !bridge.pendingApprovals.isEmpty {
                                Text("\(bridge.pendingApprovals.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 1)
                                    .background(DSMacColor.statusDanger)
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: section.icon)
                            .foregroundStyle(DSMacColor.accent)
                    }
                    .tag(section)
                }

                Section("HARNESS") {
                    HStack(spacing: 8) {
                        StatusDot(color: DSMacColor.statusRunning)
                        Text("DeepSeek Harness").font(.system(size: 12.5))
                        Spacer()
                        Text(bridge.harnessVersion)
                            .font(DSMacFont.mono())
                            .foregroundStyle(DSMacColor.textTertiary)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .safeAreaInset(edge: .bottom) {
                // 侧边栏脚卡：服务状态（对应设计稿 .sfoot）
                DSMacCard {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            StatusDot(color: bridge.running ? DSMacColor.statusRunning : DSMacColor.statusIdle,
                                      pulsing: bridge.running)
                            Text(bridge.running ? "桥接服务运行中" : "服务已停止")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(":\(bridge.port)")
                                .font(DSMacFont.mono())
                                .foregroundStyle(DSMacColor.textTertiary)
                        }
                        Text("\(bridge.host) · 已运行 \(bridge.uptimeText)")
                            .font(DSMacFont.mono())
                            .foregroundStyle(DSMacColor.textTertiary)
                    }
                    .padding(10)
                }
                .padding(10)
            }
        } detail: {
            switch selection ?? .overview {
            case .overview: OverviewView()
            case .sessions: MacSessionsView()
            case .devices:  MacDevicesView()
            case .logs:     MacLogsView()
            case .settings: MacSettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    MainWindow()
        .environmentObject(BridgeService())
        .frame(width: 1060, height: 720)
}
