//
//  ReposYAMLServiceTests.swift
//  BranchSwitchTests
//

import XCTest
@testable import BranchSwitch

final class ReposYAMLServiceTests: XCTestCase {
  private var temporaryDirectory: URL!

  override func setUpWithError() throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: temporaryDirectory)
  }

  func testPullAllRepositoriesPullsWorkspaceAndDeclaredRepositories() throws {
    let fixture = try makePullFixture()
    try commitAndPushChange(in: fixture.workspaceUpdater, fileName: "workspace.txt", content: "workspace remote update")
    try commitAndPushChange(in: fixture.dependencyUpdater, fileName: "dependency.txt", content: "dependency remote update")

    let results = try ReposYAMLService().pullAllRepositories(atProjectPath: fixture.project.path) { _ in }

    XCTAssertEqual(results.count, 2)
    let resultDescriptions = results.map { "\($0.name): \($0.message ?? "成功")" }
    XCTAssertTrue(results.allSatisfy { $0.status == .success }, "\(resultDescriptions)")
    XCTAssertEqual(try String(contentsOf: fixture.project.appending(path: "workspace.txt"), encoding: .utf8), "workspace remote update")
    XCTAssertEqual(
      try String(contentsOf: fixture.dependency.appending(path: "dependency.txt"), encoding: .utf8),
      "dependency remote update"
    )
  }

  func testPullAllRepositoriesRestoresUntrackedChangesAfterPull() throws {
    let fixture = try makePullFixture()
    let localFile = fixture.dependency.appending(path: "local-only.txt")
    try "keep local work".write(to: localFile, atomically: true, encoding: .utf8)
    try commitAndPushChange(in: fixture.dependencyUpdater, fileName: "dependency.txt", content: "dependency remote update")

    let results = try ReposYAMLService().pullAllRepositories(atProjectPath: fixture.project.path) { _ in }

    let dependencyResult = try XCTUnwrap(results.first { $0.name == "Dependency" })
    XCTAssertEqual(dependencyResult.status, .success, dependencyResult.message ?? "未知错误")
    XCTAssertTrue(dependencyResult.hadAutoStash)
    XCTAssertEqual(try String(contentsOf: localFile, encoding: .utf8), "keep local work")
    XCTAssertEqual(
      try String(contentsOf: fixture.dependency.appending(path: "dependency.txt"), encoding: .utf8),
      "dependency remote update"
    )
  }

  func testPullAllRepositoriesSkipsRepositoryWithoutUpstream() throws {
    let fixture = try makePullFixture()
    try runGit("remote remove origin", at: fixture.dependency)

    let results = try ReposYAMLService().pullAllRepositories(atProjectPath: fixture.project.path) { _ in }

    let dependencyResult = try XCTUnwrap(results.first { $0.name == "Dependency" })
    XCTAssertEqual(dependencyResult.status, .skipped)
    XCTAssertEqual(dependencyResult.message, "当前分支未配置 upstream")
  }

  func testParseReposConfig() throws {
    let service = ReposYAMLService()
    let content = """
    # 依赖仓库声明
    root: "../.."

    repos:
      - name: TradeBook_Private
        url: http://gitlab.iqdii.com/tradego8/rongyi/ios/TradeBook_Private.git
        path: TradeBook_Private
        branch: 8.4.20

      - name: Trade_Comm
        url: http://gitlab.iqdii.com/tradego8/comm/ios/Trade_Comm.git
        path: TradeRepo/Trade_Comm
        branch: public_release
    """

    let config = try service.parseConfig(from: content)

    XCTAssertEqual(config.root, "../..")
    XCTAssertEqual(config.repos.count, 2)
    XCTAssertEqual(config.repos[0].name, "TradeBook_Private")
    XCTAssertEqual(config.repos[0].path, "TradeBook_Private")
    XCTAssertEqual(config.repos[0].branch, "8.4.20")
    XCTAssertEqual(config.repos[1].name, "Trade_Comm")
    XCTAssertEqual(config.repos[1].path, "TradeRepo/Trade_Comm")
    XCTAssertEqual(config.repos[1].branch, "public_release")
  }

  func testParseConfigWithInlineCommentsAndQuotedValues() throws {
    let service = ReposYAMLService()
    let content = """
    root: '../..' # 相对于 fastlane
    repos:
      - name: "MOU"
        url: "http://gitlab.iqdii.com/group/MOU.git"
        path: "TradeRepo/BTrade/MOU"
        branch: "Distribution_iAisa"
    """

    let config = try service.parseConfig(from: content)

    XCTAssertEqual(config.root, "../..")
    XCTAssertEqual(config.repos.first?.name, "MOU")
    XCTAssertEqual(config.repos.first?.branch, "Distribution_iAisa")
  }

  func testResolveRootRelativeToFastlaneDirectory() throws {
    let service = ReposYAMLService()
    let config = ReposConfig(root: "../..", repos: [])
    let configURL = URL(fileURLWithPath: "/Users/kim/project/fastlane/repos.yml")

    let rootURL = service.rootURL(for: config, configURL: configURL)

    XCTAssertEqual(rootURL.path, "/Users/kim")
  }

  func testParseLocalBranches() {
    let service = ReposYAMLService()
    let output = """
    develop
    release/8.4.20
    public_release
    """

    let branches = service.parseLocalBranches(from: output)

    XCTAssertEqual(branches, ["develop", "release/8.4.20", "public_release"])
  }

  func testMissingRepoFieldThrows() {
    let service = ReposYAMLService()
    let content = """
    root: "../.."
    repos:
      - name: TradeBook_Private
        url: http://gitlab.iqdii.com/repo.git
        path: TradeBook_Private
    """

    XCTAssertThrowsError(try service.parseConfig(from: content)) { error in
      guard case ReposYAMLServiceError.missingField(_, let field) = error else {
        XCTFail("Expected missingField error")
        return
      }
      XCTAssertEqual(field, "branch")
    }
  }

  private func makePullFixture() throws -> PullFixture {
    let workspaceRemote = temporaryDirectory.appending(path: "workspace.git", directoryHint: .isDirectory)
    let dependencyRemote = temporaryDirectory.appending(path: "dependency.git", directoryHint: .isDirectory)
    let workspaceSeed = temporaryDirectory.appending(path: "workspace-seed", directoryHint: .isDirectory)
    let dependencySeed = temporaryDirectory.appending(path: "dependency-seed", directoryHint: .isDirectory)
    let project = temporaryDirectory.appending(path: "project", directoryHint: .isDirectory)
    let dependency = project.appending(path: "Dependencies/Dependency", directoryHint: .isDirectory)
    let workspaceUpdater = temporaryDirectory.appending(path: "workspace-updater", directoryHint: .isDirectory)
    let dependencyUpdater = temporaryDirectory.appending(path: "dependency-updater", directoryHint: .isDirectory)

    try runGit("init --bare \(shellEscaped(workspaceRemote.path))", at: temporaryDirectory)
    try runGit("init --bare \(shellEscaped(dependencyRemote.path))", at: temporaryDirectory)
    try makeSeedRepository(at: workspaceSeed, remote: workspaceRemote, fileName: "workspace.txt", content: "workspace initial")
    try makeSeedRepository(at: dependencySeed, remote: dependencyRemote, fileName: "dependency.txt", content: "dependency initial")

    let configURL = workspaceSeed.appending(path: "fastlane/repos.yml")
    try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let config = """
    root: ".."
    repos:
      - name: Dependency
        url: "\(dependencyRemote.path)"
        path: Dependencies/Dependency
        branch: master
    """
    try config.write(to: configURL, atomically: true, encoding: .utf8)
    try runGit("add fastlane/repos.yml", at: workspaceSeed)
    try runGit("commit -m 'Add repos config'", at: workspaceSeed)
    try runGit("push", at: workspaceSeed)

    try runGit("clone \(shellEscaped(workspaceRemote.path)) \(shellEscaped(project.path))", at: temporaryDirectory)
    try FileManager.default.createDirectory(at: dependency.deletingLastPathComponent(), withIntermediateDirectories: true)
    try runGit("clone \(shellEscaped(dependencyRemote.path)) \(shellEscaped(dependency.path))", at: temporaryDirectory)
    try runGit("clone \(shellEscaped(workspaceRemote.path)) \(shellEscaped(workspaceUpdater.path))", at: temporaryDirectory)
    try runGit("clone \(shellEscaped(dependencyRemote.path)) \(shellEscaped(dependencyUpdater.path))", at: temporaryDirectory)

    return PullFixture(
      project: project,
      dependency: dependency,
      workspaceUpdater: workspaceUpdater,
      dependencyUpdater: dependencyUpdater
    )
  }

  private func makeSeedRepository(at path: URL, remote: URL, fileName: String, content: String) throws {
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
    try runGit("init", at: path)
    try configureGitUser(at: path)
    try content.write(to: path.appending(path: fileName), atomically: true, encoding: .utf8)
    try runGit("add \(shellEscaped(fileName))", at: path)
    try runGit("commit -m 'Initial commit'", at: path)
    try runGit("remote add origin \(shellEscaped(remote.path))", at: path)
    try runGit("push -u origin HEAD", at: path)
  }

  private func commitAndPushChange(in path: URL, fileName: String, content: String) throws {
    try configureGitUser(at: path)
    try content.write(to: path.appending(path: fileName), atomically: true, encoding: .utf8)
    try runGit("add \(shellEscaped(fileName))", at: path)
    try runGit("commit -m 'Remote update'", at: path)
    try runGit("push", at: path)
  }

  private func configureGitUser(at path: URL) throws {
    try runGit("config user.email test@example.com", at: path)
    try runGit("config user.name BranchSwitchTests", at: path)
  }

  private func runGit(_ arguments: String, at path: URL) throws {
    _ = try ProcessRunner().run("git \(arguments)", at: path.path)
  }

  private func shellEscaped(_ value: String) -> String {
    let parts = value.split(separator: "'", omittingEmptySubsequences: false)
    return "'" + parts.joined(separator: "'\\''") + "'"
  }
}

private struct PullFixture {
  let project: URL
  let dependency: URL
  let workspaceUpdater: URL
  let dependencyUpdater: URL
}
