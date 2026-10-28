import Foundation
import XCTest
@testable import BranchSwitch

final class BranchSyncServiceTests: XCTestCase {
  private var temporaryDirectory: URL!

  override func setUpWithError() throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: temporaryDirectory)
  }

  func testProjectContextReadsOnlyMainProjectRemoteBranches() throws {
    let fixture = try makeFixture()

    let context = try BranchSyncService().loadProjectContext(atProjectPath: fixture.project.path)

    XCTAssertEqual(context.sourceProjectBranch, "develop")
    XCTAssertEqual(context.targetBranches, ["master", "release"])
    XCTAssertEqual(context.defaultTargetBranch, "master")
    XCTAssertEqual(context.sourceConfig.repos.first?.branch, "develop")
    XCTAssertEqual(try runGit("branch --show-current", at: fixture.project), "develop")
  }

  func testSelectedMainProjectBranchReposConfigSetsDependencyTargetBranches() throws {
    let fixture = try makeFixture()
    let service = BranchSyncService()
    let context = try service.loadProjectContext(atProjectPath: fixture.project.path)

    let preview = try service.loadPreview(for: context, targetProjectBranch: "master")

    XCTAssertEqual(preview.targetProjectBranch, "master")
    XCTAssertEqual(preview.targetConfigBranch, "master")
    XCTAssertEqual(try runGit("branch --show-current", at: fixture.project), "develop")

    let dependency = try XCTUnwrap(preview.repositories.first { $0.path == "Dependency" })
    XCTAssertEqual(dependency.sourceBranch, "develop")
    XCTAssertEqual(dependency.targetBranch, "main")
    XCTAssertTrue(dependency.canSync)
    XCTAssertEqual(dependency.name, "Dependency", "按 path 配对，保留来源配置中的仓库名称")

    let targetOnly = try XCTUnwrap(preview.repositories.first { $0.path == "StableOnly" })
    XCTAssertFalse(targetOnly.canSync)
    XCTAssertEqual(targetOnly.unavailableReason, "当前分支的 repos.yml 未声明此仓库")
  }

  func testChosenTargetBranchLoadsItsOwnReposConfig() throws {
    let fixture = try makeFixture()
    let service = BranchSyncService()
    let context = try service.loadProjectContext(atProjectPath: fixture.project.path)

    let preview = try service.loadPreview(for: context, targetProjectBranch: "release")

    let dependency = try XCTUnwrap(preview.repositories.first { $0.path == "Dependency" })
    XCTAssertEqual(dependency.sourceBranch, "develop")
    XCTAssertEqual(dependency.targetBranch, "release")
    XCTAssertEqual(preview.targetConfigBranch, "release")
  }

  func testSyncMergesConfiguredSourceBranchIntoSelectedTargetAndPushes() throws {
    let fixture = try makeFixture()
    let service = BranchSyncService()
    let context = try service.loadProjectContext(atProjectPath: fixture.project.path)
    let preview = try service.loadPreview(for: context, targetProjectBranch: "master")
    let dependency = try XCTUnwrap(preview.repositories.first { $0.path == "Dependency" })

    let result = service.sync(dependency)

    XCTAssertEqual(result.status, .success, result.message)
    XCTAssertEqual(try runGit("branch --show-current", at: fixture.dependency), "develop")
    XCTAssertEqual(try runGit("show origin/main:source.txt", at: fixture.dependency), "development commit")
    XCTAssertEqual(
      try runGit("rev-parse main", at: fixture.dependency),
      try runGit("rev-parse origin/main", at: fixture.dependency)
    )
  }

  func testSyncSkipsDirtyRepository() throws {
    let fixture = try makeFixture()
    let service = BranchSyncService()
    let context = try service.loadProjectContext(atProjectPath: fixture.project.path)
    let preview = try service.loadPreview(for: context, targetProjectBranch: "master")
    let dependency = try XCTUnwrap(preview.repositories.first { $0.path == "Dependency" })
    try "local edit".write(
      to: fixture.dependency.appending(path: "dirty.txt"),
      atomically: true,
      encoding: .utf8
    )

    let result = service.sync(dependency)

    XCTAssertEqual(result.status, .skipped)
    XCTAssertEqual(result.message, "工作区有未提交修改。")
    XCTAssertEqual(try runGit("branch --show-current", at: fixture.dependency), "develop")
  }

  func testDefaultTargetBranchFallsBackToMainWhenMasterIsMissing() throws {
    let fixture = try makeFixture(projectStableBranch: "main")

    let context = try BranchSyncService().loadProjectContext(atProjectPath: fixture.project.path)

    XCTAssertEqual(context.sourceProjectBranch, "develop")
    XCTAssertEqual(context.defaultTargetBranch, "main")
    XCTAssertTrue(context.targetBranches.contains("release"))
  }

  private func makeFixture(projectStableBranch: String = "master") throws -> BranchSyncFixture {
    let workspace = temporaryDirectory.appending(path: "workspace", directoryHint: .isDirectory)
    let project = workspace.appending(path: "MainProject", directoryHint: .isDirectory)
    let dependency = workspace.appending(path: "Dependency", directoryHint: .isDirectory)
    let projectRemote = temporaryDirectory.appending(path: "project.git", directoryHint: .isDirectory)
    let dependencyRemote = temporaryDirectory.appending(path: "dependency.git", directoryHint: .isDirectory)

    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    try runGit("init --bare --initial-branch=\(projectStableBranch) \(quote(projectRemote.path))", at: temporaryDirectory)
    try runGit("init --bare --initial-branch=main \(quote(dependencyRemote.path))", at: temporaryDirectory)

    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    try runGit("init --initial-branch=\(projectStableBranch)", at: project)
    try configureGitUser(at: project)
    try writeProjectConfig(
      in: project,
      dependencyBranch: "main",
      dependencyRemote: dependencyRemote,
      dependencyName: "StableDependency",
      includeStableOnly: true
    )
    try runGit("add fastlane/repos.yml", at: project)
    try runGit("commit -m 'Stable project config'", at: project)
    try runGit("remote add origin \(quote(projectRemote.path))", at: project)
    try runGit("push -u origin \(projectStableBranch)", at: project)

    try runGit("checkout -b release", at: project)
    try writeProjectConfig(in: project, dependencyBranch: "release", dependencyRemote: dependencyRemote)
    try runGit("add fastlane/repos.yml", at: project)
    try runGit("commit -m 'Release project config'", at: project)
    try runGit("push -u origin release", at: project)

    try runGit("checkout -b develop \(projectStableBranch)", at: project)
    try writeProjectConfig(in: project, dependencyBranch: "develop", dependencyRemote: dependencyRemote)
    try runGit("add fastlane/repos.yml", at: project)
    try runGit("commit -m 'Development project config'", at: project)

    try FileManager.default.createDirectory(at: dependency, withIntermediateDirectories: true)
    try runGit("init --initial-branch=main", at: dependency)
    try configureGitUser(at: dependency)
    try "stable commit".write(to: dependency.appending(path: "stable.txt"), atomically: true, encoding: .utf8)
    try runGit("add stable.txt", at: dependency)
    try runGit("commit -m 'Stable dependency'", at: dependency)
    try runGit("remote add origin \(quote(dependencyRemote.path))", at: dependency)
    try runGit("push -u origin main", at: dependency)
    try runGit("checkout -b release", at: dependency)
    try runGit("push -u origin release", at: dependency)
    try runGit("checkout -b develop main", at: dependency)
    try "development commit".write(to: dependency.appending(path: "source.txt"), atomically: true, encoding: .utf8)
    try runGit("add source.txt", at: dependency)
    try runGit("commit -m 'Development dependency'", at: dependency)

    return BranchSyncFixture(project: project, dependency: dependency)
  }

  private func writeProjectConfig(
    in project: URL,
    dependencyBranch: String,
    dependencyRemote: URL,
    dependencyName: String = "Dependency",
    includeStableOnly: Bool = false
  ) throws {
    let stableOnlyEntry = includeStableOnly
      ? """
          - name: StableOnly
            url: \(dependencyRemote.path)
            path: StableOnly
            branch: main
        """
      : ""
    let config = """
    root: ../..
    repos:
      - name: \(dependencyName)
        url: \(dependencyRemote.path)
        path: Dependency
        branch: \(dependencyBranch)
    \(stableOnlyEntry)
    """
    let configURL = project.appending(path: "fastlane/repos.yml")
    try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try config.write(to: configURL, atomically: true, encoding: .utf8)
  }

  private func configureGitUser(at path: URL) throws {
    try runGit("config user.email branch-sync-tests@example.com", at: path)
    try runGit("config user.name BranchSyncTests", at: path)
  }

  @discardableResult
  private func runGit(_ command: String, at path: URL) throws -> String {
    try ProcessRunner().run("git \(command)", at: path.path).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func quote(_ value: String) -> String {
    "'\(value.replacing("'", with: "'\\''"))'"
  }
}

private struct BranchSyncFixture {
  let project: URL
  let dependency: URL
}
