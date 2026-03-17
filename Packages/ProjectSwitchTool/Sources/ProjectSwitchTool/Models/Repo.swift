//
//  Repo.swift
//  GitSwitcher
//
//  Created by kim on 2026/3/13.
//

import Foundation

public struct Repo: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public var currentBranch: String
    public let targetBranch: String
    
    public init(id: UUID = UUID(), name: String, path: String, currentBranch: String, targetBranch: String) {
        self.id = id
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
        self.targetBranch = targetBranch
    }
}
