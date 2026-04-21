//
//  ProcessRunner.swift
//  BranchSwitch
//

import Foundation

public enum ProcessRunnerError: Error, LocalizedError, Sendable {
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "命令执行失败: \(message)"
        }
    }
}

public struct ProcessRunner: Sendable {
    public init() {}

    /// 超时时间（秒），默认 60 秒
    private static let defaultTimeout: TimeInterval = 60

    public func run(_ command: String, at path: String, timeout: TimeInterval? = nil) throws -> String {
        let effectiveTimeout = timeout ?? Self.defaultTimeout
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = pipe
        process.standardError = errorPipe
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]

        do {
            try process.run()

            // 使用超时机制等待进程完成
            let deadline = DispatchTime.now() + effectiveTimeout

            var processFinished = false
            let lock = NSLock()

            // 在后台线程等待进程
            Thread {
                process.waitUntilExit()
                lock.lock()
                processFinished = true
                lock.unlock()
            }.start()

            // 等待直到完成或超时
            lock.lock()
            while !processFinished {
                lock.unlock()
                Thread.sleep(forTimeInterval: 0.1)
                let now = DispatchTime.now()
                if now >= deadline {
                    lock.unlock()
                    process.interrupt()
                    throw ProcessRunnerError.executionFailed("命令执行超时 (\(Int(effectiveTimeout))秒): \(command)")
                }
                lock.lock()
            }
            lock.unlock()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: data, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 && !errorOutput.isEmpty {
                throw ProcessRunnerError.executionFailed(errorOutput)
            }

            return output
        } catch {
            throw ProcessRunnerError.executionFailed(error.localizedDescription)
        }
    }
}
