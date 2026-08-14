// BridgeManager.swift — manage the bundled dsh-remote-bridge Node service.

import Foundation
import Security

@MainActor
@Observable
final class BridgeManager {
    enum Status: Equatable {
        case stopped
        case starting
        case running(port: Int)
        case failed(String)
    }

    static nonisolated let defaultPort = 3878
    static nonisolated let defaultDshURL = "http://127.0.0.1:3080"

    private(set) var status: Status = .stopped
    private(set) var token: String = ""
    private(set) var logLines: [String] = []
    private var process: Process?

    /// Directory holding server.js + dsh-client.js.
    /// 开发模式（DEBUG 构建）：优先使用工作区源码（改动立即生效，无需重新构建 App）；
    /// 发布构建（Release）：始终使用 bundle 内置副本。
    var bridgeDirectory: URL? {
        #if DEBUG
        let devPath = URL(fileURLWithPath: "/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/bridge")
        if FileManager.default.fileExists(atPath: devPath.appendingPathComponent("server.js").path) {
            return devPath
        }
        #endif
        return Bundle.main.resourceURL?.appendingPathComponent("bridge")
    }

    /// Read or create the auth token at ~/.dsh-remote-bridge/token.
    static func resolveToken() -> String {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dsh-remote-bridge", isDirectory: true)
        let file = dir.appendingPathComponent("token")
        if let existing = try? String(contentsOf: file, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return existing
        }
        let fresh = generateToken()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try fresh.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            // still return a usable token even if we can't persist it
        }
        return fresh
    }

    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes).base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
        }
        return UUID().uuidString + UUID().uuidString
    }

    func start(dshURL: String = BridgeManager.defaultDshURL, port: Int = BridgeManager.defaultPort) {
        guard let bridgeDirectory else {
            status = .failed("未找到内置 bridge 代码（Resources/bridge）")
            return
        }
        let server = bridgeDirectory.appendingPathComponent("server.js").path
        guard FileManager.default.fileExists(atPath: server) else {
            status = .failed("内置 bridge 代码缺失: \(server)")
            return
        }
        guard let nodePath = DshInstaller.find("node") else {
            status = .failed("未检测到 node，请先安装 Node.js")
            return
        }

        killStaleInstances(port: port)
        stop()
        token = Self.resolveToken()
        logLines = []
        status = .starting

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [server, "--dsh-url", dshURL, "--port", String(port), "--token", token]
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
                        Task { @MainActor in
                            self?.ingestLog(text, port: port)
                        }
                    }
                }
            }
        }
        attach(process.standardOutput as? Pipe)
        attach(process.standardError as? Pipe)

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if case .starting = self.status {
                    self.status = .failed("bridge 进程异常退出")
                } else {
                    self.status = .stopped
                }
            }
        }

        do {
            try process.run()
        } catch {
            status = .failed("启动失败: \(error.localizedDescription)")
        }
    }

    /// Auto-start entry: if a bridge is already listening on our port (from a
    /// previous run), just adopt the running state instead of restarting it.
    func ensureRunning() {
        if case .running = status { return }
        let lookup = ProcessRunner.runSync("lsof", ["-t", "-iTCP:\(Self.defaultPort)", "-sTCP:LISTEN"])
        if lookup.exitCode == 0, !lookup.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .running(port: Self.defaultPort)
            token = Self.resolveToken()
            return
        }
        start()
    }

    /// Kill any leftover bridge process holding our port (e.g. an orphaned
    /// instance from a previous app run) so the new one can bind.
    private func killStaleInstances(port: Int) {
        let lookup = ProcessRunner.runSync("lsof", ["-t", "-iTCP:\(port)", "-sTCP:LISTEN"])
        guard lookup.exitCode == 0 else { return }
        for rawPid in lookup.stdout.split(whereSeparator: \.isNewline) {
            let pid = String(rawPid).trimmingCharacters(in: .whitespaces)
            guard !pid.isEmpty, pid != String(ProcessInfo.processInfo.processIdentifier) else { continue }
            let cmd = ProcessRunner.runSync("ps", ["-p", pid, "-o", "command="])
            guard cmd.stdout.contains("server.js") else { continue }
            let killResult = ProcessRunner.runSync("kill", [pid])
            if killResult.exitCode == 0 {
                logLines.append("已清理残留桥接进程 (pid \(pid))")
            }
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        status = .stopped
    }

    private func ingestLog(_ line: String, port: Int) {
        logLines.append(line)
        if line.contains("listening on") {
            status = .running(port: port)
        }
    }
}
