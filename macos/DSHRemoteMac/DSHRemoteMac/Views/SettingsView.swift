//
//  SettingsView.swift
//  DSH Remote Mac 伴侣 — 设置（安装 / 自启 / 安全）
//

import SwiftUI

struct MacSettingsView: View {
    @Environment(BridgeService.self) private var bridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("设置")
                    .font(DSMacFont.windowTitle)
                    .padding(.top, 4)

                installSection
                autostartSection
                autostartBridgeSection
                securitySection
            }
            .padding(20)
        }
        .background(DSMacColor.backgroundBase)
    }

    // MARK: - DSH 安装

    private var installSection: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader("DeepSeek Harness 安装") {
                    StatusPill(text: installStatusText, color: installStatusColor)
                }
                switch bridge.installer.status {
                case .installed(let version):
                    Text("已安装（版本 \(version)）。DSH 是 DeepSeek 官方 Agent 运行时，会话数据存储于本地。")
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.textSecondary)
                    Button("重新检测") { bridge.installer.detect() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                case .missing:
                    Text("未检测到 DSH。安装后可在「概览」页一键启动 dsh web 服务。")
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.textSecondary)
                    Button("一键安装") {
                        Task { await bridge.installer.install() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                case .installing:
                    ProgressView("正在安装…")
                        .controlSize(.small)
                case .installFailed(let message):
                    Text(message)
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.statusDanger)
                    Button("重试") {
                        Task { await bridge.installer.install() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                case .checking, .unknown:
                    ProgressView("检测中…")
                        .controlSize(.small)
                }
                if !bridge.installer.logLines.isEmpty {
                    let lines = bridge.installer.logLines.suffix(6)
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(DSMacFont.mono(10))
                            .foregroundStyle(DSMacColor.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - 开机自启

    private var autostartSection: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader("开机自启")
                Toggle(isOn: Binding(
                    get: { bridge.dshWeb.autoStartEnabled },
                    set: { on in
                        if on { bridge.dshWeb.enableAutoStart() } else { bridge.dshWeb.disableAutoStart() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("登录时自动运行 dsh web")
                            .font(.system(size: 13, weight: .medium))
                        Text("通过 launchd 后台托管，进程退出自动重启，无需保持任何窗口打开")
                            .font(DSMacFont.caption)
                            .foregroundStyle(DSMacColor.textSecondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(14)
        }
    }

    // MARK: - 启动行为

    private var autostartBridgeSection: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader("启动行为")
                Toggle(isOn: Binding(
                    get: { bridge.autoStartBridge },
                    set: { bridge.autoStartBridge = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("打开 App 时自动开启桥接服务")
                            .font(.system(size: 13, weight: .medium))
                        Text("开启后无需手动点击启动；iPhone 打开 App 即可连接")
                            .font(DSMacFont.caption)
                            .foregroundStyle(DSMacColor.textSecondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(14)
        }
    }

    // MARK: - 安全

    private var securitySection: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader("安全")
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("配对 Token")
                            .font(.system(size: 13, weight: .medium))
                        Text(BridgeManager.resolveToken())
                            .font(DSMacFont.mono())
                            .foregroundStyle(DSMacColor.textTertiary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(BridgeManager.resolveToken(), forType: .string)
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .controlSize(.small)
                }
                Text("桥接服务只转发白名单方法，DSH 的配置与凭据接口不对外暴露；建议仅在可信网络使用。")
                    .font(DSMacFont.caption)
                    .foregroundStyle(DSMacColor.textSecondary)
            }
            .padding(14)
        }
    }

    private var installStatusText: String {
        switch bridge.installer.status {
        case .installed: "已安装"
        case .missing: "未安装"
        case .installing: "安装中"
        case .installFailed: "失败"
        case .checking, .unknown: "检测中"
        }
    }

    private var installStatusColor: Color {
        switch bridge.installer.status {
        case .installed: DSMacColor.runningText
        case .missing, .installFailed: DSMacColor.statusDanger
        case .installing: DSMacColor.waitingText
        default: DSMacColor.textSecondary
        }
    }
}

#Preview {
    MacSettingsView()
        .environment(BridgeService())
        .frame(width: 700, height: 560)
}
