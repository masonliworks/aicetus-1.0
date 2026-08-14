// SettingsView.swift — server address + token configuration.

import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var baseURL = ""
    @State private var token = ""
    @State private var showToken = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var showScanner = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case address
        case token
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $baseURL, prompt: Text("Mac 地址，如 http://192.168.1.10:3878")) {
                        Text("服务器地址")
                    }
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .address)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    HStack {
                        if showToken {
                            TextField(text: $token) {
                                Text("Token")
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .token)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                        } else {
                            SecureField(text: $token) {
                                Text("Token")
                            }
                            .focused($focusedField, equals: .token)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                        }
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("桥接服务")
                } footer: {
                    Text("Token 在 Mac 上运行桥接服务时打印，或查看 ~/.dsh-remote-bridge/token")
                }

                Section {
                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("扫码配对")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                } footer: {
                    Text("在 Mac 伴侣 App 中启动桥接服务，扫描其显示的二维码即可自动完成配置。")
                }

                Section {
                    Button {
                        saveAndConnect()
                    } label: {
                        if busy {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(state.isConnected ? "保存并重连" : "连接")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .disabled(busy || baseURL.trimmingCharacters(in: .whitespaces).isEmpty || token.isEmpty)
                    .listRowSeparator(.hidden)

                    if state.isConnected {
                        Button(role: .destructive) {
                            state.disconnect()
                        } label: {
                            Text("断开连接")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Section("连接状态") {
                    LabeledContent("状态", value: statusText)
                    if let version = state.hostVersion {
                        LabeledContent("DSH 版本", value: version)
                    }
                    if let error = errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section("关于") {
                    LabeledContent("App", value: "掌中鲸")
                    LabeledContent("桥接服务", value: "dsh-remote-bridge")
                    Text("通过局域网内的桥接服务远程控制 Mac 上的 DeepSeek Harness。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(TapGesture().onEnded {
                focusedField = nil
            })
            .onAppear {
                focusedField = nil
                if let config = state.config {
                    baseURL = config.baseURL
                    token = config.token
                }
            }
            .onDisappear {
                focusedField = nil
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { scanned in
                    showScanner = false
                    applyScanned(scanned)
                }
                .ignoresSafeArea()
            }
        }
    }

    /// Handle a scanned pairing code: fill the form and connect immediately.
    private func applyScanned(_ text: String) {
        guard let url = URL(string: text), let config = PairingURL.parse(url) else {
            errorMessage = "无效的配对二维码：\(text)"
            return
        }
        baseURL = config.baseURL
        token = config.token
        state.config = config
        state.disconnect()
        state.connect()
    }

    private var statusText: String {
        switch state.phase {
        case .connected: "已连接"
        case .connecting: "连接中…"
        case .disconnected: "未连接"
        case .failed(let message): "失败: \(message)"
        }
    }

    private func saveAndConnect() {
        errorMessage = nil
        let newConfig = ServerConfig(baseURL: baseURL, token: token)
        guard newConfig.isValid else {
            errorMessage = "地址或 Token 无效"
            return
        }
        state.config = newConfig
        busy = true
        Task {
            state.connect()
            // Give the first refresh a moment, then surface any failure.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if case .failed(let message) = state.phase {
                errorMessage = message
            }
            busy = false
        }
    }
}
