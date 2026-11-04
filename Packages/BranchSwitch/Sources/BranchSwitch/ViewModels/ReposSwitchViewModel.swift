//
//  ReposSwitchViewModel.swift
//  BranchSwitch
//

import AppKit
import Foundation
import JYBLog

public enum RepoSwitchTargetMode: String, CaseIterable, Sendable {
  case branch
  case tag

  public var title: String {
    switch self {
    case .branch: "分支"
    case .tag: "Tag"
    }
  }
}

@Observable
@MainActor
public final class ReposSwitchViewModel {
  private static let lastProjectPathKey = "ReposSwitch.lastProjectPath"
  private static let maxConcurrentRepoSwitchCount = 6

  public var projectPath: String = ""
  public var targetMode: RepoSwitchTargetMode = .branch {
    didSet {
      guard targetMode != oldValue else { return }
      currentTask?.cancel()
      resetLoadedConfig()
      availableTags = []
      selectedTagName = nil
      tagLoadErrorMessage = nil
      isTagPreviewLoaded = false
    }
  }
  public var configPath: String = ""
  public var rootPath: String = ""
  public var localBranches: [String] = []
  public var currentBranch: String = ""
  public var selectedBranch: String = ""
  public var availableTags: [GitTagInfo] = []
  public var selectedTagName: String?
  public var tagLoadErrorMessage: String?
  public var isTagPreviewLoaded = false
  public var repos: [RepoSwitchInfo] = []
  public var isLoading = false
  public var isSwitching = false
  public var isPulling = false
  public var isConfirmEnabled = false
  public var isPullPreviewLoaded = false
  public var loadErrorMessage: String?
  public var pullSummary: String?
  public var operationSummary: String?
  public var operationResults: [String: String] = [:]
  public var operationDetails: [String: String] = [:]
  public var selectedPullRepositoryIDs: Set<String> = []

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

  public var isBusy: Bool {
    isLoading || isSwitching || isPulling
  }

  public var displayedRepos: [RepoSwitchInfo] {
    guard targetMode == .tag else { return repos }
    let targetTag = selectedTagName ?? "选择 Tag"
    return repos.map { repo in
      RepoSwitchInfo(
        name: repo.name,
        path: repo.path,
        absolutePath: repo.absolutePath,
        currentBranch: repo.currentBranch,
        targetBranch: targetTag,
        isCloned: repo.isCloned,
        scope: repo.scope
      )
    }
  }

  public var canConfirmSwitch: Bool {
    guard !isBusy, !repos.isEmpty, loadedConfig != nil else { return false }
    switch targetMode {
    case .branch:
      return isConfirmEnabled
    case .tag:
      guard isTagPreviewLoaded,
            let selectedTagName
      else { return false }
      return availableTags.contains { $0.name == selectedTagName }
    }
  }

  public var isAllPullRepositoriesSelected: Bool {
    !repos.isEmpty && repos.allSatisfy { selectedPullRepositoryIDs.contains($0.id) }
  }

  public var selectedPullRepositoryCount: Int {
    repos.filter { selectedPullRepositoryIDs.contains($0.id) }.count
  }

  public func setPullRepository(_ repositoryID: String, selected: Bool) {
    if selected {
      selectedPullRepositoryIDs.insert(repositoryID)
    } else {
      selectedPullRepositoryIDs.remove(repositoryID)
    }
  }

