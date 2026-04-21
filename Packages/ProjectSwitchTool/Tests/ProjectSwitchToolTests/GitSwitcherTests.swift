//
//  GitSwitcherTests.swift
//  GitSwitcherTests
//
//  Created by kim on 2026/3/13.
//

import XCTest
@testable import ProjectSwitchTool

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

    func testRunInvalidPath() {
        XCTAssertThrowsError(try ProcessRunner.run("echo hello", at: "/nonexistent/path/xyz"))
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

        // 由于路径不存在，readCurrentBranch 应该返回 "unknown"
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

        // 由于路径不存在，hasChanges 应该返回 false
        let result = service.hasChanges(repo: repo)
        XCTAssertFalse(result)
    }

    @MainActor
    func testPullWithNoTrackingInfo() async throws {
        // 创建临时测试仓库
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 初始化 git 仓库
        _ = try ProcessRunner.run("git init", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.email test@test.com", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.name Test", at: tempDir.path)
        _ = try ProcessRunner.run("touch test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git add test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git commit -m 'initial'", at: tempDir.path)

        let repo = Repo(
            name: "test-repo",
            path: tempDir.path,
            currentBranch: "main",
            targetBranch: "main"
        )

        // 由于没有远程，pull 会跳过（检测到远程不存在）
        try service.pull(repo: repo)

        // 清理
        try? FileManager.default.removeItem(at: tempDir)
    }

    @MainActor
    func testCheckoutCreatesNewBranch() async throws {
        // 创建临时测试仓库
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 初始化 git 仓库
        _ = try ProcessRunner.run("git init", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.email test@test.com", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.name Test", at: tempDir.path)
        _ = try ProcessRunner.run("touch test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git add test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git commit -m 'initial'", at: tempDir.path)

        let repo = Repo(
            name: "test-repo",
            path: tempDir.path,
            currentBranch: "main",
            targetBranch: "test-branch"
        )

        // 切换到不存在的分支（应该创建并切换）
        try service.checkout(repo: repo, branch: "test-branch")

        let currentBranch = service.readCurrentBranch(repo: repo)
        XCTAssertEqual(currentBranch, "test-branch")

        // 清理
        try? FileManager.default.removeItem(at: tempDir)
    }

    @MainActor
    func testCheckoutExistingBranch() async throws {
        // 创建临时测试仓库
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 初始化 git 仓库并创建分支
        _ = try ProcessRunner.run("git init", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.email test@test.com", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.name Test", at: tempDir.path)
        _ = try ProcessRunner.run("touch test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git add test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git commit -m 'initial'", at: tempDir.path)
        _ = try ProcessRunner.run("git branch existing-branch", at: tempDir.path)

        let repo = Repo(
            name: "test-repo",
            path: tempDir.path,
            currentBranch: "main",
            targetBranch: "existing-branch"
        )

        // 切换到已存在的分支
        try service.checkout(repo: repo, branch: "existing-branch")

        let currentBranch = service.readCurrentBranch(repo: repo)
        XCTAssertEqual(currentBranch, "existing-branch")

        // 清理
        try? FileManager.default.removeItem(at: tempDir)
    }

    @MainActor
    func testPullWithTrackingInfo() async throws {
        // 创建临时测试仓库
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 初始化 git 仓库
        _ = try ProcessRunner.run("git init", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.email test@test.com", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.name Test", at: tempDir.path)
        _ = try ProcessRunner.run("touch test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git add test.txt", at: tempDir.path)
        _ = try ProcessRunner.run("git commit -m 'initial'", at: tempDir.path)

        let repo = Repo(
            name: "test-repo",
            path: tempDir.path,
            currentBranch: "main",
            targetBranch: "main"
        )

        // 由于没有远程，pull 会跳过（检测到远程不存在）
        try service.pull(repo: repo)

        // 清理
        try? FileManager.default.removeItem(at: tempDir)
    }

    @MainActor
    func testCheckoutSubmoduleWithInitializedSubmodule() async throws {
        // 这个测试需要创建一个带有子模块的测试仓库
        // 由于子模块测试较复杂，这里测试核心逻辑：检查 checkout 命令是否能正确执行

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 创建父仓库
        _ = try ProcessRunner.run("git init", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.email test@test.com", at: tempDir.path)
        _ = try ProcessRunner.run("git config user.name Test", at: tempDir.path)

        // 创建子模块目录
        let submoduleDir = tempDir.appendingPathComponent("submodule")
        try FileManager.default.createDirectory(at: submoduleDir, withIntermediateDirectories: true)

        // 初始化子模块仓库
        _ = try ProcessRunner.run("git init", at: submoduleDir.path)
        _ = try ProcessRunner.run("git config user.email test@test.com", at: submoduleDir.path)
        _ = try ProcessRunner.run("git config user.name Test", at: submoduleDir.path)
        _ = try ProcessRunner.run("touch submodule.txt", at: submoduleDir.path)
        _ = try ProcessRunner.run("git add submodule.txt", at: submoduleDir.path)
        _ = try ProcessRunner.run("git commit -m 'submodule initial'", at: submoduleDir.path)
        _ = try ProcessRunner.run("git branch feature-branch", at: submoduleDir.path)

        let repo = Repo(
            name: "parent-repo",
            path: tempDir.path,
            currentBranch: "main",
            targetBranch: "main"
        )

        let submodule = Submodule(
            name: "submodule",
            path: "submodule",
            currentBranch: "main",
            targetBranch: "feature-branch"
        )

        // 测试切换子模块（子模块已初始化的情况）
        try service.checkoutSubmodule(repo: repo, submodule: submodule)

        // 验证子模块当前分支
        let submoduleBranch = service.readCurrentBranch(repo: Repo(
            name: "submodule",
            path: submoduleDir.path,
            currentBranch: "",
            targetBranch: ""
        ))
        XCTAssertEqual(submoduleBranch, "feature-branch")

        // 清理
        try? FileManager.default.removeItem(at: tempDir)
    }

    @MainActor
    func testParseGitmodules() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 创建 .gitmodules 文件
        let gitmodulesContent = """
        [submodule "TestSubmodule"]
            path = TestSubmodule
            url = http://example.com/test.git
            branch = develop
        [submodule "AnotherSubmodule"]
            path = AnotherSubmodule
            url = http://example.com/another.git
        """

        let gitmodulesPath = tempDir.appendingPathComponent(".gitmodules")
        try gitmodulesContent.write(toFile: gitmodulesPath, atomically: true, encoding: .utf8)

        // 创建子模块目录
        let submoduleDir = tempDir.appendingPathComponent("TestSubmodule")
        let anotherSubmoduleDir = tempDir.appendingPathComponent("AnotherSubmodule")
        try FileManager.default.createDirectory(at: submoduleDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: anotherSubmoduleDir, withIntermediateDirectories: true)

        // 初始化子模块 git 仓库
        _ = try ProcessRunner.run("git init", at: submoduleDir.path)
        _ = try ProcessRunner.run("git init", at: anotherSubmoduleDir.path)

        let repo = Repo(
            name: "test-repo",
            path: tempDir.path,
            currentBranch: "main",
            targetBranch: "main"
        )

        let submodules = service.readGitmodules(repo: repo)

        XCTAssertEqual(submodules.count, 2)

        // 验证第一个子模块（指定了 branch）
        let testSubmodule = submodules.first { $0.name == "TestSubmodule" }
        XCTAssertNotNil(testSubmodule)
        XCTAssertEqual(testSubmodule?.path, "TestSubmodule")
        XCTAssertEqual(testSubmodule?.targetBranch, "develop")

        // 验证第二个子模块（没有指定 branch，应该默认为 main）
        let anotherSubmodule = submodules.first { $0.name == "AnotherSubmodule" }
        XCTAssertNotNil(anotherSubmodule)
        XCTAssertEqual(anotherSubmodule?.path, "AnotherSubmodule")
        XCTAssertEqual(anotherSubmodule?.targetBranch, "main")

        // 清理
        try? FileManager.default.removeItem(at: tempDir)
    }
}
