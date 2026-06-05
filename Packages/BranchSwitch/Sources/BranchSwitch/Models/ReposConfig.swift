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

  public init(name: String, url: String, path: String, branch: String) {
    self.name = name
    self.url = url
    self.path = path
    self.branch = branch
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

public struct RepoSwitchInfo: Identifiable, Equatable, Sendable {
  public let name: String
  public let path: String
  public let absolutePath: String
  public let currentBranch: String
  public let targetBranch: String
  public let isCloned: Bool

  public init(
    name: String,
    path: String,
    absolutePath: String,
    currentBranch: String,
    targetBranch: String,
    isCloned: Bool
  ) {
    self.name = name
    self.path = path
    self.absolutePath = absolutePath
    self.currentBranch = currentBranch
    self.targetBranch = targetBranch
    self.isCloned = isCloned
  }

  public var id: String { path }
}
