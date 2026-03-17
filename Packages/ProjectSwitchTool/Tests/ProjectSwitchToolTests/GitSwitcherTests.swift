//
//  GitSwitcherTests.swift
//  GitSwitcherTests
//
//  Created by kim on 2026/3/13.
//

import XCTest
@testable import GitSwitcher

final class RepoTests: XCTestCase {
    func testRepoInitialization() {
        let repo = Repo(
            name: "test-repo",
            path: "/path/to/test-repo",
            currentBranch: "main",
            targetBranch: "develop"
        )
        
        XCTAssertEqual(repo.name, "test-repo")
        XCTAssertEqual(repo.path, "/path/to/test-repo")
        XCTAssertEqual(repo.currentBranch, "main")
        XCTAssertEqual(repo.targetBranch, "develop")
        XCTAssertNotNil(repo.id)
    }
    
    func testRepoEquatable() {
        let repo1 = Repo(
            name: "test-repo",
            path: "/path/to/test-repo",
            currentBranch: "main",
            targetBranch: "develop"
        )
        
        let repo2 = Repo(
            name: "test-repo",
            path: "/path/to/test-repo",
            currentBranch: "main",
            targetBranch: "develop"
        )
        
        XCTAssertNotEqual(repo1.id, repo2.id)
    }
}

final class RepoConfigTests: XCTestCase {
    func testRepoConfigInitialization() {
        let config = RepoConfig(
            org: "test-org",
            repos: [
                "repo1": "main",
                "repo2": "develop"
            ]
        )
        
        XCTAssertEqual(config.org, "test-org")
        XCTAssertEqual(config.repos.count, 2)
        XCTAssertEqual(config.repos["repo1"], "main")
        XCTAssertEqual(config.repos["repo2"], "develop")
    }
}

final class ProcessRunnerTests: XCTestCase {
    func testRunEchoCommand() throws {
        let result = try ProcessRunner.run("echo 'hello'", at: "/tmp")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }
    
    func testRunInvalidCommand() {
        XCTAssertThrowsError(try ProcessRunner.run("invalid-command-xyz", at: "/tmp"))
    }
    
    func testRunPwdCommand() throws {
        let result = try ProcessRunner.run("pwd", at: "/tmp")
        XCTAssertTrue(result.contains("tmp"))
    }
}

final class GitServiceTests: XCTestCase {
    let service = GitService()
    
    func testReadCurrentBranchWithInvalidPath() {
        let repo = Repo(
            name: "invalid-repo",
            path: "/nonexistent/path/repo",
            currentBranch: "",
            targetBranch: "main"
        )
        
        let result = service.readCurrentBranch(repo: repo)
        XCTAssertEqual(result, "unknown")
    }
    
    func testHasChangesWithInvalidPath() {
        let repo = Repo(
            name: "invalid-repo",
            path: "/nonexistent/path/repo",
            currentBranch: "",
            targetBranch: "main"
        )
        
        let result = service.hasChanges(repo: repo)
        XCTAssertFalse(result)
    }
}
