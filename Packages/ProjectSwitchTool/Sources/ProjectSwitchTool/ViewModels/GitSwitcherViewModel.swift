//
//  GitSwitcherViewModel.swift
//  GitSwitcher
//
//  Created by kim on 2026/3/13.
//

import Foundation
import Yams
import AppKit
import SwiftUI
import Rainbow

public enum LogLevel: Sendable {
    case info
    case success
    case warning
    case error
}

public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let message: String
    public let level: LogLevel
    
    public init(_ message: String) {
        self.message = message
        if message.contains("成功") {
            self.level = .success
        } else if message.contains("失败") || message.contains("错误") {
            self.level = .error
        } else if message.contains("stash") || message.contains("未找到") {
            self.level = .warning
        } else if message.contains("已经在") {
            self.level = .info
        } else {
            self.level = .info
        }
    }
    
    public var coloredMessage: String {
        switch level {
        case .success:
            return message.green
        case .error:
            return message.red
        case .warning:
            return message.yellow
        case .info:
            return message.cyan
        }
    }
}

@Observable
@MainActor
public final class GitSwitcherViewModel {
    public var projectPath: String = ""
    public var repos: [Repo] = []
    public var isWorking: Bool = false
    var logs: [LogEntry] = []
    
    private let service = GitService()
    
    public init() {}
    
    public func selectWorkspace() {
        let panel = NSOpenPanel()
        
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = .desktopDirectory
        
        if panel.runModal() == .OK {
            let path = panel.url?.path ?? ""
            projectPath = path
            
            let configPath = (path as NSString).appendingPathComponent("repos.yaml")
            guard let config = loadConfig(path: configPath) else { return }
            repos = scanRepos(root: (path as NSString).deletingLastPathComponent, config: config)
        }
    }
    
    public func loadConfig(path: String) -> RepoConfig? {
        do {
            let yamlString = try String(contentsOfFile: path, encoding: .utf8)
            
            let decoder = YAMLDecoder()
            let config = try decoder.decode(RepoConfig.self, from: yamlString)
            return config
        } catch {
            appendLog("YAML 解析失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func scanRepos(root: String, config: RepoConfig) -> [Repo] {
        var scannedRepos: [Repo] = []
        for (name, branch) in config.repos {
            let repoPath = (root as NSString).appendingPathComponent(name)
            let gitPath = (repoPath as NSString).appendingPathComponent(".git")
            
            if FileManager.default.fileExists(atPath: gitPath) {
                var repo = Repo(name: name, path: repoPath, currentBranch: "", targetBranch: branch)
                let currentBranch = service.readCurrentBranch(repo: repo)
                repo.currentBranch = currentBranch
                scannedRepos.append(repo)
                appendLog("\(name)\t当前分支:\(repo.currentBranch) -> 目标分支:\(repo.targetBranch)")
            } else {
                appendLog("未找到仓库: \(name)")
            }
        }
        return scannedRepos
    }
    
    public func switchWorkspace() {
        let currentRepos = repos
        isWorking = true
        
        Task.detached { @MainActor [self] in
            for repo in currentRepos {
                if repo.currentBranch == repo.targetBranch {
                    self.appendLog("\(repo.name) 已经在目标分支")
                    continue
                }
                do {
                    if service.hasChanges(repo: repo) {
                        try service.stash(repo: repo)
                        self.appendLog("\(repo.name) 已 stash 当前分支改动，请在合适时机手动恢复")
                    }
                    try service.checkout(repo: repo, branch: repo.targetBranch)
                    try service.pull(repo: repo)
                    self.appendLog("\(repo.name) 切换到 \(repo.targetBranch) 成功")
                } catch {
                    self.appendLog("\(repo.name) 切换失败: \(error.localizedDescription)")
                }
            }
            self.isWorking = false
        }
    }
    
    private func appendLog(_ message: String) {
        logs.append(LogEntry(message))
    }
}
