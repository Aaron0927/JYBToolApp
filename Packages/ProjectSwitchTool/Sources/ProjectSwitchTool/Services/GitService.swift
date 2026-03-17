//
//  GitService.swift
//  GitSwitcher
//
//  Created by kim on 2026/3/13.
//

import Foundation

public final class GitService: Sendable {
    public init() {}
    
    public func readCurrentBranch(repo: Repo) -> String {
        do {
            let result = try ProcessRunner.run("git rev-parse --abbrev-ref HEAD", at: repo.path)
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("读取 \(repo.name) 当前分支失败: \(error)")
            return "unknown"
        }
    }
    
    public func hasChanges(repo: Repo) -> Bool {
        let result = try? ProcessRunner.run("git status --porcelain", at: repo.path)
        return !(result?.isEmpty ?? true)
    }
    
    public func stash(repo: Repo) throws {
        _ = try ProcessRunner.run("git stash push -u", at: repo.path)
    }
    
    public func checkout(repo: Repo, branch: String) throws {
        try ProcessRunner.run("git checkout \(branch)", at: repo.path)
    }
    
    public func pull(repo: Repo) throws {
        try ProcessRunner.run("git pull", at: repo.path)
    }
}
