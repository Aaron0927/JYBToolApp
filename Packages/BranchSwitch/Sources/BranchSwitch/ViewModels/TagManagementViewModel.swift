import AppKit
import Foundation
import JYBLog

@Observable
@MainActor
public final class TagManagementViewModel {
  private static let lastProjectPathKey = "TagManagement.lastProjectPath"

  public var projectPath = ""
  public var repositories: [RepoSwitchInfo] = []
  public var selectedRepositoryIDs: Set<String> = []
  public private(set) var availableTags: [GitTagInfo] = []
  public var selectedTagName: String?
  public var tagName = ""
  public var tagMessage = ""
  public var isLoading = false
  public var isWorking = false
  public var errorMessage: String?
  public private(set) var tagLoadErrorMessage: String?
  public var statusMessage: String?
  public var operationProgress: String?
  public private(set) var operationResults: [TagRepositoryOperationResult] = []

  private var currentTask: Task<Void, Never>?

  public var isBusy: Bool {
    isLoading || isWorking
  }

  public var selectedRepositories: [RepoSwitchInfo] {
    repositories.filter { selectedRepositoryIDs.contains($0.id) }
  }

  public var selectedDeletionRepositories: [RepoSwitchInfo] {
    repositories.filter {
      $0.scope == .dependency && selectedRepositoryIDs.contains($0.id)
    }
  }

  public var deletionTargets: [RepoSwitchInfo] {
    guard let workspaceRepository = repositories.first(where: { $0.scope == .workspace }) else {
      return []
    }
    return [workspaceRepository] + selectedDeletionRepositories
  }

  public var areAllRepositoriesSelected: Bool {
    !repositories.isEmpty && selectedRepositoryIDs.count == repositories.count
  }

  public var canCreateTag: Bool {
    !selectedRepositories.isEmpty &&
      !tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public var canDeleteTag: Bool {
    guard let selectedTagName,
          availableTags.contains(where: { $0.name == selectedTagName }),
          let workspaceRepository = repositories.first(where: { $0.scope == .workspace })
    else { return false }
    return workspaceRepository.isCloned && !isBusy
  }

  public init() {
    projectPath = UserDefaults.standard.string(forKey: Self.lastProjectPathKey) ?? ""
  }

  public func selectProject() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false

    if panel.runModal() == .OK, let url = panel.url {
      projectPath = url.path
      loadRepositories()
    }
  }

  public func loadRepositories() {
    guard !projectPath.isEmpty else {
      errorMessage = "请选择包含 fastlane/repos.yml 的主工程目录。"
      return
    }

    currentTask?.cancel()
    isLoading = true
    errorMessage = nil
    statusMessage = nil
    operationProgress = nil
    operationResults = []
    repositories = []
    selectedRepositoryIDs = []
    availableTags = []
    selectedTagName = nil
    tagLoadErrorMessage = nil
    UserDefaults.standard.set(projectPath, forKey: Self.lastProjectPathKey)

    let path = projectPath
    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> RepositoryLoadResult in
        do {
          let service = ReposYAMLService()
          let loaded = try service.loadRepoInfos(atProjectPath: path)
          let branch = service.getCurrentBranch(at: path) ?? ""
          let workspace = service.makeWorkspaceRepoInfo(rootPath: path, targetBranch: branch)
          let tagResult = Self.readTags(at: path)
          return RepositoryLoadResult(
            repositories: [workspace] + loaded.infos,
            tags: tagResult.tags,
            error: nil,
            tagError: tagResult.error
          )
        } catch {
          return RepositoryLoadResult(repositories: [], tags: [], error: error.localizedDescription, tagError: nil)
        }
      }.value

