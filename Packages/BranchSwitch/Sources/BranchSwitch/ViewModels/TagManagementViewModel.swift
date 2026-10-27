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
  public var tags: [GitTagInfo] = []
  public var hasOrigin = false
  public var tagName = ""
  public var tagMessage = ""
  public var isLoading = false
  public var isWorking = false
  public var errorMessage: String?
  public var statusMessage: String?

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
    tags = []
    repositories = []
    selectedRepositoryID = ""
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
      guard let firstRepository = result.repositories.first(where: \.isCloned) ?? result.repositories.first else {
        return
      }
      self.selectedRepositoryID = firstRepository.id
      self.loadTags()
    }
  }

  public func selectRepository(_ repositoryID: String) {
    guard selectedRepositoryID != repositoryID else { return }
    selectedRepositoryID = repositoryID
    tags = []
    hasOrigin = false
    statusMessage = nil
    loadTags()
  }

  public func loadTags() {
    guard let repository = selectedRepository else { return }
    guard repository.isCloned else {
      tags = []
      hasOrigin = false
      errorMessage = "所选路径不是可用的 Git 仓库。"
      return
    }

    currentTask?.cancel()
    isLoading = true
    errorMessage = nil
    let path = repository.absolutePath

    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> TagLoadResult in
        do {
          return TagLoadResult(snapshot: try ReposYAMLService().loadTags(at: path), error: nil)
        } catch {
          return TagLoadResult(snapshot: nil, error: error.localizedDescription)
        }
      }.value

      guard let self else { return }
      self.isLoading = false
      self.currentTask = nil
      if let snapshot = result.snapshot {
        self.tags = snapshot.tags
        self.hasOrigin = snapshot.hasOrigin
        self.errorMessage = nil
        self.statusMessage = "已读取 \(snapshot.tags.count) 个 Tag"
      } else {
        self.errorMessage = result.error
      }
    }
  }

  public func createTag(name: String, message: String) {
    perform(.create(
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      message: message.trimmingCharacters(in: .whitespacesAndNewlines)
    ))
  }

  public func pushTag(_ name: String) {
    perform(.push(name))
  }

  public func deleteLocalTag(_ name: String) {
    perform(.deleteLocal(name))
  }

  public func deleteRemoteTag(_ name: String) {
    perform(.deleteRemote(name))
  }

  public func checkoutTag(_ name: String) {
    perform(.checkout(name))
  }

  private func perform(_ operation: TagOperation) {
    guard let repository = selectedRepository else { return }
    guard repository.isCloned else {
      errorMessage = "所选路径不是可用的 Git 仓库。"
      return
    }

    currentTask?.cancel()
    isWorking = true
    errorMessage = nil
    statusMessage = nil
    let path = repository.absolutePath

    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> TagActionResult in
        let service = ReposYAMLService()
        do {
          switch operation {
          case .create(let name, let message):
            try service.createTag(name, message: message, at: path)
          case .push(let name):
            try service.pushTag(name, at: path)
          case .deleteLocal(let name):
            try service.deleteLocalTag(name, at: path)
          case .deleteRemote(let name):
            try service.deleteRemoteTag(name, at: path)
          case .checkout(let name):
            try service.checkoutTag(name, at: path) { message in
              Task { @MainActor in
                LogManager.shared.debug(message)
              }
            }
          }
        } catch {
          return TagActionResult(snapshot: nil, currentBranch: nil, error: error.localizedDescription)
        }

        do {
          return TagActionResult(
            snapshot: try service.loadTags(at: path),
            currentBranch: service.getCurrentBranch(at: path),
            error: nil
          )
        } catch {
          return TagActionResult(
            snapshot: nil,
            currentBranch: nil,
            error: "Tag 操作已完成，但刷新列表失败：\(error.localizedDescription)"
          )
        }
      }.value

      guard let self else { return }
      self.isWorking = false
      self.currentTask = nil
      if let snapshot = result.snapshot {
        self.tags = snapshot.tags
        self.hasOrigin = snapshot.hasOrigin
        self.errorMessage = nil
        self.statusMessage = operation.successMessage
        if let currentBranch = result.currentBranch, let repository = self.selectedRepository {
          self.repositories = self.repositories.map { item in
            guard item.id == repository.id else { return item }
            return RepoSwitchInfo(
              name: item.name,
              path: item.path,
              absolutePath: item.absolutePath,
              currentBranch: currentBranch,
              targetBranch: item.targetBranch,
              isCloned: item.isCloned,
              scope: item.scope
            )
          }
        }
        if case .create = operation {
          self.tagName = ""
          self.tagMessage = ""
        }
      } else {
        self.errorMessage = result.error
      }
    }
  }

  private enum TagOperation: Sendable {
    case create(name: String, message: String)
    case push(String)
    case deleteLocal(String)
    case deleteRemote(String)
    case checkout(String)

    var successMessage: String {
      switch self {
      case .create(let name, _): "已创建 Tag \(name)"
      case .push(let name): "已推送 Tag \(name)"
      case .deleteLocal(let name): "已删除本地 Tag \(name)"
      case .deleteRemote(let name): "已删除远端 Tag \(name)"
      case .checkout(let name): "已切换到 Tag \(name)（detached HEAD）"
      }
    }
  }

  private struct RepositoryLoadResult: Sendable {
    let repositories: [RepoSwitchInfo]
    let error: String?
  }

  private struct TagLoadResult: Sendable {
    let snapshot: GitTagSnapshot?
    let error: String?
  }

  private struct TagActionResult: Sendable {
    let snapshot: GitTagSnapshot?
    let currentBranch: String?
    let error: String?
  }
}
