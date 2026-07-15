//
//  ReposSwitchViewModel.swift
//  BranchSwitch
//

import AppKit
import Foundation
import JYBLog

@Observable
@MainActor
public final class ReposSwitchViewModel {
  private static let lastProjectPathKey = "ReposSwitch.lastProjectPath"
  private static let maxConcurrentRepoSwitchCount = 6

  public var projectPath: String = ""
  public var configPath: String = ""
  public var rootPath: String = ""
  public var localBranches: [String] = []
  public var currentBranch: String = ""
  public var selectedBranch: String = ""
  public var repos: [RepoSwitchInfo] = []
  public var isLoading = false
  public var isSwitching = false
  public var isConfirmEnabled = false

  private let service = ReposYAMLService()
  private var currentTask: Task<Void, Never>?
  private var loadedConfig: ReposConfig?

  public init() {
    if let lastPath = UserDefaults.standard.string(forKey: Self.lastProjectPathKey) {
      projectPath = lastPath
      configPath = service.configURL(forProjectPath: lastPath).path
    }
  }

  public var hasWorkspace: Bool {
    guard !projectPath.isEmpty else { return false }
    if findWorkspace(in: projectPath) != nil {
      return true
    }

    for repo in repos where repo.isCloned {
      if findWorkspace(in: repo.absolutePath) != nil {
        return true
      }
    }

    return false
  }

  public func selectProject() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false

