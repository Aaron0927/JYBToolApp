//
//  SubmoduleTests.swift
//  BranchSwitchTests
//

import XCTest
@testable import BranchSwitch

final class SubmoduleTests: XCTestCase {

    func testSubmoduleInit() {
        let submodule = Submodule(name: "MyModule", path: "path/to/module", branch: "develop")

        XCTAssertEqual(submodule.name, "MyModule")
        XCTAssertEqual(submodule.path, "path/to/module")
        XCTAssertEqual(submodule.branch, "develop")
    }

    func testSubmoduleEquatable() {
        let submodule1 = Submodule(name: "MyModule", path: "path/to/module", branch: "develop")
        let submodule2 = Submodule(name: "MyModule", path: "path/to/module", branch: "develop")
        let submodule3 = Submodule(name: "OtherModule", path: "path/to/module", branch: "main")

        XCTAssertEqual(submodule1, submodule2)
        XCTAssertNotEqual(submodule1, submodule3)
    }

    func testSubmoduleIdentifiable() {
        let submodule = Submodule(name: "MyModule", path: "path/to/module", branch: "develop")
        XCTAssertEqual(submodule.id, "MyModule")
    }
}
