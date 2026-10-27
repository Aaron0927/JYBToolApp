import AppKit
import Foundation
import JYBLog

@Observable
@MainActor
public final class TagManagementViewModel {
  private static let lastProjectPathKey = "TagManagement.lastProjectPath"

  public var projectPath = ""
  public var repositories: [RepoSwitchInfo] = []
  public var selectedRepositoryID = ""
  public var tagName = ""
  public var tagMessage = ""
  public var isLoading = false
  public var isWorking = false
  public var errorMessage: String?
  public var statusMessage: String?
  public private(set) var pendingPushTagName: String?
  public private(set) var pendingPushRepositoryID: String?

  private var currentTask: Task<Void, Never>?

  public var isBusy: Bool {
    isLoading || isWorking
  }

  public init() {
    projectPath = UserDefaults.standard.string(forKey: Self.lastProjectPathKey) ?? ""
  }

  public var selectedRepository: RepoSwitchInfo? {
    repositories.first { $0.id == selectedRepositoryID }
  }

  public var canRetryPendingPush: Bool {
    pendingPushTagName != nil && pendingPushRepositoryID == selectedRepositoryID
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
    repositories = []
    selectedRepositoryID = ""
    pendingPushTagName = nil
    pendingPushRepositoryID = nil
    UserDefaults.standard.set(projectPath, forKey: Self.lastProjectPathKey)

    let path = projectPath
    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> RepositoryLoadResult in
        do {
          let loaded = try ReposYAMLService().loadRepoInfos(atProjectPath: path)
          let branch = ReposYAMLService().getCurrentBranch(at: loaded.rootPath) ?? ""
          let workspace = ReposYAMLService().makeWorkspaceRepoInfo(
            rootPath: loaded.rootPath,
            targetBranch: branch
          )
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
      self.selectedRepositoryID = (result.repositories.first(where: \.isCloned) ?? result.repositories.first)?.id ?? ""
    }
  }

  public func selectRepository(_ repositoryID: String) {
    guard selectedRepositoryID != repositoryID else { return }
    selectedRepositoryID = repositoryID
    errorMessage = nil
    statusMessage = nil
  }

  public func createAndPushTag(name: String, message: String) {
    perform(.createAndPush(
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      message: message.trimmingCharacters(in: .whitespacesAndNewlines)
    ))
  }

  public func retryPendingTagPush() {
    guard canRetryPendingPush, let pendingPushTagName else { return }
    perform(.push(name: pendingPushTagName))
  }

  private func perform(_ operation: TagOperation) {
    guard let repository = selectedRepository else { return }
    guard repository.isCloned else {
      errorMessage = "所选仓库尚未克隆，无法设置或推送 Tag。"
      return
    }

    currentTask?.cancel()
    isWorking = true
    errorMessage = nil
    statusMessage = nil
    let path = repository.absolutePath
    LogManager.shared.info("\(repository.name) · \(operation.startMessage)")

    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> TagActionResult in
        let service = ReposYAMLService()
        do {
          switch operation {
          case .createAndPush(let name, let message):
            try service.createAndPushTag(name, message: message, at: path)
          case .push(let name):
            try service.pushTag(name, at: path)
          }
          return TagActionResult(error: nil, createdLocalTag: nil)
        } catch let error as ReposYAMLServiceError {
          if case .tagPushFailed(let name, _) = error {
            return TagActionResult(error: error.localizedDescription, createdLocalTag: name)
          }
          return TagActionResult(error: error.localizedDescription, createdLocalTag: nil)
        } catch {
          return TagActionResult(error: error.localizedDescription, createdLocalTag: nil)
        }
      }.value

      guard let self else { return }
      self.isWorking = false
      self.currentTask = nil
      if let createdLocalTag = result.createdLocalTag {
        self.pendingPushTagName = createdLocalTag
        self.pendingPushRepositoryID = repository.id
      }
      if result.error == nil {
        self.statusMessage = operation.successMessage
        LogManager.shared.success("\(repository.name) · \(operation.successMessage)")
        if case .createAndPush = operation {
          self.tagName = ""
          self.tagMessage = ""
        } else {
          self.pendingPushTagName = nil
          self.pendingPushRepositoryID = nil
        }
      } else {
        self.errorMessage = result.error
        if let error = result.error {
          LogManager.shared.error("\(repository.name) · \(error)")
        }
      }
    }
  }

  private enum TagOperation: Sendable {
    case createAndPush(name: String, message: String)
    case push(name: String)

    var startMessage: String {
      switch self {
      case .createAndPush(let name, _): "开始设置并推送 Tag \(name)"
      case .push(let name): "开始重试推送 Tag \(name)"
      }
    }

    var successMessage: String {
      switch self {
      case .createAndPush(let name, _): "已设置并推送 Tag \(name)"
      case .push(let name): "已推送 Tag \(name)"
      }
    }
  }

  private struct RepositoryLoadResult: Sendable {
    let repositories: [RepoSwitchInfo]
    let error: String?
  }

  private struct TagActionResult: Sendable {
    let error: String?
    let createdLocalTag: String?
  }
}
