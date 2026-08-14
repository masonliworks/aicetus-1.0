// RootView.swift — main tab layout with connection status bar.

import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView {
            SessionsListView(state: state)
                .tabItem { Label("会话", systemImage: "bubble.left.and.bubble.right") }
                .badge(totalPending)

            SettingsView(state: state)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .task {
            // Auto-connect when a saved profile exists.
            if state.config != nil, !state.isConnected {
                state.connect()
            }
        }
    }

    /// Total pending interactions across all sessions (approvals + questions).
    private var totalPending: Int {
        state.approvals.count + state.questions.count
    }
}

struct ConnectionBanner: View {
    let state: AppState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            if state.isConnected, state.dshReachable {
                Text("已连接 · \(state.runningSessions) 个会话运行中" + (state.hostModel.map { " · \($0)" } ?? ""))
            } else if state.isConnected {
                Text("已连接 · DSH 无法访问").foregroundStyle(DSColor.statusDanger)
            } else {
                Text(text)
            }
        }
        .font(DSFont.caption)
        .foregroundStyle(DSColor.textSecondary)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .barMaterial()
    }

    private var color: Color {
        switch state.phase {
        case .connected:
            return state.dshReachable ? DSColor.statusRunning : DSColor.statusDanger
        case .connecting: return DSColor.statusWaiting
        case .disconnected: return DSColor.statusIdle
        case .failed: return DSColor.statusDanger
        }
    }

    private var text: String {
        switch state.phase {
        case .connected: return "已连接"
        case .connecting: return "连接中…"
        case .disconnected: return "未连接"
        case .failed(let message): return "连接失败: \(message)"
        }
    }
}
