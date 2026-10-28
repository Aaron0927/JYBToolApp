import AppKit
import Foundation
import JYBLog

@Observable
@MainActor
public final class BranchSyncViewModel {
  private static let lastProjectPathKey = "BranchSync.lastProjectPath"

  public var projectPath = ""
  public private(set) var preview: BranchSyncPreview?
  public var selectedRepositoryIDs: Set<String> = []
  public private(set) var isLoading = false
  public private(set) var isWorking = false
  public private(set) var errorMessage: String?
  public private(set) var operationProgress: String?
  public private(set) var summary: String?
  public private(set) var operationResults: [BranchSyncResult] = []

  private var currentTask: Task<Void, Never>?

  public init() {
    projectPath = UserDefaults.standard.string(forKey: Self.lastProjectPathKey) ?? ""
  }

  public var isBusy: Bool { isLoading || isWorking }

  public var repositories: [BranchSyncRepository] { preview?.repositories ?? [] }

  public var selectableRepositories: [BranchSyncRepository] {
    repositories.filter(\.isSelectable)
  }

  public var selectedRepositories: [BranchSyncRepository] {
    repositories.filter { selectedRepositoryIDs.contains($0.id) && $0.isSelectable }
  }

  public var areAllRepositoriesSelected: Bool {
    !selectableRepositories.isEmpty && selectedRepositories.count == selectableRepositories.count
  }

  public func selectProject() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false

    if panel.runModal() == .OK, let url = panel.url {
      projectPath = url.path
      loadPreview()
    }
  }

  public func loadPreview() {
    guard !projectPath.isEmpty else {
      errorMessage = "请选择包含 fastlane/repos.yml 的主工程目录。"
      return
    }

    currentTask?.cancel()
    isLoading = true
    errorMessage = nil
    summary = nil
    operationProgress = nil
    operationResults = []
    preview = nil
    selectedRepositoryIDs = []
    UserDefaults.standard.set(projectPath, forKey: Self.lastProjectPathKey)
    LogManager.shared.info("读取当前分支和 origin/master 或 origin/main 的 repos.yml…")

    let path = projectPath
    currentTask = Task { @MainActor [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> Result<BranchSyncPreview, BranchSyncPreviewLoadError> in
        do {
          return .success(try BranchSyncService().loadPreview(atProjectPath: path))
        } catch {
          return .failure(BranchSyncPreviewLoadError(message: error.localizedDescription))
        }
      }.value

      guard let self else { return }
      self.isLoading = false
      self.currentTask = nil
      switch result {
      case .success(let preview):
        self.preview = preview
        self.selectedRepositoryIDs = Set(preview.repositories.filter(\.isSelectable).map(\.id))
        LogManager.shared.success(
          "已读取 \(preview.repositories.count) 个仓库；来源配置 \(preview.sourceProjectBranch)，目标配置 origin/\(preview.targetConfigBranch)"
        )
      case .failure(let error):
        self.errorMessage = error.message
        LogManager.shared.error("读取分支同步配置失败：\(error.message)")
      }
    }
  }

  public func setRepository(_ repositoryID: String, selected: Bool) {
    guard !isBusy, selectableRepositories.contains(where: { $0.id == repositoryID }) else { return }
    if selected {
      selectedRepositoryIDs.insert(repositoryID)
    } else {
      selectedRepositoryIDs.remove(repositoryID)
    }
  }

  public func setAllRepositoriesSelected(_ selected: Bool) {
    guard !isBusy else { return }
    selectedRepositoryIDs = selected ? Set(selectableRepositories.map(\.id)) : []
  }

  public func syncSelectedRepositories() {
    let targets = selectedRepositories
    guard !targets.isEmpty else { return }

    currentTask?.cancel()
    isWorking = true
    errorMessage = nil
    summary = nil
    operationResults = []
    LogManager.shared.info("========== 开始分支同步（\(targets.count) 个仓库） ==========")

    currentTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for (index, repository) in targets.enumerated() {
        self.operationProgress = "正在同步 \(repository.name)（\(index + 1)/\(targets.count)）…"
        let result = await Task.detached(priority: .userInitiated) {
          BranchSyncService().sync(repository)
        }.value
        self.operationResults.append(result)
        Self.log(result)
      }

      let success = self.operationResults.filter { $0.status == .success }.count
      let skipped = self.operationResults.filter { $0.status == .skipped }.count
      let failed = self.operationResults.filter { $0.status == .failed || $0.status == .pushFailed }.count
      self.summary = "完成：成功 \(success)，跳过 \(skipped)，失败 \(failed)"
      self.operationProgress = nil
      self.isWorking = false
      self.currentTask = nil
      LogManager.shared.info("========== \(self.summary ?? "分支同步完成") ==========")
    }
  }

  private static func log(_ result: BranchSyncResult) {
    let message = "\(result.name) · \(result.sourceBranch) → \(result.targetBranch)：\(result.message)"
    switch result.status {
    case .success: LogManager.shared.success(message)
    case .skipped: LogManager.shared.info("跳过：\(message)")
    case .failed, .pushFailed: LogManager.shared.error(message)
    }
  }
}

private struct BranchSyncPreviewLoadError: Error, Sendable {
  let message: String
}