      guard let self else { return }
      self.isLoading = false
      self.currentTask = nil
      self.repositories = result.repositories
      self.selectedRepositoryIDs = Set(result.repositories.map(\.id))
      self.errorMessage = result.error
      self.availableTags = result.tags
      self.tagLoadErrorMessage = result.tagError
    }
  }

  public func reloadTags() {
    guard !projectPath.isEmpty,
          repositories.contains(where: { $0.scope == .workspace && $0.isCloned })
    else {
      tagLoadErrorMessage = "请先读取一个有效的主仓库。"
      return
    }

    currentTask?.cancel()
    isLoading = true
    tagLoadErrorMessage = nil
    let path = projectPath
    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) {
        Self.readTags(at: path)
      }.value
      guard let self else { return }
      self.isLoading = false
      self.currentTask = nil
      self.availableTags = result.tags
      self.tagLoadErrorMessage = result.error
      if let selectedTagName = self.selectedTagName,
         !result.tags.contains(where: { $0.name == selectedTagName }) {
        self.selectedTagName = nil
      }
    }
  }

  public func setRepository(_ repositoryID: String, selected: Bool) {
    guard !isBusy else { return }
    if selected {
      selectedRepositoryIDs.insert(repositoryID)
    } else {
      selectedRepositoryIDs.remove(repositoryID)
    }
    errorMessage = nil
  }

  public func setAllRepositoriesSelected(_ selected: Bool) {
    guard !isBusy else { return }
    selectedRepositoryIDs = selected ? Set(repositories.map(\.id)) : []
    errorMessage = nil
  }

  public func createAndPushTag(
    name: String,
    message: String,
    repositoryIDs: Set<String>,
    pushToRemote: Bool = true
  ) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
    let targets = repositories.filter { repositoryIDs.contains($0.id) }
    guard !targets.isEmpty else {
      errorMessage = "请至少选择一个仓库。"
      return
    }
    guard !name.isEmpty else {
      errorMessage = "Tag 名称不能为空。"
      return
    }

    currentTask?.cancel()
    isWorking = true
    errorMessage = nil
    statusMessage = nil
    operationResults = []

    currentTask = Task { @MainActor [weak self] in
      guard let self else { return }
      var createdRepositories: [RepoSwitchInfo] = []
      for (index, repository) in targets.enumerated() {
        self.operationProgress = "正在创建 \(repository.name) 的 Tag（\(index + 1)/\(targets.count)）…"
        let result = await Self.createTag(
          name,
          message: message,
          in: repository
        )
        self.operationResults.append(result)
        Self.log(result)
        if result.status == .success {
          createdRepositories.append(repository)
        }
      }

      self.isWorking = false
      self.currentTask = nil
      self.operationProgress = nil
      if !createdRepositories.isEmpty {
        self.tagName = ""
        self.tagMessage = ""
      }
      self.statusMessage = Self.summary(for: self.operationResults, pushToRemote: pushToRemote)
      LogManager.shared.info("Tag 批量处理完成：\(self.statusMessage ?? "")")
      if pushToRemote {
        Self.pushTagsInBackground(name, repositories: createdRepositories)
      }
    }
  }

  public func deleteTag(_ name: String, dependencyRepositoryIDs: Set<String>) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      errorMessage = "请选择要删除的 Tag。"
      return
    }
    guard let workspaceRepository = repositories.first(where: { $0.scope == .workspace }) else {
      errorMessage = "主仓库尚未读取。"
      return
    }
    guard workspaceRepository.isCloned else {
      errorMessage = "主仓库不是有效的 Git 仓库。"
      return
    }
    guard availableTags.contains(where: { $0.name == name }) else {
      errorMessage = "所选 Tag 已不在主仓库列表中，请重新读取 Tag。"
      return
    }

    let dependencies = repositories.filter {
      $0.scope == .dependency && dependencyRepositoryIDs.contains($0.id)
    }
    let targets = [workspaceRepository] + dependencies

    currentTask?.cancel()
    isWorking = true
    errorMessage = nil
    statusMessage = nil
    operationResults = []

    currentTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for (index, repository) in targets.enumerated() {
        self.operationProgress = "正在删除 \(repository.name) 的 Tag（\(index + 1)/\(targets.count)）…"
        let result = await Self.deleteTag(name, in: repository)
        self.operationResults.append(result)
        Self.log(result)
      }

      let refreshedTags = await Task.detached(priority: .utility) {
        Self.readTags(at: workspaceRepository.absolutePath)
      }.value
      self.availableTags = refreshedTags.tags
      self.tagLoadErrorMessage = refreshedTags.error
      if let selectedTagName = self.selectedTagName,
         !refreshedTags.tags.contains(where: { $0.name == selectedTagName }) {
        self.selectedTagName = nil
      }

      self.isWorking = false
      self.currentTask = nil
      self.operationProgress = nil
      self.statusMessage = Self.deleteSummary(for: self.operationResults)
      LogManager.shared.info("Tag 批量删除完成：\(self.statusMessage ?? "")")
    }
  }

  public func retryTagPush(for repositoryID: String) {
    guard !isBusy,
          let resultIndex = operationResults.firstIndex(where: {
            $0.repositoryID == repositoryID && $0.status == .pushFailed
          }),
          let repository = repositories.first(where: { $0.id == repositoryID })
    else { return }

    let failedResult = operationResults[resultIndex]
    isWorking = true
    errorMessage = nil
    statusMessage = nil
    operationProgress = "正在重试推送 \(failedResult.tagName) 到 \(repository.name)…"
    LogManager.shared.info("\(repository.name) · 开始重试推送 Tag \(failedResult.tagName)")

    currentTask = Task { @MainActor [weak self] in
      let result = await Self.retryTagPush(failedResult.tagName, in: repository)
      guard let self else { return }
      if let resultIndex = self.operationResults.firstIndex(where: { $0.repositoryID == repositoryID }) {
        self.operationResults[resultIndex] = result
      }
      self.isWorking = false
      self.currentTask = nil
      self.operationProgress = nil
      self.statusMessage = result.message
      Self.log(result)
    }
  }

  private static func createTag(
    _ name: String,
    message: String,
    in repository: RepoSwitchInfo
  ) async -> TagRepositoryOperationResult {
    guard repository.isCloned else {
      return TagRepositoryOperationResult(
        repositoryID: repository.id,
        repositoryName: repository.name,
        tagName: name,
        status: .failed,
        message: "仓库尚未克隆。"
      )
    }

    return await Task.detached(priority: .userInitiated) {
      do {
        let service = ReposYAMLService()
        try service.createTag(name, message: message, at: repository.absolutePath)
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: .success,
          message: "已在当前 HEAD 创建本地 Tag。"
        )
      } catch {
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: .failed,
          message: error.localizedDescription
        )
      }
    }.value
  }

  private static func deleteTag(
    _ name: String,
    in repository: RepoSwitchInfo
  ) async -> TagRepositoryOperationResult {
    guard repository.isCloned else {
      return TagRepositoryOperationResult(
        repositoryID: repository.id,
        repositoryName: repository.name,
        tagName: name,
        status: .failed,
        message: "仓库尚未克隆。"
      )
    }

    return await Task.detached(priority: .userInitiated) {
      do {
        let service = ReposYAMLService()
        let snapshot = try service.loadTags(at: repository.absolutePath)
        guard let tag = snapshot.tags.first(where: { $0.name == name }) else {
          return TagRepositoryOperationResult(
            repositoryID: repository.id,
            repositoryName: repository.name,
            tagName: name,
            status: .skipped,
            message: "该仓库没有此 Tag，已跳过。"
          )
        }

        var deletedLocations = [String]()
        var failures = [String]()
        if tag.localObjectID != nil {
          do {
            try service.deleteLocalTag(name, at: repository.absolutePath)
            deletedLocations.append("本地")
          } catch {
            failures.append("本地删除失败：\(error.localizedDescription)")
          }
        }
        if tag.remoteObjectID != nil {
          do {
            try service.deleteRemoteTag(name, at: repository.absolutePath)
            deletedLocations.append("远程")
          } catch {
            failures.append("远程删除失败：\(error.localizedDescription)")
          }
        }

        let locationSummary = deletedLocations.joined(separator: "和")
        if failures.isEmpty {
          return TagRepositoryOperationResult(
            repositoryID: repository.id,
            repositoryName: repository.name,
            tagName: name,
            status: .success,
            message: "已删除\(locationSummary) Tag。"
          )
        }
        let partialMessage = deletedLocations.isEmpty ? "" : "已删除\(locationSummary) Tag；"
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: .failed,
          message: "\(partialMessage)\(failures.joined(separator: "；"))"
        )
      } catch {
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: .failed,
          message: error.localizedDescription
        )
      }
    }.value
  }

  private static func pushTagsInBackground(_ name: String, repositories: [RepoSwitchInfo]) {
    for repository in repositories {
      Task.detached(priority: .utility) {
        await MainActor.run {
          LogManager.shared.info("\(repository.name) · 开始后台推送 Tag \(name) 到 origin")
        }
        do {
          try ReposYAMLService().pushTag(name, at: repository.absolutePath)
          await MainActor.run {
            LogManager.shared.success("\(repository.name) · Tag \(name) 已推送到 origin")
          }
        } catch {
          let reason = error.localizedDescription
          await MainActor.run {
            LogManager.shared.error("\(repository.name) · Tag \(name) 后台推送失败，本地 Tag 已保留：\(reason)")
          }
        }
      }
    }
  }

  private static func retryTagPush(_ name: String, in repository: RepoSwitchInfo) async -> TagRepositoryOperationResult {
    await Task.detached(priority: .userInitiated) {
      do {
        try ReposYAMLService().pushTag(name, at: repository.absolutePath)
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: .success,
          message: "已推送到 origin。"
        )
      } catch {
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: .pushFailed,
          message: "本地 Tag 已保留，推送重试失败：\(error.localizedDescription)"
        )
      }
    }.value
  }

  private static func log(_ result: TagRepositoryOperationResult) {
    let message = "\(result.repositoryName) · Tag \(result.tagName)：\(result.message)"
    switch result.status {
    case .success:
      LogManager.shared.success(message)
    case .skipped:
      LogManager.shared.info(message)
    case .pushFailed:
      LogManager.shared.warning(message)
    case .failed:
      LogManager.shared.error(message)
    }
  }

  private static func summary(for results: [TagRepositoryOperationResult], pushToRemote: Bool) -> String {
    let succeeded = results.filter { $0.status == .success }.count
    let failed = results.filter { $0.status == .failed }.count
    let pushNote = pushToRemote && succeeded > 0 ? "已开始后台推送，结果见执行日志。" : ""
    return "本地 Tag 创建完成：成功 \(succeeded)，失败 \(failed)。\(pushNote)"
  }

  private static func deleteSummary(for results: [TagRepositoryOperationResult]) -> String {
    let deleted = results.filter { $0.status == .success }.count
    let skipped = results.filter { $0.status == .skipped }.count
    let failed = results.filter { $0.status == .failed }.count
    return "Tag 删除完成：成功 \(deleted)，跳过 \(skipped)，失败 \(failed)。"
  }

  nonisolated private static func readTags(at path: String) -> TagLoadResult {
    do {
      let snapshot = try ReposYAMLService().loadTags(at: path)
      return TagLoadResult(tags: snapshot.tags, error: nil)
    } catch {
      return TagLoadResult(tags: [], error: error.localizedDescription)
    }
  }

  private struct RepositoryLoadResult: Sendable {
    let repositories: [RepoSwitchInfo]
    let tags: [GitTagInfo]
    let error: String?
    let tagError: String?
  }

  private struct TagLoadResult: Sendable {
    let tags: [GitTagInfo]
    let error: String?
  }
}
