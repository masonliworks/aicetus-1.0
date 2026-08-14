//
//  Sheets.swift
//  DSH Remote — 弹层（规范 §6.5）：新建会话 / 创建目标 / 扫码配对
//

import SwiftUI

// MARK: - 新建会话 sheet

struct NewSessionSheet: View {
    let workspaces: [Workspace]
    var onCreate: (Workspace?, String) -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedWorkspace: Workspace?
    @State private var selectedPreset = "default"

    private let presets: [(name: String, desc: String)] = [
        ("default", "通用预设，适合大多数任务"),
        ("code-reviewer", "先给方案再动手，改动逐条确认"),
        ("writer", "文案与整理向，减少命令执行"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("工作区") {
                    ForEach(workspaces) { ws in
                        pickerRow(title: ws.name, subtitle: ws.path,
                                  selected: selectedWorkspace == ws) {
                            selectedWorkspace = ws
                        }
                    }
                    pickerRow(title: "不指定工作区", subtitle: nil,
                              selected: selectedWorkspace == nil) {
                        selectedWorkspace = nil
                    }
                }
                Section("Agent 预设") {
                    ForEach(presets, id: \.name) { preset in
                        pickerRow(title: preset.name, subtitle: preset.desc,
                                  selected: selectedPreset == preset.name) {
                            selectedPreset = preset.name
                        }
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
                    Button("创建") {
                        onCreate(selectedWorkspace, selectedPreset)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func pickerRow(title: String, subtitle: String?,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DSSpace.s2) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? DSColor.accent : DSColor.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DSFont.body).foregroundStyle(DSColor.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - 创建目标 sheet

struct CreateGoalSheet: View {
    var onCreate: (String, Int) -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var objective = ""
    @State private var maxRounds = 20

    var body: some View {
        NavigationStack {
            Form {
                Section("目标描述") {
                    TextEditor(text: $objective)
                        .font(DSFont.body)
                        .frame(minHeight: 84)
                }
                Section {
                    Stepper("最多自动执行轮次：\(maxRounds)", value: $maxRounds, in: 1...100)
                } footer: {
                    Text("达到轮次上限后 Agent 会暂停并等待你的指示。留空描述将无法创建。")
                }
            }
            .navigationTitle("创建目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        onCreate(objective, maxRounds)
                        dismiss()
                    }
                    .disabled(objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 扫码配对取景页（§6.4）
// 真实实现：AVFoundation / VisionKit DataScanner 识别 dshremote:// 后自动填充并连接，成功震动。
// 骨架仅给出 UI 结构。

struct ScanPairView: View {
    var onScanned: (URL) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // TODO: DataScannerViewController / AVCaptureVideoPreviewLayer 嵌入此处

            // 取景框
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(DSColor.accent, lineWidth: 3)
                .frame(width: 230, height: 230)
                .overlay(alignment: .top) {
                    // 扫描线（上下往复）
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let y = 25 + abs(sin(t * .pi / 2.2)) * 180
                        Rectangle()
                            .fill(DSColor.accent)
                            .frame(height: 2)
                            .shadow(color: DSColor.accent, radius: 6)
                            .offset(y: y)
                    }
                    .clipped()
                }

            VStack {
                Spacer()
                Text("对准 Mac 伴侣 App 中的二维码")
                    .font(DSFont.body.weight(.semibold))
                Text("识别 dshremote:// 后自动填充地址与 Token\n连接成功时震动反馈")
                    .font(DSFont.footnote)
                    .multilineTextAlignment(.center)
                    .opacity(0.6)
                    .padding(.top, DSSpace.s1)
                Button("无法扫码？手动输入地址与 Token") {
                    dismiss()   // 回到设置页手动表单
                }
                .font(DSFont.footnote)
                .tint(DSColor.accent)
                .padding(.top, DSSpace.s4)
                .padding(.bottom, 40)
            }
            .foregroundStyle(.white)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.tint(DSColor.accent)
            }
        }
    }
}

#Preview("新建会话") {
    NewSessionSheet(workspaces: [SampleData.harness, SampleData.crawler])
}

#Preview("创建目标") {
    CreateGoalSheet()
}
