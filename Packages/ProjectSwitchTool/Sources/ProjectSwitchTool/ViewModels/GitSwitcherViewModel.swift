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
import JYBLog

@Observable
@MainActor
public final class GitSwitcherViewModel {
    private static let lastProjectPathKey = "GitSwitcher.lastProjectPath"

    public var projectPath: String = ""
    public var repos: [Repo] = []
    public var isWorking: Bool = false

    public var hasWorkspace: Bool {
        guard !projectPath.isEmpty else { return false }
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: projectPath)

        if let matches = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
           matches.contains(where: { $0.pathExtension == "xcworkspace" || $0.pathExtension == "xcodeproj" }) {
            return true
        }
        return false
    }

    private let service = GitService()

    public init() {
        // 加载上次选择的路径
        if let lastPath = UserDefaults.standard.string(forKey: Self.lastProjectPathKey) {
            projectPath = lastPath
            loadWorkspace(at: lastPath)
        }
    }

    private func saveLastPath() {
        UserDefaults.standard.set(projectPath, forKey: Self.lastProjectPathKey)
    }

    public func selectWorkspace() {
        let panel = NSOpenPanel()

        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = .desktopDirectory

        if panel.runModal() == .OK {
            let path = panel.url?.path ?? ""
            projectPath = path
            saveLastPath()
            repos = loadWorkspace(at: path)
            logReposStatus()
        }
    }

    @discardableResult
    private func loadWorkspace(at path: String) -> [Repo] {
        let configPath = (path as NSString).appendingPathComponent("repos.yaml")
        guard let config = loadConfig(path: configPath) else { return [] }
        return scanRepos(root: (path as NSString).deletingLastPathComponent, config: config)
    }

    public func openInXcode() {
        guard !projectPath.isEmpty else { return }

        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: projectPath)

        // 优先查找 workspace
        if let matches = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
           let workspace = matches.first(where: { $0.pathExtension == "xcworkspace" }) {
            NSWorkspace.shared.openApplication(at: workspace, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        // 其次查找 xcodeproj
        if let matches = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
           let project = matches.first(where: { $0.pathExtension == "xcodeproj" }) {
            NSWorkspace.shared.openApplication(at: project, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        LogManager.shared.warning("未找到 xcworkspace 或 xcodeproj")
    }
    
    public func loadConfig(path: String) -> RepoConfig? {
        do {
            let yamlString = try String(contentsOfFile: path, encoding: .utf8)
            
            let decoder = YAMLDecoder()
            let config = try decoder.decode(RepoConfig.self, from: yamlString)
            return config
        } catch {
            LogManager.shared.error("YAML 解析失败: \(error.localizedDescription)")
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
            }
        }
        return scannedRepos
    }

    public func logReposStatus() {
        for repo in repos {
            LogManager.shared.info("\(repo.name)\t当前分支:\(repo.currentBranch) -> 目标分支:\(repo.targetBranch)")
        }
    }
    
    public func switchWorkspace() {
        let currentRepos = repos
        isWorking = true
        
        Task.detached { @MainActor [self] in
            for repo in currentRepos {
                if repo.currentBranch == repo.targetBranch {
                    LogManager.shared.info("\(repo.name) 已经在目标分支")
                    continue
                }
                do {
                    if service.hasChanges(repo: repo) {
                        try service.stash(repo: repo)
                        LogManager.shared.warning("\(repo.name) 已 stash 当前分支改动，请在合适时机手动恢复")
                    }
                    try service.checkout(repo: repo, branch: repo.targetBranch)
                    try service.pull(repo: repo)
                    LogManager.shared.success("\(repo.name) 切换到 \(repo.targetBranch) 成功")
                } catch {
                    LogManager.shared.error("\(repo.name) 切换失败: \(error.localizedDescription)")
                }
            }
            self.isWorking = false
        }
    }
    
}
