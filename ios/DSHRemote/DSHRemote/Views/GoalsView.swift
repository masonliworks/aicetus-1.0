// GoalsView.swift — 创建目标表单（会话内入口用）

import SwiftUI

struct GoalCreateSheet: View {
    @Bindable var state: AppState
    /// When set (created from inside a session), the picker is hidden and this
    /// session is used directly.
    var fixedSessionId: String?
    @Environment(\.dismiss) private var dismiss
    @State private var sessionId: String?
    @State private var objective = ""
    @State private var maxRounds = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    private var effectiveSessionId: String? {
        fixedSessionId ?? sessionId
    }

    var body: some View {
        NavigationStack {
            Form {
                if fixedSessionId == nil {
                    Section("目标会话") {
                        Picker("会话", selection: $sessionId) {
                            ForEach(state.sessions) { session in
                                Text(session.displayTitle).tag(Optional(session.sessionId))
                            }
                        }
                    }
                }
                Section("目标内容") {
                    TextEditor(text: $objective)
                        .frame(minHeight: 100)
                }
                Section("轮次上限（可选）") {
                    TextField(text: $maxRounds) {
                        Text("如 12")
                    }
                    .keyboardType(.numberPad)
                }
            }
            .navigationTitle("创建目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if submitting {
                            ProgressView()
                        } else {
                            Text("创建")
                        }
                    }
                    .disabled(submitting || objective.trimmingCharacters(in: .whitespaces).isEmpty || effectiveSessionId == nil)
                }
            }
            .onAppear {
                if sessionId == nil { sessionId = state.sessions.first?.sessionId }
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

    private func submit() {
        submitting = true
        let rounds = Int(maxRounds.trimmingCharacters(in: .whitespaces))
        Task {
            defer { submitting = false }
            do {
                guard let sessionId = effectiveSessionId else { return }
                try await state.createGoal(
                    sessionId: sessionId,
                    objective: objective.trimmingCharacters(in: .whitespacesAndNewlines),
                    maxRounds: rounds
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
