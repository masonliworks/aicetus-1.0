//
//  ContentView.swift / DSHRemoteApp.swift
//  DSH Remote — App 入口与信息架构（规范 §2）
//
//  App
//  ├── 会话 Tab（首页，工作区分栏）
//  └── 设置 Tab
//  顶部常驻全局连接横幅（§6.1）
//

import SwiftUI

@main
struct DSHRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var sessions = SampleData.sessions
    @State private var connected = true

    private var totalPending: Int { sessions.reduce(0) { $0 + $1.pendingApprovals } }

    var body: some View {
        VStack(spacing: 0) {
            ConnectionBanner(connected: connected,
                             runningCount: sessions.filter { $0.status == .running }.count,
                             modelName: "deepseek-v4")
            TabView {
                SessionListView(sessions: sessions)
                    .tabItem { Label("会话", systemImage: "bubble.left.and.bubble.right") }
                    .badge(totalPending)               // §6.2 Tab 角标 = 全局待审批+待回答总数

                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
        }
        .background(DSColor.backgroundBase)
    }
}

#Preview {
    ContentView()
}