    if panel.runModal() == .OK, let url = panel.url {
      projectPath = url.path
      saveLastProjectPath()
      resetLoadedConfig()
      loadBranches()
    }
  }

  public func loadBranches() {
    guard !projectPath.isEmpty else { return }
    currentTask?.cancel()
    isLoading = true
    isConfirmEnabled = false
    configPath = service.configURL(forProjectPath: projectPath).path
    resetLoadedConfig()
    LogManager.shared.info("正在读取主工程本地分支...")

    let currentProjectPath = projectPath
    currentTask = Task { @MainActor in
      let result = await Task.detached { () -> BranchLoadResult in
        do {
          let service = ReposYAMLService()
          let branches = try service.getLocalBranches(at: currentProjectPath)
          let currentBranch = service.getCurrentBranch(at: currentProjectPath) ?? branches.first ?? ""
          return BranchLoadResult(
            branches: branches,
            currentBranch: currentBranch,
            error: nil
          )
        } catch {
          return BranchLoadResult(branches: [], currentBranch: "", error: error.localizedDescription)
        }
      }.value

      finishBranchLoad(result)
    }
  }

  public func branchSelectionChanged() {
    resetLoadedConfig()
  }

  public func loadData() {
    guard !projectPath.isEmpty, !selectedBranch.isEmpty else { return }
    currentTask?.cancel()
    isLoading = true
    isConfirmEnabled = false
    configPath = service.configURL(forProjectPath: projectPath).path
    LogManager.shared.info("正在切换主工程到 \(selectedBranch)，并读取 repos.yml...")

    let currentProjectPath = projectPath
    let branch = selectedBranch
    currentTask = Task { @MainActor in
      let result = await Task.detached { () -> LoadResult in
        do {
          let service = ReposYAMLService()
          try service.checkoutLocalBranch(branch, at: currentProjectPath) { message in
            Task { @MainActor in
              LogManager.shared.debug(message)
            }
          }
          let loaded = try service.loadRepoInfos(atProjectPath: currentProjectPath)
          let workspaceInfo = service.makeWorkspaceRepoInfo(rootPath: loaded.rootPath, targetBranch: branch)
          return LoadResult(
            config: loaded.config,
            rootPath: loaded.rootPath,
            repos: [workspaceInfo] + loaded.infos,
            currentBranch: branch,
            error: nil
          )
        } catch {
          return LoadResult(
            config: nil,
            rootPath: "",
            repos: [],
            currentBranch: "",
            error: error.localizedDescription
          )
        }
      }.value

      finishLoad(result)
    }
  }

  public func switchRepos() {
    guard let loadedConfig, !projectPath.isEmpty else { return }
    currentTask?.cancel()
    isSwitching = true
    isConfirmEnabled = false
    LogManager.shared.info("========== 开始公版配置切换 ==========")
    LogManager.shared.info("依赖仓库并发切换，最大并发数: \(Self.maxConcurrentRepoSwitchCount)")

    let currentConfig = loadedConfig
    let currentConfigURL = service.configURL(forProjectPath: projectPath)
    let workspaceRootPath = rootPath
    let workspaceTargetBranch = selectedBranch
    let maxConcurrentCount = Self.maxConcurrentRepoSwitchCount
    currentTask = Task { @MainActor in
      let results = await Task.detached { () async -> [RepoSwitchResult] in
        let service = ReposYAMLService()
        let rootURL = service.rootURL(for: currentConfig, configURL: currentConfigURL)
        var orderedResults: [RepoSwitchResult] = []

        if !workspaceRootPath.isEmpty {
          let workspaceName = URL(fileURLWithPath: workspaceRootPath, isDirectory: true)
            .standardizedFileURL
            .lastPathComponent
          let workspaceResult = service.updateExistingRepo(
            name: workspaceName,
            path: workspaceRootPath,
            branch: workspaceTargetBranch
          ) { message in
            Task { @MainActor in
              LogManager.shared.debug(message)
            }
          }
          orderedResults.append(workspaceResult)
        }

        let dependencyResults = await withTaskGroup(of: (Int, RepoSwitchResult).self) { group in
          let indexedRepos = Array(currentConfig.repos.enumerated())
          var nextIndex = 0
          var results: [(Int, RepoSwitchResult)] = []

          func addNextRepoIfNeeded() {
            guard nextIndex < indexedRepos.count else { return }

            let indexedRepo = indexedRepos[nextIndex]
            nextIndex += 1

            group.addTask {
              let repoService = ReposYAMLService()
              let result = repoService.updateRepo(indexedRepo.element, rootURL: rootURL) { message in
                Task { @MainActor in
                  LogManager.shared.debug(message)
                }
              }

              return (indexedRepo.offset, result)
            }
          }

          for _ in 0..<min(maxConcurrentCount, indexedRepos.count) {
            addNextRepoIfNeeded()
          }

          for await result in group {
            results.append(result)
            addNextRepoIfNeeded()
          }

          return results
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }
        }

        orderedResults.append(contentsOf: dependencyResults)
        return orderedResults
      }.value

      finishSwitch(results)
    }
  }

  public func openInXcode() {
    guard !projectPath.isEmpty else { return }

    if let workspace = findWorkspace(in: projectPath) {
      NSWorkspace.shared.openApplication(at: workspace, configuration: NSWorkspace.OpenConfiguration())
      return
    }

    for repo in repos where repo.isCloned {
      if let workspace = findWorkspace(in: repo.absolutePath) {
        NSWorkspace.shared.openApplication(at: workspace, configuration: NSWorkspace.OpenConfiguration())
        return
      }
    }
  }

  private func finishBranchLoad(_ result: BranchLoadResult) {
    isLoading = false
    currentTask = nil

    if let error = result.error {
      localBranches = []
      currentBranch = ""
      selectedBranch = ""
      LogManager.shared.error("读取主工程本地分支失败: \(error)")
      return
    }

    localBranches = result.branches
    currentBranch = result.currentBranch
    selectedBranch = result.branches.contains(result.currentBranch) ? result.currentBranch : (result.branches.first ?? "")
    saveLastProjectPath()

    if localBranches.isEmpty {
      LogManager.shared.error("主工程没有可用的本地分支")
    } else {
      LogManager.shared.success("已读取 \(localBranches.count) 个本地分支")
      LogManager.shared.info("主工程当前分支: \(currentBranch)")
    }
  }

  private func finishLoad(_ result: LoadResult) {
    isLoading = false
    currentTask = nil

    if let error = result.error {
      loadedConfig = nil
      repos = []
      rootPath = ""
      isConfirmEnabled = false
      LogManager.shared.error("加载 repos.yml 失败: \(error)")
      return
    }

    loadedConfig = result.config
    rootPath = result.rootPath
    repos = result.repos
    currentBranch = result.currentBranch.isEmpty ? selectedBranch : result.currentBranch
    isConfirmEnabled = !repos.isEmpty
    saveLastProjectPath()

    LogManager.shared.success("主工程已切换到 \(selectedBranch)")
    LogManager.shared.success("已读取 \(repos.count) 个仓库")
    LogManager.shared.info("仓库根目录: \(rootPath)")
    for repo in repos {
      LogManager.shared.info("\(repo.name)\t当前分支: \(repo.currentBranch) -> 目标分支: \(repo.targetBranch)")
    }
  }

  private func finishSwitch(_ results: [RepoSwitchResult]) {
    for result in results {
      if result.success {
        LogManager.shared.success("✓ \(result.name) 切换成功")
      } else {
        LogManager.shared.error("✗ \(result.name) 切换失败: \(result.error ?? "未知错误")")
      }
    }

    let failedCount = results.filter { !$0.success }.count
    if failedCount == 0 {
      LogManager.shared.success("========== 公版配置切换完成 ==========")
    } else {
      LogManager.shared.error("========== 公版配置切换完成，失败 \(failedCount) 个 ==========")
    }

    isSwitching = false
    isConfirmEnabled = true
    currentTask = nil
    loadData()
  }

  private func saveLastProjectPath() {
    UserDefaults.standard.set(projectPath, forKey: Self.lastProjectPathKey)
  }

  private func resetLoadedConfig() {
    loadedConfig = nil
    repos = []
    rootPath = ""
    isConfirmEnabled = false
  }

  private func findWorkspace(in path: String) -> URL? {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    guard let entries = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
      return nil
    }

    if let workspace = entries.first(where: { $0.pathExtension == "xcworkspace" }) {
      return workspace
    }
    return entries.first(where: { $0.pathExtension == "xcodeproj" })
  }

  private struct LoadResult: Sendable {
    let config: ReposConfig?
    let rootPath: String
    let repos: [RepoSwitchInfo]
    let currentBranch: String
    let error: String?
  }

  private struct BranchLoadResult: Sendable {
    let branches: [String]
    let currentBranch: String
    let error: String?
  }
}
