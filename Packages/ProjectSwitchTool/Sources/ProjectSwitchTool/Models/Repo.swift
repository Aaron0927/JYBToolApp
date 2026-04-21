//
//  Repo.swift
//  GitSwitcher
//
//  Created by kim on 2026/3/13.
//

import Foundation

public struct Submodule: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let path: String
    public var currentBranch: String
    public var targetBranch: String

    public init(id: UUID = UUID(), name: String, path: String, currentBranch: String = "", targetBranch: String = "") {
        self.id = id
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
        self.targetBranch = targetBranch
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Submodule, rhs: Submodule) -> Bool {
        lhs.id == rhs.id
    }
}

public struct Repo: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public var currentBranch: String
    public var targetBranch: String
    public var branches: [String] = []
    public var isMainRepo: Bool = false
    public var submodules: [Submodule] = []
    public var hasStash: Bool = false

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        currentBranch: String,
        targetBranch: String,
        branches: [String] = [],
        isMainRepo: Bool = false,
        submodules: [Submodule] = [],
        hasStash: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
        self.targetBranch = targetBranch
        self.branches = branches
        self.isMainRepo = isMainRepo
        self.submodules = submodules
        self.hasStash = hasStash
    }
}
