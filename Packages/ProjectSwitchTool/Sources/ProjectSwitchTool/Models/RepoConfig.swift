//
//  RepoConfig.swift
//  GitSwitcher
//
//  Created by kim on 2026/3/13.
//

import Foundation

public struct RepoConfig: Decodable, Sendable {
    public let org: String
    public let repos: [String: String]
    
    public init(org: String, repos: [String: String]) {
        self.org = org
        self.repos = repos
    }
}
