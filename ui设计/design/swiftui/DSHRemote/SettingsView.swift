//
//  SettingsView.swift
//  DSH Remote — 设置（规范 §6.4）
//

import SwiftUI

struct SettingsView: View {
    @State private var bridgeAddress = "ws://192.168.1.8:7820"
    @State private var token = "dsh_9f2e…7K2P"
    @State private var showToken = false
    @State private var connected = true
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                // 1. 桥接服务
                Section {
                    LabeledContent("地址") {
                        TextField("ws://host:port", text: $bridgeAddress)
                            .font(DSFont.mono(14))
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Token") {
                        HStack(spacing: 6) {
                            if showToken {
                                Text(token).font(DSFont.mono(14)).lineLimit(1)
                            } else {
                                Text("••••••" + token.suffix(4)).font(DSFont.mono(14))
                            }
                            Button { showToken.toggle() } label: {
                                Image(systemName: showToken ? "eye.slash" : "eye")
                            }
                            .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                } header: {
                    Text("桥接服务")
                } footer: {
                    Text("地址与 Token 由 Mac 伴侣 App 生成，建议扫码自动填充。")
                }

                // 2. 配对
                Section("配对") {
                    Button {
                        showScanner = true
                    } label: {
                        Label("扫码配对", systemImage: "qrcode.viewfinder")
                            .font(DSFont.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpace.s2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DSColor.accent)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }

                // 3. 连接
                Section("连接") {
                    Button("保存并重连") { reconnect() }
                        .tint(DSColor.accent)
                        .frame(maxWidth: .infinity)
                    if connected {
                        Button("断开连接", role: .destructive) { connected = false }
                            .frame(maxWidth: .infinity)
                    }
                }

                // 4. 连接状态
                Section("连接状态") {
                    LabeledContent("状态") {
                        StateIndicator(color: connected ? DSColor.statusRunning : DSColor.statusIdle,
                                       text: connected ? "已连接" : "未连接",
                                       pulsing: connected)
                    }
                    LabeledContent("DSH 版本", value: "v1.8.2")
                    LabeledContent("当前模型", value: "deepseek-v4 · High")
                    LabeledContent("错误", value: "无")
                }

                // 5. 关于
                Section("关于") {
                    LabeledContent("DSH Remote", value: "v0.3.1")
                }
            }
            .navigationTitle("设置")
            .fullScreenCover(isPresented: $showScanner) {
                NavigationStack { ScanPairView() }
            }
        }
    }

    private func reconnect() {
        // TODO: 保存配置并重建 WebSocket 连接
    }
}

#Preview {
    SettingsView()
}
