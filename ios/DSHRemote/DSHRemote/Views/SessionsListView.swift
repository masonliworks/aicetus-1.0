//
//  SessionsListView.swift
//  DSH Remote — 会话列表（UI agent 设计 §6.2：工作区分栏 + 左滑管理）
//

import SwiftUI

/// One workspace section in the session list.
struct SessionGroup: Identifiable {
    let workspace: WorkspaceInfo?
    let sessions: [SessionInfo]
    var id: String { workspace?.id ?? "orphan" }
}

struct SessionsListView: View {
    @Bindable var state: AppState
    @State private var errorMessage: String?
    @State private var path: [SessionInfo] = []
    @State private var showCreatePanel = false
    @State private var renamingSession: SessionInfo?
    @State private var renameTitle = ""
    @State private var busy = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !state.sessions.contains(where: { !state.archivedSessionIds.contains($0.sessionId) && !$0.isSubagent }) {
                    ContentUnavailableView(
                        "没有会话",
                        systemImage: "bubble.left",
                        description: Text("点击右上角 + 新建会话，或确认 Mac 上的 DSH 正在运行")
                    )
                } else {
                    List {
                        ForEach(groupedSessions) { group in
                            Section {
                                ForEach(group.sessions) { session in
                                    NavigationLink(value: session) {
                                        SessionRow(
                                            session: session,
                                            pendingCount: pendingCount(for: session.sessionId)
                                        )
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            archive(session)
                                        } label: {
                                            Label("归档", systemImage: "archivebox")
                                        }
                                        Button {
                                            fork(session)
                                        } label: {
                                            Label("分叉", systemImage: "arrow.triangle.branch")
                                        }
                                        .tint(.blue)
                                        Button {
                                            beginRename(session)
                                        } label: {
                                            Label("重命名", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                }
                            } header: {
                                if let ws = group.workspace {
                                    HStack(spacing: 5) {
                                        Image(systemName: "folder")
                                            .font(.caption)
                                        Text(ws.displayTitle)
                                            .font(DSFont.caption.weight(.semibold))
                                            .foregroundStyle(DSColor.textSecondary)
                                        if !ws.path.isEmpty {
                                            Text(ws.path)
                                                .font(DSFont.caption2)
                                                .foregroundStyle(DSColor.textTertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DSColor.backgroundBase)
                }
            }
            .navigationTitle("会话")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SessionInfo.self) { session in
                ChatView(state: state, session: session)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            async let w: Void = state.loadWorkspaces()
                            async let p: Void = state.loadPresets()
                            _ = await (w, p)
                            showCreatePanel = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!state.isConnected)
                }
            }
            .refreshable {
                await state.refresh()
            }
            .sheet(isPresented: $showCreatePanel) {
                CreateSessionSheet(state: state)
            }
            .alert("重命名会话", isPresented: Binding(
                get: { renamingSession != nil },
                set: { if !$0 { renamingSession = nil } }
            )) {
                TextField("会话标题", text: $renameTitle)
                Button("保存") {
                    if let session = renamingSession {
                        rename(session)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("输入新的会话标题")
            }
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onChange(of: state.selectedSessionId) { _, newValue in
            guard let sessionId = newValue,
                  let session = state.sessions.first(where: { $0.sessionId == sessionId }) else { return }
            state.selectedSessionId = nil
            path = [session]
        }
    }

    private func pendingCount(for sessionId: String) -> Int {
        state.approvals.filter { $0.sessionId == sessionId }.count
            + state.questions.filter { $0.sessionId == sessionId }.count
    }

    private var groupedSessions: [SessionGroup] {
        var byWorkspace: [String?: [SessionInfo]] = [:]
        for session in state.sessions
            where !state.archivedSessionIds.contains(session.sessionId) && !session.isSubagent {
            byWorkspace[session.workspaceId, default: []].append(session)
        }
        var groups: [SessionGroup] = []
        for ws in state.workspaces {
            if let items = byWorkspace[ws.id], !items.isEmpty {
                groups.append(SessionGroup(workspace: ws, sessions: items))
            }
        }
        if let orphan = byWorkspace[nil], !orphan.isEmpty {
            groups.append(SessionGroup(workspace: nil, sessions: orphan))
        }
        return groups
    }

    private func beginRename(_ session: SessionInfo) {
        renameTitle = session.displayTitle
        renamingSession = session
    }

    private func rename(_ session: SessionInfo) {
        busy = true
        Task {
            defer { busy = false }
            do {
                try await state.renameSession(sessionId: session.sessionId, title: renameTitle)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func fork(_ session: SessionInfo) {
        busy = true
        Task {
            defer { busy = false }
            do {
                try await state.forkSession(sessionId: session.sessionId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func archive(_ session: SessionInfo) {
        busy = true
        Task {
            defer { busy = false }
            do {
                try await state.archiveSession(sessionId: session.sessionId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - 新建会话面板（工作区 + 预设）

struct CreateSessionSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var workspaceId: String?
    @State private var presetId: String?
    @State private var creating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("工作区") {
                    if state.workspaces.isEmpty {
                        Text("没有工作区，将创建在默认位置")
                            .foregroundStyle(DSColor.textSecondary)
                    } else {
                        Picker("工作区", selection: $workspaceId) {
                            Text("默认").tag(String?.none)
                            ForEach(state.workspaces) { ws in
                                Text(ws.displayTitle).tag(Optional(ws.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("Agent 预设") {
                    Picker("预设", selection: $presetId) {
                        ForEach(state.presets) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }
                    .pickerStyle(.menu)
                    if let preset = state.presets.first(where: { $0.id == presetId }) {
                        Text(preset.description)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
            .navigationTitle("新建会话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        create()
                    } label: {
                        if creating {
                            ProgressView()
                        } else {
                            Text("创建")
                        }
                    }
                    .disabled(creating)
                }
            }
            .onAppear {
                if presetId == nil {
                    presetId = state.presets.first(where: \.isDefault)?.id ?? state.presets.first?.id
                }
            }
            .alert("创建失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func create() {
        creating = true
        Task {
            defer { creating = false }
            do {
                _ = try await state.createSession(workspaceId: workspaceId, agentPreset: presetId)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
