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
    public var configPath: String = ""
    public var pathHistory: [String] = []
    public var repos: [Repo] = []
    public var isWorking: Bool = false
    public var isLoadingWorkspace: Bool = false
    public var isLoadingBranches: Bool = false
    public var switchCompleted: Bool = false
    public var errorMessage: String?
    public var operationSummary: String?
    public var operationProgress: String?

    // 新增：分支选择相关
    public var selectedBranch: String = ""
    public var availableBranches: [String] = []

    public var hasWorkspace: Bool {
        switchCompleted && findXcodeProjectURL() != nil
    }

    private let service = GitService()
    private var workspaceLoadID = UUID()

    public init() {
        // 加载路径历史
        pathHistory = UserDefaults.standard.stringArray(forKey: Self.pathHistoryKey) ?? []
        // 加载上次选择的路径
        if let lastPath = pathHistory.first {
            projectPath = lastPath
            configPath = Self.configPath(for: lastPath)
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
            guard let path = panel.url?.path else { return }
            selectPath(path)
        }
    }

    public func selectHistoryPath(_ path: String) {
        errorMessage = nil
        projectPath = path
        configPath = Self.configPath(for: path)
        switchCompleted = false
        loadWorkspace(at: path)
    }

    private func selectPath(_ path: String) {
        errorMessage = nil
        projectPath = path
        configPath = Self.configPath(for: path)
        switchCompleted = false
        saveToHistory(path)
        loadWorkspace(at: path)
    }

    private func loadWorkspace(at path: String) {
        let loadID = UUID()
        workspaceLoadID = loadID
        isLoadingWorkspace = true
        repos = []

        let service = service
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.readAndScanWorkspace(path: path, service: service)
            }.value
            guard let self, self.workspaceLoadID == loadID else { return }
            self.repos = result.repos
            self.errorMessage = result.error
            self.isLoadingWorkspace = false
            self.logReposStatus()
            if let error = result.error {
                LogManager.shared.error(error)
            }
        }
    }

    public func openInXcode() {
        guard let projectURL = findXcodeProjectURL() else {
            LogManager.shared.warning("未找到 xcworkspace 或 xcodeproj")
            return
        }

        NSWorkspace.shared.openApplication(at: projectURL, configuration: NSWorkspace.OpenConfiguration())
    }

    public func loadConfig(path: String) -> RepoConfig? {
        do {
            let yamlString = try String(contentsOfFile: path, encoding: .utf8)

            let decoder = YAMLDecoder()
            let config = try decoder.decode(RepoConfig.self, from: yamlString)
            errorMessage = nil
            return config
        } catch {
            errorMessage = "YAML 解析失败：\(error.localizedDescription)"
            LogManager.shared.error(errorMessage ?? "YAML 解析失败")
            return nil
        }
    }

    public func scanRepos(root: String, config: RepoConfig) -> [Repo] {
        Self.scannedRepos(root: root, config: config, service: service)
    }

    nonisolated private static func readAndScanWorkspace(path: String, service: GitService) -> (repos: [Repo], error: String?) {
        let configPath = Self.configPath(for: path)
        let configText: String
        do {
            configText = try String(contentsOfFile: configPath, encoding: .utf8)
        } catch {
            return ([], "读取配置失败：\(error.localizedDescription)")
        }

        let config: RepoConfig
        do {
            config = try YAMLDecoder().decode(RepoConfig.self, from: configText)
        } catch {
            return ([], "YAML 解析失败：\(error.localizedDescription)")
        }

        return (scannedRepos(root: (path as NSString).deletingLastPathComponent, config: config, service: service), nil)
    }

    nonisolated private static func scannedRepos(root: String, config: RepoConfig, service: GitService) -> [Repo] {
        var scannedRepos: [Repo] = []
        for (name, branch) in config.repos {
            let repoPath = (root as NSString).appendingPathComponent(name)
            let isAvailable = isGitRepository(at: repoPath)
            var repo = Repo(
                name: name,
                path: repoPath,
                currentBranch: isAvailable ? "" : "未找到",
                targetBranch: branch,
                isMainRepo: name == config.org,
                isAvailable: isAvailable
            )

            if isAvailable {
                repo.currentBranch = service.readCurrentBranch(repo: repo)
                repo.hasStash = service.hasSavedStash(repo: repo)
            }

            scannedRepos.append(repo)
        }

        return scannedRepos.sorted { lhs, rhs in
            if lhs.isMainRepo != rhs.isMainRepo {
                return lhs.isMainRepo
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public func logReposStatus() {
        for repo in repos {
            LogManager.shared.info("\(repo.name)\t当前分支:\(repo.currentBranch) -> 目标分支:\(repo.targetBranch)")
        }
    }

    // MARK: - 分支相关操作

    public func loadBranches(for repo: Repo) {
        isLoadingBranches = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = self.service
            let result = await Task.detached(priority: .userInitiated) {
                (service.fetchBranches(repo: repo), service.readGitmodules(repo: repo))
            }.value
            if let index = self.repos.firstIndex(where: { $0.id == repo.id }) {
                self.repos[index].branches = result.0
                self.repos[index].submodules = result.1
            }
            self.isLoadingBranches = false
        }
    }

    public func loadSubmodules(for repo: Repo) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = self.service
            let submodules = await Task.detached(priority: .userInitiated) {
                service.readGitmodules(repo: repo)
            }.value
            if let index = self.repos.firstIndex(where: { $0.id == repo.id }) {
                self.repos[index].submodules = submodules
            }
        }
    }

    public func switchBranch(for repo: Repo, to branch: String) {
        isWorking = true
        operationSummary = nil
        operationProgress = "正在切换 \(repo.name)…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = self.service
            let result = await Task.detached(priority: .userInitiated) { () -> (String, [Submodule], String?) in
                var resultingSubmodules: [Submodule] = []
                do {
                    let oldSubmodules = service.readGitmodules(repo: repo)
                    if service.hasChanges(repo: repo) {
                        try service.saveStash(repo: repo)
                    }

                    try service.checkout(repo: repo, branch: branch)
                    let newSubmodules = service.readGitmodules(repo: repo)
                    resultingSubmodules = newSubmodules.map { newSubmodule in
                        let oldBranch = oldSubmodules.first(where: { $0.path == newSubmodule.path })?.currentBranch ?? ""
                        return Submodule(
                            id: newSubmodule.id,
                            name: newSubmodule.name,
                            path: newSubmodule.path,
                            currentBranch: oldBranch,
                            targetBranch: newSubmodule.targetBranch
                        )
                    }

                    for submodule in newSubmodules {
                        try service.checkoutSubmodule(repo: repo, submodule: submodule)
                    }
                    try service.restoreStash(repo: repo)
                    return (service.readCurrentBranch(repo: repo), resultingSubmodules, nil)
                } catch {
                    return (service.readCurrentBranch(repo: repo), resultingSubmodules, error.localizedDescription)
                }
            }.value

            if let index = self.repos.firstIndex(where: { $0.id == repo.id }) {
                self.repos[index].currentBranch = result.0
                self.repos[index].submodules = result.1
            }
            self.operationProgress = nil
            self.operationSummary = result.2.map { "切换失败：\($0)" } ?? "\(repo.name) 切换完成"
            self.errorMessage = result.2
            if let error = result.2 {
                LogManager.shared.error("\(repo.name) 切换失败：\(error)")
            } else {
                LogManager.shared.success("\(repo.name) 已切换到 \(branch)")
            }
            self.isWorking = false
        }
    }

    public func switchSubmoduleBranch(for repo: Repo, submodule: Submodule) {
        isWorking = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = self.service
            let errorMessage = await Task.detached(priority: .userInitiated) { () -> String? in
                do {
                    try service.checkoutSubmodule(repo: repo, submodule: submodule)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value

            if let repoIndex = self.repos.firstIndex(where: { $0.id == repo.id }), errorMessage == nil,
               let submoduleIndex = self.repos[repoIndex].submodules.firstIndex(where: { $0.id == submodule.id }) {
                self.repos[repoIndex].submodules[submoduleIndex].currentBranch = submodule.targetBranch
            }
            if let errorMessage {
                LogManager.shared.error("子模块切换失败: \(errorMessage)")
            }
            self.isWorking = false
        }
    }

    // MARK: - 旧版切换（保留兼容性）

    public func switchWorkspace() {
        let currentRepos = repos.map { repo -> Repo in
            var updated = repo
            updated.operationStatus = nil
            updated.operationDetail = nil
            return updated
        }
        repos = currentRepos
        isWorking = true
        switchCompleted = false

        operationSummary = nil
        errorMessage = nil
        LogManager.shared.info("========== 开始切换分支，共 \(currentRepos.count) 个仓库 ==========")

        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = self.service
            var updatedRepos: [Repo] = []
            var successCount = 0
            var skipCount = 0
            var failCount = 0

            for (index, originalRepo) in currentRepos.enumerated() {
                var repo = originalRepo
                self.operationProgress = "正在处理 \(index + 1)/\(currentRepos.count)：\(repo.name)"
                LogManager.shared.info("[\(index + 1)/\(currentRepos.count)] \(repo.name)：\(repo.currentBranch) → \(repo.targetBranch)")

                if !repo.isAvailable {
                    repo.operationStatus = "跳过"
                    repo.operationDetail = "目标路径不是可用的 Git 仓库。"
                    skipCount += 1
                } else if repo.currentBranch == repo.targetBranch {
                    repo.operationStatus = "跳过"
                    repo.operationDetail = "已经位于目标分支。"
                    skipCount += 1
                } else {
                    repo = await Task.detached(priority: .userInitiated) { [service, repo] in
                        var updatedRepo = repo
                        do {
                            if service.hasChanges(repo: repo) {
                                try service.saveStash(repo: repo)
                            }
                            try service.checkout(repo: repo, branch: repo.targetBranch)
                            try service.pull(repo: repo)
                            try service.restoreStash(repo: repo)
                            updatedRepo.operationStatus = "成功"
                            updatedRepo.operationDetail = nil
                        } catch {
                            updatedRepo.operationStatus = "失败"
                            updatedRepo.operationDetail = error.localizedDescription
                        }
                        updatedRepo.currentBranch = service.readCurrentBranch(repo: repo)
                        updatedRepo.hasStash = service.hasSavedStash(repo: repo)
                        return updatedRepo
                    }.value

                    if repo.operationStatus == "成功" {
                        successCount += 1
                        LogManager.shared.success("[\(index + 1)] \(repo.name) 切换成功")
                    } else {
                        failCount += 1
                        LogManager.shared.error("[\(index + 1)] \(repo.name) 切换失败：\(repo.operationDetail ?? "未知错误")")
                    }
                }

                updatedRepos.append(repo)
                if repo.operationStatus == "跳过" {
                    LogManager.shared.warning("[\(index + 1)] \(repo.name) 已跳过：\(repo.operationDetail ?? "")")
                }
                if let repositoryIndex = self.repos.firstIndex(where: { $0.id == repo.id }) {
                    self.repos[repositoryIndex] = repo
                }
            }

            self.repos = updatedRepos
            self.operationProgress = nil
            self.operationSummary = "切换结果：成功 \(successCount)，跳过 \(skipCount)，失败 \(failCount)"
            self.errorMessage = failCount > 0 ? "有 \(failCount) 个仓库切换失败，请查看逐仓结果和日志。" : nil
            self.isWorking = false
            self.switchCompleted = true
            LogManager.shared.info("========== \(self.operationSummary ?? "切换完成") ==========")
        }
    }

    nonisolated private static func configPath(for path: String) -> String {
        (path as NSString).appendingPathComponent("repos.yaml")
    }

    nonisolated private static func isGitRepository(at path: String) -> Bool {
        let fileManager = FileManager.default
        let gitPath = (path as NSString).appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitPath) {
            return true
        }

        return (try? ProcessRunner.run("git rev-parse --is-inside-work-tree", at: path))?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    private func findXcodeProjectURL() -> URL? {
        let searchPaths = [projectPath] + repos.map(\.path)
        for path in searchPaths where !path.isEmpty {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard let matches = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
                continue
            }

            if let workspace = matches.first(where: { $0.pathExtension == "xcworkspace" }) {
                return workspace
            }

            if let project = matches.first(where: { $0.pathExtension == "xcodeproj" }) {
                return project
            }
        }

        return nil
    }
}
