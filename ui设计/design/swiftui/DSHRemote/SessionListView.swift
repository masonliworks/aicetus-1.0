//
//  SessionListView.swift
//  DSH Remote — 会话列表（首页，规范 §6.2 + §5.2 工作区分栏）
//

import SwiftUI

struct SessionListView: View {
    let sessions: [Session]
    @State private var showNewSession = false
    @State private var didPullRefresh = false

    /// 按工作区分组；未归类的放最后（§5.2）
    private var groups: [(Workspace?, [Session])] {
        var order: [Workspace?] = []
        var map: [Workspace?: [Session]] = [:]
        for s in sessions {
            if map[s.workspace] == nil { order.append(s.workspace) }
            map[s.workspace, default: []].append(s)
        }
        order.sort { ($0 == nil) ? false : ($1 == nil) }
        return order.map { ($0, map[$0] ?? []) }
    }

    private var totalPending: Int { sessions.reduce(0) { $0 + $1.pendingApprovals } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groups, id: \.0) { workspace, items in
                        Section {
                            ForEach(items) { session in
                                NavigationLink(value: session) {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {   // §5.3 左滑三操作
                                    Button(role: .destructive) { } label: {
                                        Label("归档", systemImage: "archivebox")
                                    }
                                    Button { } label: { Label("分叉", systemImage: "arrow.branch") }
                                        .tint(DSColor.accent)
                                    Button { } label: { Label("重命名", systemImage: "pencil") }
                                        .tint(DSColor.statusWaiting)
                                }
                            }
                        } header: {
                            if let workspace {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                    Text(workspace.name).font(DSFont.caption.weight(.semibold))
                                    Text(workspace.path)
                                        .font(DSFont.mono(11))
                                        .foregroundStyle(DSColor.textTertiary)
                                        .lineLimit(1)
                                }
                                .padding(.top, DSSpace.s2)
                            }
                        }
                    }

                    if sessions.isEmpty {
                        ContentUnavailableView("暂无会话",
                                               systemImage: "bubble.left.and.bubble.right",
                                               description: Text("点右上角 + 新建一个会话"))
                    }
                }
                .padding(.horizontal, DSSpace.page)
            }
            .background(DSColor.backgroundBase)
            .refreshable { await reload() }          // 下拉刷新（另有 5s 自动刷新，接入层实现）
            .navigationTitle("会话")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewSession = true } label: { Image(systemName: "plus") }
                        .tint(DSColor.accent)
                }
            }
            .navigationDestination(for: Session.self) { session in
                SessionDetailView(session: session)
            }
            .sheet(isPresented: $showNewSession) {
                NewSessionSheet(workspaces: [SampleData.harness, SampleData.crawler])
            }
        }
    }

    private func reload() async {
        // TODO: 拉取桥接服务会话列表
    }
}

#Preview {
    SessionListView(sessions: SampleData.sessions)
}
