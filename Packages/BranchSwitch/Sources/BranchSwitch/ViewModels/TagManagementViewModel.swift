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
  public var tagName = ""
  public var tagMessage = ""
  public var isLoading = false
  public var isWorking = false
  public var errorMessage: String?
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

  public var areAllRepositoriesSelected: Bool {
    !repositories.isEmpty && selectedRepositoryIDs.count == repositories.count
  }

  public var canCreateAndPushTag: Bool {
    !selectedRepositories.isEmpty &&
      !tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !tagMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    UserDefaults.standard.set(projectPath, forKey: Self.lastProjectPathKey)

    let path = projectPath
    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> RepositoryLoadResult in
        do {
          let service = ReposYAMLService()
          let loaded = try service.loadRepoInfos(atProjectPath: path)
          let branch = service.getCurrentBranch(at: loaded.rootPath) ?? ""
          let workspace = service.makeWorkspaceRepoInfo(rootPath: loaded.rootPath, targetBranch: branch)
          return RepositoryLoadResult(repositories: [workspace] + loaded.infos, error: nil)
        } catch {
          return RepositoryLoadResult(repositories: [], error: error.localizedDescription)
        }
      }.value

      guard let self else { return }
      self.isLoading = false
      self.currentTask = nil
      self.repositories = result.repositories
      self.errorMessage = result.error
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

  public func createAndPushTag(name: String, message: String, repositoryIDs: Set<String>) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
    let targets = repositories.filter { repositoryIDs.contains($0.id) }
    guard !targets.isEmpty else {
      errorMessage = "请至少选择一个仓库。"
      return
    }
    guard !name.isEmpty, !message.isEmpty else {
      errorMessage = "Tag 名称和附注说明不能为空。"
      return
    }

    currentTask?.cancel()
    isWorking = true
    errorMessage = nil
    statusMessage = nil
    operationResults = []

    currentTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for (index, repository) in targets.enumerated() {
        self.operationProgress = "正在处理 \(repository.name)（\(index + 1)/\(targets.count)）…"
        let result = await Self.createAndPushTag(name, message: message, in: repository)
        self.operationResults.append(result)
        Self.log(result)
      }

      self.isWorking = false
      self.currentTask = nil
      self.operationProgress = nil
      if self.operationResults.contains(where: { $0.status != .failed }) {
        self.tagName = ""
        self.tagMessage = ""
      }
      self.statusMessage = Self.summary(for: self.operationResults)
      LogManager.shared.info("Tag 批量处理完成：\(self.statusMessage ?? "")")
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

  private static func createAndPushTag(
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
        try ReposYAMLService().createAndPushTag(name, message: message, at: repository.absolutePath)
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: .success,
          message: "已在当前 HEAD 创建并推送到 origin。"
        )
      } catch let error as ReposYAMLServiceError {
        let status: TagRepositoryOperationStatus
        if case .tagPushFailed = error {
          status = .pushFailed
        } else {
          status = .failed
        }
        return TagRepositoryOperationResult(
          repositoryID: repository.id,
          repositoryName: repository.name,
          tagName: name,
          status: status,
          message: error.localizedDescription
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
    case .pushFailed:
      LogManager.shared.warning(message)
    case .failed:
      LogManager.shared.error(message)
    }
  }

  private static func summary(for results: [TagRepositoryOperationResult]) -> String {
    let succeeded = results.filter { $0.status == .success }.count
    let pushFailed = results.filter { $0.status == .pushFailed }.count
    let failed = results.filter { $0.status == .failed }.count
    return "处理完成：成功 \(succeeded)，待重试推送 \(pushFailed)，失败 \(failed)。"
  }

  private struct RepositoryLoadResult: Sendable {
    let repositories: [RepoSwitchInfo]
    let error: String?
  }
}
