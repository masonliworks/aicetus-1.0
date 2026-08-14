// DshWebManager.swift — monitor the local dsh web server (port 3080) and
// provide a run switch (spawn/terminate `dsh web`).

import Foundation

@MainActor
@Observable
final class DshWebManager {
    enum Status: Equatable {
        case unknown
        case checking
        case running
        case stopped
        case starting
        case failed(String)
    }

    static let defaultURL = URL(string: "http://127.0.0.1:3080")!

    private(set) var status: Status = .unknown
    private(set) var lastLog: [String] = []
    /// Whether dsh web is registered as a launchd LaunchAgent (login autostart).
    private(set) var autoStartEnabled = false

    static let launchAgentLabel = "com.dshremote.dshweb"
    static var launchAgentPlist: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }
    private var process: Process?
    private var pollTask: Task<Void, Never>?

    func startMonitoring() {
        refreshAutoStartState()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkOnce()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: - LaunchAgent autostart

    /// Whether the LaunchAgent plist exists and is loaded by launchd.
    func refreshAutoStartState() {
        let fileExists = FileManager.default.fileExists(atPath: Self.launchAgentPlist.path)
        let uid = getuid()
        let check = ProcessRunner.runSync("launchctl", ["print", "gui/\(uid)/\(Self.launchAgentLabel)"])
        autoStartEnabled = fileExists && check.exitCode == 0
    }

    /// Register dsh web to start at login via a launchd LaunchAgent.
    func enableAutoStart() {
        guard let dshPath = DshInstaller.find("dsh") else { return }
        let plist: [String: Any] = [
            "Label": Self.launchAgentLabel,
            "ProgramArguments": [dshPath, "web"],
            "EnvironmentVariables": ["PATH": DshInstaller.resolvedShellPATH],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "/tmp/dsh-web-autostart.log",
            "StandardErrorPath": "/tmp/dsh-web-autostart.err.log",
        ]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try FileManager.default.createDirectory(
                at: Self.launchAgentPlist.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: Self.launchAgentPlist, options: .atomic)
            let uid = getuid()
            let r = ProcessRunner.runSync("launchctl", ["bootstrap", "gui/\(uid)", Self.launchAgentPlist.path])
            if r.exitCode != 0 {
                // Already bootstrapped — fall back to kickstart reload.
                _ = ProcessRunner.runSync("launchctl", ["bootout", "gui/\(uid)/\(Self.launchAgentLabel)"])
                _ = ProcessRunner.runSync("launchctl", ["bootstrap", "gui/\(uid)", Self.launchAgentPlist.path])
            }
        } catch {
            lastLog.append("注册自启动失败: \(error.localizedDescription)")
        }
        refreshAutoStartState()
    }

    /// Remove the LaunchAgent (no longer start at login).
    func disableAutoStart() {
        let uid = getuid()
        _ = ProcessRunner.runSync("launchctl", ["bootout", "gui/\(uid)/\(Self.launchAgentLabel)"])
        try? FileManager.default.removeItem(at: Self.launchAgentPlist)
        refreshAutoStartState()
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
    }

    func checkOnce() async {
        // Don't clobber "starting" while the spawn is in flight.
        if case .starting = status { return }
        var request = URLRequest(url: Self.defaultURL)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse).map { (200..<400).contains($0.statusCode) } ?? false
            status = ok ? .running : .stopped
        } catch {
            status = .stopped
        }
    }

    /// Launch `dsh web` as a child process (uses the login-shell PATH so a
    /// user-installed dsh is found).
    func start() {
        guard let dshPath = DshInstaller.find("dsh") else {
            status = .failed("未找到 dsh 命令，请先安装 DeepSeek Harness")
            return
        }
        stopProcessOnly()
        lastLog = []
        status = .starting
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dshPath)
        process.arguments = ["web"]
        process.environment = ["PATH": DshInstaller.resolvedShellPATH]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        self.process = process

        func attach(_ pipe: Pipe?) {
            guard let pipe else { return }
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty { return }
                if let s = String(data: data, encoding: .utf8) {
                    for line in s.split(whereSeparator: \.isNewline) {
                        let text = String(line)
                        Task { @MainActor in self?.ingestLog(text) }
                    }
                }
            }
        }
        attach(process.standardOutput as? Pipe)
        attach(process.standardError as? Pipe)

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.status = .stopped
            }
        }

        do {
            try process.run()
            // Give it a moment, then probe the health endpoint.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.checkOnce()
            }
        } catch {
            status = .failed("启动失败: \\(error.localizedDescription)")
        }
    }

    func stop() {
        stopProcessOnly()
        status = .stopped
    }

    private func stopProcessOnly() {
        process?.terminate()
        process = nil
    }

    private func ingestLog(_ line: String) {
        lastLog.append(line)
        if lastLog.count > 30 { lastLog.removeFirst(lastLog.count - 30) }
        if line.contains("listening") || line.contains("dsh web:") {
            status = .running
        }
    }
}
