//
//  SectionViews.swift
//  DSH Remote Mac 伴侣 — 侧边栏各 section 的占位/骨架视图
//
//  设计稿只画出了概览页全貌，其余 section（会话/设备/日志/设置）
//  这里给出与概览页同语言的骨架，接入真实数据时再展开。
//

import SwiftUI

// MARK: - 会话（只读看管视角）

struct MacSessionsView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        List(bridge.sessions) { session in
            HStack(spacing: 10) {
                StatusDot(color: session.status.color,
                          pulsing: session.status != .idle && session.status != .complete)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title).font(.system(size: 13, weight: .semibold))
                    Text("\(session.workspace) · \(session.detail)")
                        .font(DSMacFont.mono())
                        .foregroundStyle(DSMacColor.textTertiary)
                }
                Spacer()
                StatusPill(text: session.status.label, color: session.status.textColor)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("会话")
    }
}

// MARK: - 设备

struct MacDevicesView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        List(bridge.devices) { device in
            HStack(spacing: 10) {
                Image(systemName: device.name.contains("iPad") ? "ipad" : "iphone")
                    .font(.system(size: 17))
                    .foregroundStyle(DSMacColor.textSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).font(.system(size: 13, weight: .semibold))
                    Text(device.detail)
                        .font(DSMacFont.mono())
                        .foregroundStyle(DSMacColor.textTertiary)
                }
                Spacer()
                StatusPill(text: device.online ? "已连接" : "离线",
                           color: device.online ? DSMacColor.runningText : DSMacColor.textSecondary)
            }
            .padding(.vertical, 4)
            .opacity(device.online ? 1 : 0.55)
        }
        .navigationTitle("设备")
        .toolbar {
            ToolbarItem {
                Button { /* 弹出配对二维码窗口 */ } label: {
                    Label("配对新设备", systemImage: "qrcode")
                }
            }
        }
    }
}

// MARK: - 日志

struct MacLogsView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(bridge.logs) { entry in
                    LogLine(entry: entry)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("日志")
        .toolbar {
            ToolbarItem {
                Button { /* 导出日志 */ } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - 设置（桥接服务相关；对齐 iOS 端 §6.4 分组思路）

struct MacSettingsView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        Form {
            Section("桥接服务") {
                Toggle("启动桥接服务", isOn: Binding(get: { bridge.running },
                                                   set: { _ in bridge.toggleRunning() }))
                LabeledContent("监听地址") {
                    Text("\(bridge.host):\(bridge.port)")
                        .font(DSMacFont.mono())
                        .foregroundStyle(DSMacColor.textSecondary)
                }
                Toggle("局域网自动发现（Bonjour）", isOn: $bridge.lanDiscovery)
            }
            Section("安全") {
                LabeledContent("配对 Token") {
                    Text(bridge.tokenSet ? "已设置" : "未设置")
                        .foregroundStyle(DSMacColor.textSecondary)
                }
                Button("重新生成 Token…") {}
                Button("显示配对二维码…") {}
            }
            Section("Harness") {
                LabeledContent("DeepSeek Harness") {
                    HStack(spacing: 6) {
                        StatusDot(color: DSMacColor.statusRunning)
                        Text(bridge.harnessVersion)
                            .font(DSMacFont.mono())
                            .foregroundStyle(DSMacColor.textSecondary)
                    }
                }
                LabeledContent("今日拦截高危命令") {
                    Text("\(bridge.stats.blockedDanger)")
                        .foregroundStyle(DSMacColor.statusDanger)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }
}

#Preview("设置") {
    MacSettingsView()
        .environmentObject(BridgeService())
        .frame(width: 560, height: 480)
}
