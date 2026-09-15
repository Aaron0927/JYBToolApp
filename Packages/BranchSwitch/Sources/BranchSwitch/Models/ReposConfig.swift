//
//  ReposConfig.swift
//  BranchSwitch
//

import Foundation

public struct DeclaredRepo: Identifiable, Equatable, Sendable {
  public let name: String
  public let url: String
  public let path: String
  public let branch: String
  public let tag: String?

  public init(name: String, url: String, path: String, branch: String, tag: String? = nil) {
    self.name = name
    self.url = url
    self.path = path
    self.branch = branch
    self.tag = tag
  }

  public var id: String { path }
}

public struct ReposConfig: Equatable, Sendable {
  public let root: String
  public let repos: [DeclaredRepo]

  public init(root: String, repos: [DeclaredRepo]) {
    self.root = root
    self.repos = repos
  }
}

public enum RepoSwitchScope: String, Equatable, Sendable {
  case workspace
  case dependency
}

public struct RepoSwitchInfo: Identifiable, Equatable, Sendable {
  public let name: String
  public let path: String
  public let absolutePath: String
  public let currentBranch: String
  public let targetBranch: String
  public let targetTag: String?
  public let isCloned: Bool
  public let scope: RepoSwitchScope

  public init(
    name: String,
    path: String,
    absolutePath: String,
    currentBranch: String,
    targetBranch: String,
    targetTag: String? = nil,
    isCloned: Bool,
    scope: RepoSwitchScope = .dependency
  ) {
    self.name = name
    self.path = path
    self.absolutePath = absolutePath
    self.currentBranch = currentBranch
    self.targetBranch = targetBranch
    self.targetTag = targetTag
    self.isCloned = isCloned
    self.scope = scope
  }

  public var id: String { "\(scope.rawValue):\(path)" }
}
