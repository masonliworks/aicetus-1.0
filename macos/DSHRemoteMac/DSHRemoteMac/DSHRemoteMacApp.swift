//
//  DSHRemoteMacApp.swift
//  DSH Remote Mac 伴侣 — App 入口（重构版：概览仪表盘 + 连接中心 + 设置）
//
//  参考 AirBuddy / Tailscale 等优秀伴侣工具的信息架构：
//  - 侧边栏最小化（3 项），每页单一职责
//  - 概览 = 状态仪表盘（DSH / 桥接 / iOS 连接 + 关键数据）
//  - 连接 = 配对中心（三步指引 + 二维码 + 连接信息）
//  - 设置 = 安装/自启/Token
//

import SwiftUI

@main
struct DSHRemoteMacApp: App {
    @State private var bridge = BridgeService()

    var body: some Scene {
        WindowGroup("掌中鲸伴侣", id: "main") {
            MainWindow()
                .environment(bridge)
                .frame(minWidth: 860, minHeight: 560)
                .onAppear { bridge.start() }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 680)

        Window("配对二维码", id: "pairing") {
            PairingCard()
                .environment(bridge)
                .frame(width: 300)
                .padding(16)
                .background(DSMacColor.backgroundBase)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environment(bridge)
        } label: {
            Image(systemName: bridge.pendingItems.isEmpty
                  ? "antenna.radiowaves.left.and.right"
                  : "antenna.radiowaves.left.and.right.circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - 主窗口

enum MacSection: String, CaseIterable, Identifiable {
    case overview, connect, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "概览"
        case .connect: return "连接"
        case .settings: return "设置"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "rectangle.grid.2x2"
        case .connect: return "qrcode"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindow: View {
    @Environment(BridgeService.self) private var bridge
    @State private var selection: MacSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(MacSection.allCases) { section in
                        Label {
                            HStack {
                                Text(section.title)
                                Spacer()
                                if section == .overview && !bridge.pendingItems.isEmpty {
                                    Text("\(bridge.pendingItems.count)")
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
                }

                Section("HARNESS") {
                    HStack(spacing: 8) {
                        StatusDot(color: dshColor, pulsing: dshRunning)
                        Text("DeepSeek Harness").font(.system(size: 12.5))
                        Spacer()
                        Text(bridge.harnessVersion)
                            .font(DSMacFont.mono())
                            .foregroundStyle(DSMacColor.textTertiary)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
            .safeAreaInset(edge: .bottom) {
                DSMacCard {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            StatusDot(color: bridge.running ? DSMacColor.accent : DSMacColor.statusDanger,
                                      pulsing: bridge.running)
                                .fixedSize()
                            Text(bridge.running ? "桥接服务运行中" : "服务已停止")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize()
                            Spacer(minLength: 4)
                            Text(":\(bridge.port)")
                                .font(DSMacFont.mono())
                                .foregroundStyle(DSMacColor.textTertiary)
                                .fixedSize()
                        }
                        Text("\(bridge.host) · 已运行 \(bridge.uptimeText)")
                            .font(DSMacFont.mono())
                            .foregroundStyle(DSMacColor.textTertiary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(10)
                    .animation(nil, value: bridge.running)                    .padding(10)
                }
                .padding(10)
            }
        } detail: {
            switch selection ?? .overview {
            case .overview: OverviewView()
            case .connect: ConnectView()
            case .settings: MacSettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(DSMacColor.backgroundBase)
    }

    private var dshRunning: Bool {
        if case .running = bridge.dshWeb.status { return true }
        return false
    }

    private var dshColor: Color {
        switch bridge.dshWeb.status {
        case .running: DSMacColor.accent
        case .starting: DSMacColor.statusWaiting
        default: DSMacColor.statusDanger
        }
    }
}

#Preview {
    MainWindow()
        .environment(BridgeService())
        .frame(width: 1000, height: 680)
}
