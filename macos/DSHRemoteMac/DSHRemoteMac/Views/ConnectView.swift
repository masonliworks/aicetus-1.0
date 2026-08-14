//
//  ConnectView.swift
//  DSH Remote Mac 伴侣 — 连接（配对中心）
//
//  三步指引式配对（参考 AirPods 配对体验）：启动服务 → 扫码 → 自动连接。
//  连接信息可一键复制；网络模式预留广域网。
//

import SwiftUI

struct ConnectView: View {
    @Environment(BridgeService.self) private var bridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("连接")
                    .font(DSMacFont.windowTitle)
                    .padding(.top, 4)

                // 三步指引
                HStack(spacing: 12) {
                    stepCard(number: 1, title: "启动服务",
                             detail: "确认 DSH 与桥接服务已运行",
                             done: bridge.running,
                             action: bridge.running ? nil : "启动",
                             onAction: { bridge.toggleRunning() })
                    stepCard(number: 2, title: "iPhone 扫码",
                             detail: "打开 掌中鲸 → 设置 → 扫码配对",
                             done: bridge.iosConnected,
                             action: nil,
                             onAction: {})
                    stepCard(number: 3, title: "自动连接",
                             detail: "扫码后自动完成配置并连接",
                             done: bridge.iosConnected,
                             action: nil,
                             onAction: {})
                }

                // 二维码 + 连接信息
                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if bridge.running {
                            PairingCard()
                        } else {
                            DSMacCard {
                                VStack(spacing: 8) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 40))
                                        .foregroundStyle(DSMacColor.textTertiary)
                                    Text("启动桥接服务后显示二维码")
                                        .font(DSMacFont.caption)
                                        .foregroundStyle(DSMacColor.textTertiary)
                                    Button("启动桥接服务") { bridge.toggleRunning() }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(14)
                            }
                        }
                    }
                    // 与右列（连接信息 + 网络模式）底部对齐：填满整列高度
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)

                    VStack(spacing: 12) {
                        infoCard
                        networkModeCard
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .background(DSMacColor.backgroundBase)
    }

    // MARK: - 步骤卡

    private func stepCard(number: Int, title: String, detail: String,
                          done: Bool, action: String?, onAction: @escaping () -> Void) -> some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(done ? DSMacColor.statusRunning : DSMacColor.accent.opacity(0.15))
                            .frame(width: 24, height: 24)
                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(number)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DSMacColor.accent)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 24)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(height: 17, alignment: .leading)
                Text(detail)
                    .font(DSMacFont.caption)
                    .foregroundStyle(DSMacColor.textSecondary)
                    .frame(height: 30, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack {
                    if let action, !done {
                        Button(action) { onAction() }
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

    // MARK: - 连接信息

    private var infoCard: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader("连接信息")
                infoRow(label: "局域网地址", value: "\(bridge.host):\(bridge.port)", copyable: true)
                infoRow(label: "配对 Token", value: BridgeManager.resolveToken(), copyable: true)
                infoRow(label: "配对链接", value: bridge.pairingDeepLink, copyable: true)
            }
            .padding(14)
        }
    }

    private func infoRow(label: String, value: String, copyable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(DSMacFont.caption)
                .foregroundStyle(DSMacColor.textSecondary)
            HStack {
                Text(value)
                    .font(DSMacFont.mono())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer()
                if copyable {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(DSMacColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("复制")
                }
            }
            .padding(8)
            .background(DSMacColor.textTertiary.opacity(0.06), in: RoundedRectangle(cornerRadius: DSMacRadius.sm))
        }
    }

    // MARK: - 网络模式

    private var networkModeCard: some View {
        DSMacCard {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader("网络模式")
                HStack(spacing: 10) {
                    modePill(title: "局域网", detail: "同一 WiFi 下直连",
                             icon: "wifi", active: true, enabled: true)
                    modePill(title: "广域网", detail: "随时随地连接（即将推出）",
                             icon: "globe", active: false, enabled: false)
                }
                Text("广域网模式将通过加密中继或自建服务器实现，届时无需与 Mac 同一网络。")
                    .font(DSMacFont.caption)
                    .foregroundStyle(DSMacColor.textTertiary)
            }
            .padding(14)
        }
    }

    private func modePill(title: String, detail: String, icon: String,
                          active: Bool, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(active ? DSMacColor.accent : DSMacColor.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if active {
                        Text("当前")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DSMacColor.statusRunning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(DSMacColor.statusRunning.opacity(0.12), in: Capsule())
                    }
                }
                Text(detail)
                    .font(DSMacFont.caption)
                    .foregroundStyle(DSMacColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(active ? DSMacColor.accent.opacity(0.06) : DSMacColor.textTertiary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: DSMacRadius.md))
        .overlay(RoundedRectangle(cornerRadius: DSMacRadius.md)
            .strokeBorder(active ? DSMacColor.accent.opacity(0.3) : DSMacColor.divider, lineWidth: 1))
        .opacity(enabled ? 1 : 0.55)
    }
}

#Preview {
    ConnectView()
        .environment(BridgeService())
        .frame(width: 800, height: 640)
}
