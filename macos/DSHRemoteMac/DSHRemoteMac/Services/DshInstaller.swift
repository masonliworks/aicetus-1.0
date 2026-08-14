// DshInstaller.swift — detect and install DeepSeek Harness (dsh CLI) + node/npm.

import Foundation

@MainActor
@Observable
final class DshInstaller {
    enum Status: Equatable {
        case unknown
        case checking
        case installed(version: String)
        case missing
        case installing
        case installFailed(String)
    }

    private(set) var status: Status = .unknown
    private(set) var logLines: [String] = []
    private(set) var nodeAvailable = false
    private(set) var npmAvailable = false

    /// Locate `dsh` / `npm` / `node` — checks the current PATH first, then the
    /// user's real login-shell PATH (GUI apps inherit a trimmed PATH that
    /// misses ~/.local/bin, ~/.hermes, nvm, homebrew, etc.).
    static func find(_ command: String) -> String? {
        if let hit = findInPath(command, ProcessInfo.processInfo.environment["PATH"]) {
            return hit
        }
        return findInPath(command, resolvedShellPATH)
    }

    private static func findInPath(_ command: String, _ pathEnv: String?) -> String? {
        guard let pathEnv, !pathEnv.isEmpty else { return nil }
        let fm = FileManager.default
        for dir in pathEnv.split(separator: ":").map(String.init) {
            guard !dir.isEmpty else { continue }
            let candidate = dir.hasSuffix("/") ? dir + command : dir + "/" + command
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// The user's real PATH, resolved once via their login shell.
    nonisolated static let resolvedShellPATH: String = {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let r = ProcessRunner.runSync(shell, ["-lc", "printf %s \"$PATH\""])
        if r.exitCode == 0, !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
    }()

    func detect() {
        status = .checking
        nodeAvailable = Self.find("node") != nil
        npmAvailable = Self.find("npm") != nil

        guard let dsh = Self.find("dsh") else {
            status = .missing
            return
        }
        // `dsh --version` prints to stderr in some builds; capture both.
        let r = ProcessRunner.runSync(dsh, ["--version"])
        let version = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        status = .installed(version: version.isEmpty ? "unknown" : version)
    }

    func install() async {
        guard npmAvailable else {
            status = .installFailed("未检测到 npm，请先安装 Node.js（nodejs.org）")
            return
        }
        status = .installing
        logLines = ["$ npm install -g @deepseek-ai/dsh"]
        let env = ["PATH": Self.resolvedShellPATH]
        let result = await ProcessRunner.run(
            executable: "npm",
            arguments: ["install", "-g", "@deepseek-ai/dsh"],
            environment: env,
            onLine: { [weak self] line in
                Task { @MainActor in self?.logLines.append(line) }
            }
        )
        if result.exitCode == 0 {
            detect()
        } else {
            status = .installFailed(result.output)
        }
    }
}
