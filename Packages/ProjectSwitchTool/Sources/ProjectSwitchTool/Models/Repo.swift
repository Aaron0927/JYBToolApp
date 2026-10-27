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
    public var isAvailable: Bool = true
    public var submodules: [Submodule] = []
    public var hasStash: Bool = false
    public var operationStatus: String?
    public var operationDetail: String?

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        currentBranch: String,
        targetBranch: String,
        branches: [String] = [],
        isMainRepo: Bool = false,
        isAvailable: Bool = true,
        submodules: [Submodule] = [],
        hasStash: Bool = false,
        operationStatus: String? = nil,
        operationDetail: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
        self.targetBranch = targetBranch
        self.branches = branches
        self.isMainRepo = isMainRepo
        self.isAvailable = isAvailable
        self.submodules = submodules
        self.hasStash = hasStash
        self.operationStatus = operationStatus
        self.operationDetail = operationDetail
    }
}