  public func toggleAllPullRepositories() {
    if isAllPullRepositoriesSelected {
      selectedPullRepositoryIDs = []
    } else {
      selectedPullRepositoryIDs = Set(repos.map(\.id))
    }
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
    isPullPreviewLoaded = false
    loadErrorMessage = nil
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

  public func loadTagSwitchData() {
    guard !projectPath.isEmpty else { return }
    currentTask?.cancel()
    isLoading = true
    isConfirmEnabled = false
    isTagPreviewLoaded = false
    loadErrorMessage = nil
    tagLoadErrorMessage = nil
    configPath = service.configURL(forProjectPath: projectPath).path
    LogManager.shared.info("正在读取主仓库配置和 Tag 列表…")

    let currentProjectPath = projectPath
    currentTask = Task { @MainActor in
      let result = await Task.detached { () -> TagSwitchLoadResult in
        do {
          let service = ReposYAMLService()
          let loaded = try service.loadRepoInfos(atProjectPath: currentProjectPath)
          let currentBranch = service.getCurrentBranch(at: currentProjectPath) ?? ""
          let workspaceInfo = service.makeWorkspaceRepoInfo(
            rootPath: currentProjectPath,
            targetBranch: "选择 Tag"
          )
          let tagResult: (tags: [GitTagInfo], error: String?)
          do {
            tagResult = (try service.loadTags(at: currentProjectPath).tags, nil)
          } catch {
            tagResult = ([], error.localizedDescription)
          }
          return TagSwitchLoadResult(
            config: loaded.config,
            rootPath: loaded.rootPath,
            repos: [workspaceInfo] + loaded.infos,
            tags: tagResult.tags,
            currentBranch: currentBranch,
            error: nil,
            tagError: tagResult.error
          )
        } catch {
          return TagSwitchLoadResult(
            config: nil,
            rootPath: "",
            repos: [],
            tags: [],
            currentBranch: "",
            error: error.localizedDescription,
            tagError: nil
          )
        }
      }.value

      finishTagSwitchLoad(result)
    }
  }

  public func loadPullPreview() {
    guard !projectPath.isEmpty else { return }
    currentTask?.cancel()
    isLoading = true
    isConfirmEnabled = false
    isPullPreviewLoaded = false
    loadErrorMessage = nil
    configPath = service.configURL(forProjectPath: projectPath).path

    let currentProjectPath = projectPath
    currentTask = Task { @MainActor in
      let result = await Task.detached { () -> PullPreviewResult in
        do {
          let service = ReposYAMLService()
          let loaded = try service.loadRepoInfos(atProjectPath: currentProjectPath)
          let workspaceBranch = service.getCurrentBranch(at: loaded.rootPath) ?? ""
          let workspaceInfo = service.makeWorkspaceRepoInfo(
            rootPath: loaded.rootPath,
            targetBranch: workspaceBranch
          )
          return PullPreviewResult(
            config: loaded.config,
            rootPath: loaded.rootPath,
            repos: [workspaceInfo] + loaded.infos,
            currentBranch: workspaceBranch,
            error: nil
          )
        } catch {
          return PullPreviewResult(
            config: nil,
            rootPath: "",
            repos: [],
            currentBranch: "",
            error: error.localizedDescription
          )
        }
      }.value

      finishPullPreview(result)
    }
  }

  public func switchRepos() {
    guard let loadedConfig, !projectPath.isEmpty else { return }
    if targetMode == .tag {
      switchReposToTag(using: loadedConfig)
      return
    }
    currentTask?.cancel()
    isSwitching = true
    isConfirmEnabled = false
    operationSummary = nil
    operationResults = [:]
    operationDetails = [:]
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

      finishSwitch(results, targetMode: .branch, targetName: workspaceTargetBranch)
    }
  }

