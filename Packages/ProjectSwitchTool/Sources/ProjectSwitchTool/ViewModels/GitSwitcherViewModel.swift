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
    private static let pathHistoryKey = "GitSwitcher.pathHistory"
    private static let maxHistoryCount = 10

    public var projectPath: String = ""
    public var pathHistory: [String] = []
    public var repos: [Repo] = []
    public var isWorking: Bool = false
    public var isLoadingBranches: Bool = false

    // 新增：分支选择相关
    public var selectedBranch: String = ""
    public var availableBranches: [String] = []

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
        // 加载路径历史
        pathHistory = UserDefaults.standard.stringArray(forKey: Self.pathHistoryKey) ?? []
        // 加载上次选择的路径
        if let lastPath = pathHistory.first {
            projectPath = lastPath
            loadWorkspace(at: lastPath)
        }
    }

    private func saveToHistory(_ path: String) {
        // 移除已存在的相同路径
        pathHistory.removeAll { $0 == path }
        // 添加到最前面
        pathHistory.insert(path, at: 0)
        // 限制最大数量
        if pathHistory.count > Self.maxHistoryCount {
            pathHistory = Array(pathHistory.prefix(Self.maxHistoryCount))
        }
        UserDefaults.standard.set(pathHistory, forKey: Self.pathHistoryKey)
    }

    public func selectWorkspace() {
        let panel = NSOpenPanel()

        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = pathHistory.first.flatMap { URL(fileURLWithPath: $0) } ?? .desktopDirectory

        if panel.runModal() == .OK {
            let path = panel.url?.path ?? ""
            selectPath(path)
        }
    }

    public func selectHistoryPath(_ path: String) {
        projectPath = path
        repos = loadWorkspace(at: path)
        logReposStatus()
    }

    private func selectPath(_ path: String) {
        projectPath = path
        saveToHistory(path)
        repos = loadWorkspace(at: path)
        logReposStatus()
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
                repo.isMainRepo = (name == config.org)
                repo.hasStash = service.hasSavedStash(repo: repo)
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

    // MARK: - 分支相关操作

    public func loadBranches(for repo: Repo) {
        isLoadingBranches = true
        Task {
            let branches = service.fetchBranches(repo: repo)
            // 加载分支时同时读取 gitmodules 获取子模块信息
            let submodules = service.readGitmodules(repo: repo)
            await MainActor.run {
                if let index = self.repos.firstIndex(where: { $0.id == repo.id }) {
                    self.repos[index].branches = branches
                    self.repos[index].submodules = submodules
                }
                self.isLoadingBranches = false
            }
        }
    }

    public func loadSubmodules(for repo: Repo) {
        Task {
            let submodules = service.readGitmodules(repo: repo)
            await MainActor.run {
                if let index = self.repos.firstIndex(where: { $0.id == repo.id }) {
                    self.repos[index].submodules = submodules
                }
            }
        }
    }

    public func switchBranch(for repo: Repo, to branch: String) {
        isWorking = true

        Task {
            LogManager.shared.info("========== 开始切换分支 ==========")
            LogManager.shared.info("仓库: \(repo.name)")
            LogManager.shared.info("目标分支: \(branch)")

            // 切换前记录子模块的当前分支
            let oldSubmodules = service.readGitmodules(repo: repo)
            var submoduleBeforeSwitch: [Submodule] = []
            for oldSub in oldSubmodules {
                submoduleBeforeSwitch.append(Submodule(
                    name: oldSub.name,
                    path: oldSub.path,
                    currentBranch: oldSub.targetBranch,  // 切换前的分支
                    targetBranch: oldSub.targetBranch
                ))
            }

            do {
                // 1. 检查并保存未提交的修改
                if service.hasChanges(repo: repo) {
                    LogManager.shared.info("检测到未提交改动，保存到本地...")
                    try service.saveStash(repo: repo)
                }

                // 2. 切换主仓库分支
                LogManager.shared.info("步骤 1: 切换主仓库到 \(branch)...")
                try service.checkout(repo: repo, branch: branch)
                LogManager.shared.info("主仓库切换完成")

                // 3. 读取 gitmodules 获取切换后的子模块信息
                LogManager.shared.info("步骤 2: 读取子模块信息...")
                let newSubmodules = service.readGitmodules(repo: repo)

                // 合并：currentBranch = 切换前的分支, targetBranch = 切换后的分支
                var mergedSubmodules: [Submodule] = []
                for newSub in newSubmodules {
                    let oldBranch = submoduleBeforeSwitch.first(where: { $0.path == newSub.path })?.currentBranch ?? ""
                    mergedSubmodules.append(Submodule(
                        name: newSub.name,
                        path: newSub.path,
                        currentBranch: oldBranch,
                        targetBranch: newSub.targetBranch
                    ))
                }

                await MainActor.run {
                    if let index = self.repos.firstIndex(where: { $0.id == repo.id }) {
                        self.repos[index].submodules = mergedSubmodules
                        self.repos[index].currentBranch = branch
                    }
                }

                if newSubmodules.isEmpty {
                    LogManager.shared.info("无子模块")
                } else {
                    LogManager.shared.info("发现 \(newSubmodules.count) 个子模块")

                    // 4. 切换子模块
                    for submodule in newSubmodules {
                        LogManager.shared.info("步骤 3: 切换子模块 \(submodule.name) 到 \(submodule.targetBranch)...")
                        try service.checkoutSubmodule(repo: repo, submodule: submodule)
                    }
                }

                // 5. 尝试恢复 stash
                LogManager.shared.info("步骤 4: 检查是否需要恢复保存的修改...")
                try service.restoreStash(repo: repo)

                LogManager.shared.success("========== 切换完成 ==========")
            } catch {
                LogManager.shared.error("切换失败: \(error.localizedDescription)")
            }

            await MainActor.run {
                self.isWorking = false
            }
        }
    }

    public func switchSubmoduleBranch(for repo: Repo, submodule: Submodule) {
        isWorking = true

        Task {
            do {
                try service.checkoutSubmodule(repo: repo, submodule: submodule)
                await MainActor.run {
                    if let repoIndex = self.repos.firstIndex(where: { $0.id == repo.id }) {
                        if let submoduleIndex = self.repos[repoIndex].submodules.firstIndex(where: { $0.id == submodule.id }) {
                            self.repos[repoIndex].submodules[submoduleIndex].currentBranch = submodule.targetBranch
                        }
                    }
                    self.isWorking = false
                }
            } catch {
                LogManager.shared.error("子模块切换失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.isWorking = false
                }
            }
        }
    }

    // MARK: - 旧版切换（保留兼容性）

    public func switchWorkspace() {
        let currentRepos = repos
        isWorking = true

        Task {
            LogManager.shared.info("========== 开始切换分支 ==========")
            LogManager.shared.info("共 \(currentRepos.count) 个仓库待处理")

            var successCount = 0
            var skipCount = 0
            var failCount = 0

            for (index, repo) in currentRepos.enumerated() {
                LogManager.shared.info("[\(index + 1)/\(currentRepos.count)] 正在处理: \(repo.name)")
                LogManager.shared.info("  当前分支: \(repo.currentBranch) -> 目标分支: \(repo.targetBranch)")

                if repo.currentBranch == repo.targetBranch {
                    LogManager.shared.info("  结果: 跳过（已在目标分支）")
                    skipCount += 1
                    continue
                }

                do {
                    if service.hasChanges(repo: repo) {
                        LogManager.shared.info("  步骤: 检测到未提交改动，执行 stash...")
                        try service.saveStash(repo: repo)
                        LogManager.shared.warning("  stash 已保存到本地")
                    }

                    LogManager.shared.info("  步骤: 切换到 \(repo.targetBranch)...")
                    try service.checkout(repo: repo, branch: repo.targetBranch)
                    LogManager.shared.info("  checkout 完成")

                    LogManager.shared.info("  步骤: 拉取远程更新...")
                    try service.pull(repo: repo)
                    LogManager.shared.info("  pull 完成")

                    // 恢复 stash
                    try service.restoreStash(repo: repo)

                    LogManager.shared.success("[\(index + 1)] \(repo.name) 切换成功")
                    successCount += 1
                } catch {
                    LogManager.shared.error("[\(index + 1)] \(repo.name) 切换失败: \(error.localizedDescription)")
                    failCount += 1
                }
            }

            LogManager.shared.info("========== 切换完成 ==========")
            LogManager.shared.info("成功: \(successCount), 跳过: \(skipCount), 失败: \(failCount)")

            await MainActor.run {
                self.isWorking = false
            }
        }
    }
}
