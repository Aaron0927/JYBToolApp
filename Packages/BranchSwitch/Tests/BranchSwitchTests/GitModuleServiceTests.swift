//
//  GitModuleServiceTests.swift
//  BranchSwitchTests
//

import XCTest
@testable import BranchSwitch

final class GitModuleServiceTests: XCTestCase {

    func testGetSubmodulesFromGitmodulesOutput() {
        let service = GitModuleService()
        let output = """
        submodule.MyModule.path path/to/module
        submodule.OtherModule.path another/path
        """

        let submodules = service.parseSubmodules(from: output)

        XCTAssertEqual(submodules.count, 2)
        XCTAssertEqual(submodules[0].name, "MyModule")
        XCTAssertEqual(submodules[0].path, "path/to/module")
        XCTAssertEqual(submodules[1].name, "OtherModule")
        XCTAssertEqual(submodules[1].path, "another/path")
    }

    func testGetSubmoduleBranchOutput() {
        let service = GitModuleService()
        let output = "develop"

        let branch = service.parseSubmoduleBranch(from: output)
        XCTAssertEqual(branch, "develop")
    }

    func testGetSubmoduleBranchEmptyOutput() {
        let service = GitModuleService()
        let output = ""

        let branch = service.parseSubmoduleBranch(from: output)
        XCTAssertEqual(branch, "master")
    }

    func testHasChangesWithChanges() {
        let service = GitModuleService()
        let output = " M file1.swift\n?? file2.swift"

        XCTAssertTrue(service.hasChanges(output: output))
    }

    func testHasChangesNoChanges() {
        let service = GitModuleService()
        let output = ""

        XCTAssertFalse(service.hasChanges(output: output))
    }

    func testUpdateSubmoduleFlow() {
        let service = GitModuleService()
        let submodule = Submodule(name: "MyModule", path: "path/to/module", branch: "develop")

        // 验证 updateSubmodule 返回预期的操作序列
        let operations = service.simulateUpdateFlow(for: submodule)

        XCTAssertEqual(operations.count, 4)
        XCTAssertEqual(operations[0], "stash")
        XCTAssertEqual(operations[1], "checkout develop")
        XCTAssertEqual(operations[2], "pull")
        XCTAssertEqual(operations[3], "stash pop")
    }

    func testShouldPullWithUpstreamTracking() {
        // 验证有上游跟踪时的处理逻辑
        let service = GitModuleService()
        let upstreamOutput = "origin/develop"

        // 验证有上游跟踪时 shouldPull 返回 true
        let shouldPull = service.shouldPullWithUpstream(upstreamOutput: upstreamOutput)
        XCTAssertTrue(shouldPull)
    }

    func testShouldPullWithoutUpstreamTracking() {
        let service = GitModuleService()
        let upstreamOutput = ""

        // 验证没有上游跟踪时 shouldPull 返回 false
        let shouldPull = service.shouldPullWithUpstream(upstreamOutput: upstreamOutput)
        XCTAssertFalse(shouldPull)
    }
}
