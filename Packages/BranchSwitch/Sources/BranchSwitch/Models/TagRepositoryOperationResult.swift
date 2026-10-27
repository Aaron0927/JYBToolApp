import Foundation

public enum TagRepositoryOperationStatus: Equatable, Sendable {
  case success
  case pushFailed
  case failed
}

public struct TagRepositoryOperationResult: Identifiable, Equatable, Sendable {
  public let repositoryID: String
  public let repositoryName: String
  public let tagName: String
  public let status: TagRepositoryOperationStatus
  public let message: String

  public init(
    repositoryID: String,
    repositoryName: String,
    tagName: String,
    status: TagRepositoryOperationStatus,
    message: String
  ) {
    self.repositoryID = repositoryID
    self.repositoryName = repositoryName
    self.tagName = tagName
    self.status = status
    self.message = message
  }

  public var id: String { repositoryID }
}