  private func switchReposToTag(using config: ReposConfig) {
    guard let selectedTagName,
          availableTags.contains(where: { $0.name == selectedTagName }),
          isTagPreviewLoaded
    else { return }

    currentTask?.cancel()
    isSwitching = true
    isConfirmEnabled = false
    operationSummary = nil
    operationResults = [:]
    operationDetails = [:]
    LogManager.shared.info("========== 开始公版仓库 Tag 切换：\(selectedTagName) ==========")
    LogManager.shared.info("主仓库固定参与；依赖仓库并发切换，最大并发数：\(Self.maxConcurrentRepoSwitchCount)")

    let tag = selectedTagName
    let projectDirectory = projectPath
    let currentConfigURL = service.configURL(forProjectPath: projectPath)
    let maxConcurrentCount = Self.maxConcurrentRepoSwitchCount
    currentTask = Task { @MainActor in
      let results = await Task.detached { () async -> [RepoSwitchResult] in
        let service = ReposYAMLService()
        let rootURL = service.rootURL(for: config, configURL: currentConfigURL)
        let workspaceName = URL(fileURLWithPath: projectDirectory, isDirectory: true)
          .standardizedFileURL
          .lastPathComponent
        let workspaceResult = service.updateExistingRepoToTag(
          name: workspaceName,
          path: projectDirectory,
          tag: tag
        ) { message in
          Task { @MainActor in
            LogManager.shared.debug(message)
          }
        }

        let dependencyResults = await withTaskGroup(of: (Int, RepoSwitchResult).self) { group in
          let indexedRepos = Array(config.repos.enumerated())
          var nextIndex = 0
          var results: [(Int, RepoSwitchResult)] = []

          func addNextRepoIfNeeded() {
            guard nextIndex < indexedRepos.count else { return }
            let indexedRepo = indexedRepos[nextIndex]
            nextIndex += 1
            group.addTask {
              let repoService = ReposYAMLService()
              let result = repoService.updateRepoToTag(
                indexedRepo.element,
                rootURL: rootURL,
                tag: tag
              ) { message in
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
          return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        return [workspaceResult] + dependencyResults
      }.value

      finishSwitch(results, targetMode: .tag, targetName: tag)
    }
  }

  public func updateSelectedRepositories() {
    let selectedRepositories = repos.filter { selectedPullRepositoryIDs.contains($0.id) }
    guard !projectPath.isEmpty, isPullPreviewLoaded, !selectedRepositories.isEmpty else { return }
    currentTask?.cancel()
    isPulling = true
    pullSummary = nil
    operationSummary = nil
    operationResults = [:]
    operationDetails = [:]
    LogManager.shared.info("========== 开始更新已选择的公版仓库（\(selectedRepositories.count) 个） ==========")

    currentTask = Task { @MainActor in
      let result = await Task.detached { () -> PullResult in
        let service = ReposYAMLService()
        let results = service.updateRepositories(selectedRepositories) { message in
          Task { @MainActor in
            LogManager.shared.debug(message)
          }
        }
        return PullResult(results: results)
      }.value

      finishPull(result)
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
      loadErrorMessage = error
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
      loadErrorMessage = error
      loadedConfig = nil
      repos = []
      rootPath = ""
      isConfirmEnabled = false
      LogManager.shared.error("加载 repos.yml 失败: \(error)")
      return
    }

    loadedConfig = result.config
    loadErrorMessage = nil
    rootPath = result.rootPath
    repos = result.repos
    currentBranch = result.currentBranch.isEmpty ? selectedBranch : result.currentBranch
    isConfirmEnabled = !repos.isEmpty
    isPullPreviewLoaded = false
    saveLastProjectPath()

    LogManager.shared.success("主工程已切换到 \(selectedBranch)")
    LogManager.shared.success("已读取 \(repos.count) 个仓库")
    LogManager.shared.info("仓库根目录: \(rootPath)")
    for repo in repos {
      LogManager.shared.info("\(repo.name)\t当前分支: \(repo.currentBranch) -> 目标分支: \(repo.targetBranch)")
    }
  }

  private func finishTagSwitchLoad(_ result: TagSwitchLoadResult) {
    isLoading = false
    currentTask = nil

    if let error = result.error {
      loadedConfig = nil
      repos = []
      rootPath = ""
      availableTags = []
      isConfirmEnabled = false
      isTagPreviewLoaded = false
      loadErrorMessage = error
      tagLoadErrorMessage = nil
      LogManager.shared.error("读取 Tag 切换所需的仓库配置失败：\(error)")
      return
    }

    loadedConfig = result.config
    loadErrorMessage = nil
    rootPath = result.rootPath
    repos = result.repos
    availableTags = result.tags
    tagLoadErrorMessage = result.tagError
    currentBranch = result.currentBranch
    isConfirmEnabled = !repos.isEmpty
    isTagPreviewLoaded = !repos.isEmpty
    isPullPreviewLoaded = false
    if let selectedTagName,
       !availableTags.contains(where: { $0.name == selectedTagName }) {
      self.selectedTagName = nil
    }
    saveLastProjectPath()

    LogManager.shared.success("已读取主仓库和 \(result.repos.count - 1) 个依赖仓库")
    LogManager.shared.info("主仓库当前分支：\(currentBranch.isEmpty ? "未知" : currentBranch)")
    LogManager.shared.info("主仓库可用 Tag：\(availableTags.count)")
    if let tagError = result.tagError {
      LogManager.shared.error("读取主仓库 Tag 失败：\(tagError)")
    }
  }

  private func finishPullPreview(_ result: PullPreviewResult) {
    isLoading = false
    currentTask = nil

    if let error = result.error {
      loadedConfig = nil
      repos = []
      rootPath = ""
      loadErrorMessage = error
      isPullPreviewLoaded = false
      selectedPullRepositoryIDs = []
      LogManager.shared.error("读取仓库更新范围失败: \(error)")
      return
    }

    loadedConfig = result.config
    loadErrorMessage = nil
    rootPath = result.rootPath
    repos = result.repos
    selectedPullRepositoryIDs = Set(repos.map(\.id))
    currentBranch = result.currentBranch
    isPullPreviewLoaded = !repos.isEmpty
    pullSummary = nil
    operationSummary = nil
    operationResults = [:]
    operationDetails = [:]
    LogManager.shared.success("已读取 \(repos.count) 个仓库")
    LogManager.shared.info("仓库根目录: \(rootPath)")
  }

  private func finishSwitch(
    _ results: [RepoSwitchResult],
    targetMode: RepoSwitchTargetMode,
    targetName: String
  ) {
    let successCount = results.filter { $0.status == .success }.count
    let skippedCount = results.filter { $0.status == .skipped }.count
    let failedCount = results.filter { $0.status == .failed }.count
    operationResults = Dictionary(uniqueKeysWithValues: results.map { result in
      let status: String
      switch result.status {
      case .success: status = "成功"
      case .skipped: status = "跳过"
      case .failed: status = "失败"
      }
      return (result.name, status)
    })
    operationDetails = Dictionary(uniqueKeysWithValues: results.filter { $0.status != .success }.compactMap { result in
      result.error.map { (result.name, $0) }
    })

    for result in results {
      switch result.status {
      case .success:
        LogManager.shared.success("✓ \(result.name) 切换成功")
      case .skipped:
        LogManager.shared.info("- \(result.name) 切换已跳过：\(result.error ?? "Tag 不存在")")
      case .failed:
        LogManager.shared.error("✗ \(result.name) 切换失败: \(result.error ?? "未知错误")")
      }
    }

    let targetDescription = targetMode == .tag ? "Tag「\(targetName)」" : "分支「\(targetName)」"
    operationSummary = "\(targetDescription) 切换结果：成功 \(successCount)，跳过 \(skippedCount)，失败 \(failedCount)"
    if failedCount == 0 {
      if skippedCount == 0 {
        LogManager.shared.success("========== 公版仓库 \(targetDescription) 切换完成 ==========")
      } else {
        LogManager.shared.warning("========== 公版仓库 \(targetDescription) 切换完成，跳过 \(skippedCount) 个 ==========")
      }
    } else {
      LogManager.shared.error("========== 公版仓库 \(targetDescription) 切换完成，失败 \(failedCount) 个 ==========")
    }

    isSwitching = false
    isConfirmEnabled = true
    currentTask = nil
    if targetMode == .branch {
      loadData()
    }
  }

  private func finishPull(_ result: PullResult) {
    defer {
      isPulling = false
      currentTask = nil
    }

    let repositoryByPath = Dictionary(uniqueKeysWithValues: repos.map { ($0.absolutePath, $0) })
    operationResults = Dictionary(uniqueKeysWithValues: result.results.map { result in
      let title: String
      switch result.status {
      case .success: title = "成功"
      case .skipped: title = "跳过"
      case .failed: title = "失败"
      }
      return (repositoryByPath[result.path]?.id ?? result.path, title)
    })
    operationDetails = Dictionary(uniqueKeysWithValues: result.results.compactMap { result in
      result.message.map { (repositoryByPath[result.path]?.id ?? result.path, $0) }
    })
    for repo in result.results {
      switch repo.status {
      case .success:
        let stashNote = repo.hadAutoStash ? "，已恢复本地改动" : ""
        LogManager.shared.success("✓ \(repo.name) 更新成功\(stashNote)")
      case .skipped:
        LogManager.shared.info("- \(repo.name) 已跳过：\(repo.message ?? "未知原因")")
      case .failed:
        LogManager.shared.error("✗ \(repo.name) 更新失败：\(repo.message ?? "未知错误")")
      }
    }

    let successCount = result.results.filter { $0.status == .success }.count
    let skippedCount = result.results.filter { $0.status == .skipped }.count
    let failedCount = result.results.filter { $0.status == .failed }.count
    pullSummary = "最近更新：成功 \(successCount)，跳过 \(skippedCount)，失败 \(failedCount)"
    operationSummary = pullSummary
    loadErrorMessage = nil
    LogManager.shared.info("========== \(pullSummary ?? "更新完成") ==========")
  }

  private func saveLastProjectPath() {
    UserDefaults.standard.set(projectPath, forKey: Self.lastProjectPathKey)
  }

  private func resetLoadedConfig() {
    loadedConfig = nil
    repos = []
    rootPath = ""
    isConfirmEnabled = false
    isPullPreviewLoaded = false
    isTagPreviewLoaded = false
    availableTags = []
    selectedTagName = nil
    tagLoadErrorMessage = nil
    loadErrorMessage = nil
    operationSummary = nil
    operationResults = [:]
    operationDetails = [:]
    selectedPullRepositoryIDs = []
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

  private struct TagSwitchLoadResult: Sendable {
    let config: ReposConfig?
    let rootPath: String
    let repos: [RepoSwitchInfo]
    let tags: [GitTagInfo]
    let currentBranch: String
    let error: String?
    let tagError: String?
  }

  private struct BranchLoadResult: Sendable {
    let branches: [String]
    let currentBranch: String
    let error: String?
  }

  private struct PullResult: Sendable {
    let results: [RepoPullResult]
  }

  private struct PullPreviewResult: Sendable {
    let config: ReposConfig?
    let rootPath: String
    let repos: [RepoSwitchInfo]
    let currentBranch: String
    let error: String?
  }
}
