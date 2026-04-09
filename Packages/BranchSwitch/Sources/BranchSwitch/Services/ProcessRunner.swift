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

    public func run(_ command: String, at path: String) throws -> String {
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
            process.waitUntilExit()

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
