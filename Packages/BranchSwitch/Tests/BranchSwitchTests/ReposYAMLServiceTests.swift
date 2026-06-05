//
//  ReposYAMLServiceTests.swift
//  BranchSwitchTests
//

import XCTest
@testable import BranchSwitch

final class ReposYAMLServiceTests: XCTestCase {
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
}
