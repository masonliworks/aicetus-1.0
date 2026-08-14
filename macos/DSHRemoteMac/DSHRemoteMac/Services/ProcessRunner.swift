// ProcessRunner.swift — run a subprocess and stream its stdout/stderr lines.

import Foundation
import os

/// A small helper to launch an executable, stream output, and await exit.
enum ProcessRunner {
    struct Result {
        let exitCode: Int32
        let output: String
    }

    /// Run a command to completion, streaming lines to `onLine` and awaiting
    /// the aggregate output. `onLine` may be called from a background queue.
    @discardableResult
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        onLine: ((String) -> Void)? = nil
    ) async -> Result {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
            if let environment {
                process.environment = environment
            }

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let collected = OSAllocatedUnfairLock(initialState: "")

            func stream(_ pipe: Pipe) {
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        pipe.fileHandleForReading.readabilityHandler = nil
                        return
                    }
                    guard let s = String(data: data, encoding: .utf8) else { return }
                    collected.withLock { $0 += s }
                    for line in s.split(whereSeparator: \.isNewline) {
                        onLine?(String(line))
                    }
                }
            }
            stream(outPipe)
            stream(errPipe)

            process.terminationHandler = { _ in
                let output = collected.withLock { $0 }
                continuation.resume(returning: Result(exitCode: process.terminationStatus, output: output))
            }

            do {
                try process.run()
            } catch {
                let output = collected.withLock { $0 }
                continuation.resume(returning: Result(exitCode: -1, output: output + "\n\(error.localizedDescription)"))
            }
        }
    }

    /// Run a command synchronously and capture stdout (for quick checks like `which`).
    @discardableResult
    static func runSync(_ executable: String, _ arguments: [String]) -> (exitCode: Int32, stdout: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return (-1, "")
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, out)
    }
}
