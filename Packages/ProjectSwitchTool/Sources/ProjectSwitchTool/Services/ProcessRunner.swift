//
//  ProcessRunner.swift
//  GitSwitcher
//
//  Created by kim on 2026/3/13.
//

import Foundation

public enum ProcessRunnerError: Error, LocalizedError, Sendable {
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return message
        }
    }
}

public struct ProcessRunner: Sendable {
    public static func run(_ command: String, at path: String) throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        
        process.launch()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    public init() {}
}
