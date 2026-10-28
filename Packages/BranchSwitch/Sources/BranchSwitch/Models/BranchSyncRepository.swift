import Foundation

public struct BranchSyncRepository: Identifiable, Equatable, Sendable {
  public let name: String
  public let path: String
  public let absolutePath: String
  public let sourceBranch: String?
  public let targetBranch: String?
  public let isWorkspace: Bool
  public let isSelectable: Bool
  public let unavailableReason: String?

  public init(
    name: String,
    path: String,
    absolutePath: String,
    sourceBranch: String?,
    targetBranch: String?,
    isWorkspace: Bool,
    isSelectable: Bool,
    unavailableReason: String? = nil
  ) {
    self.name = name
    self.path = path
    self.absolutePath = absolutePath
    self.sourceBranch = sourceBranch
    self.targetBranch = targetBranch
    self.isWorkspace = isWorkspace
    self.isSelectable = isSelectable
    self.unavailableReason = unavailableReason
  }

  public var id: String { isWorkspace ? "workspace" : path }

  public var canSync: Bool { isSelectable && sourceBranch != nil && targetBranch != nil }
}

public struct BranchSyncProjectContext: Sendable {
  public let projectPath: String
  public let sourceProjectBranch: String
  public let sourceConfig: ReposConfig
  public let sourceRootPath: String
  public let targetBranches: [String]
  public let defaultTargetBranch: String?

  public init(
    projectPath: String,
    sourceProjectBranch: String,
    sourceConfig: ReposConfig,
    sourceRootPath: String,
    targetBranches: [String],
    defaultTargetBranch: String?
  ) {
    self.projectPath = projectPath
    self.sourceProjectBranch = sourceProjectBranch
    self.sourceConfig = sourceConfig
    self.sourceRootPath = sourceRootPath
    self.targetBranches = targetBranches
    self.defaultTargetBranch = defaultTargetBranch
  }
}

public struct BranchSyncPreview: Equatable, Sendable {
  public let projectPath: String
  public let sourceProjectBranch: String
  public let targetProjectBranch: String
  public let targetConfigBranch: String
  public let repositories: [BranchSyncRepository]

  public init(
    projectPath: String,
    sourceProjectBranch: String,
    targetProjectBranch: String,
    targetConfigBranch: String,
    repositories: [BranchSyncRepository]
  ) {
    self.projectPath = projectPath
    self.sourceProjectBranch = sourceProjectBranch
    self.targetProjectBranch = targetProjectBranch
    self.targetConfigBranch = targetConfigBranch
    self.repositories = repositories
  }
}

public enum BranchSyncStatus: String, Equatable, Sendable {
  case success
  case skipped
  case failed
  case pushFailed
}

public struct BranchSyncResult: Identifiable, Equatable, Sendable {
  public let repositoryID: String
  public let name: String
  public let sourceBranch: String
  public let targetBranch: String
  public let status: BranchSyncStatus
  public let message: String

  public init(
    repositoryID: String,
    name: String,
    sourceBranch: String,
    targetBranch: String,
    status: BranchSyncStatus,
    message: String
  ) {
    self.repositoryID = repositoryID
    self.name = name
    self.sourceBranch = sourceBranch
    self.targetBranch = targetBranch
    self.status = status
    self.message = message
  }

  public var id: String { repositoryID }
}
