//
//  Submodule.swift
//  BranchSwitch
//

import Foundation

public struct Submodule: Identifiable, Equatable, Sendable {
    public let name: String
    public let path: String
    public let branch: String

    public init(name: String, path: String, branch: String) {
        self.name = name
        self.path = path
        self.branch = branch
    }

    public var id: String { name }
}
