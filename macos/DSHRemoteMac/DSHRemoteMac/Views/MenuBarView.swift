//
//  MenuBarView.swift
//  DSH Remote Mac 伴侣 — 菜单栏下拉
//
//  对应设计稿 .mpop：状态头部 / 待审批直接露出 / 快捷操作 / 版本+退出
//  由 DSHRemoteMacApp 的 MenuBarExtra 承载。
//

import SwiftUI

struct MenuBarView: View {
    @Environment(BridgeService.self) private var bridge: BridgeService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // 状态头部
            HStack(alignment: .top, spacing: 8) {
                StatusDot(color: bridge.running ? DSMacColor.statusRunning : DSMacColor.statusIdle,
                          pulsing: bridge.running)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bridge.running
                         ? "服务运行中 · \(bridge.onlineCount) 台设备在线"
                         : "服务已停止")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(bridge.host):\(bridge.port)")
                        .font(DSMacFont.mono())
                        .foregroundStyle(DSMacColor.textSecondary)
                }
                Spacer()
            }
            .padding(10)

            Divider().opacity(0.5)

            // 待审批（直接露出，不打断也能感知）
            if !bridge.pendingItems.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("待审批")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DSMacColor.textTertiary)
                    ForEach(bridge.pendingItems) { item in
                        Button {
                            openWindow(id: "main")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.kind == "approval" ? "shield.fill" : "questionmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DSMacColor.statusWaiting)
                                Text("\(item.sessionTitle) · \(item.detail)")
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                Divider().opacity(0.5)
            }

            // 快捷操作
            VStack(spacing: 0) {
                menuItem("打开主窗口", systemImage: "rectangle.grid.2x2") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                menuItem("显示配对二维码", systemImage: "qrcode") {
                    openWindow(id: "pairing")
                    NSApp.activate(ignoringOtherApps: true)
                }
                menuItem(bridge.running ? "停止服务" : "启动服务",
                         systemImage: bridge.running ? "stop.square" : "play.square") {
                    bridge.toggleRunning()
                }
            }
            .padding(.vertical, 4)

            Divider().opacity(0.5)

            // 版本 + 退出
            HStack {
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")")
                    .font(DSMacFont.mono())
                    .foregroundStyle(DSMacColor.textTertiary)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(DSMacColor.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 296)
    }

    private func menuItem(_ title: String, systemImage: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title).font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuBarView()
        .environment(BridgeService())
        .padding()
}
