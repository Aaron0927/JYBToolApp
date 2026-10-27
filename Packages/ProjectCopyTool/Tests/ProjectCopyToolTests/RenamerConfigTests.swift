import Foundation
import XCTest
@testable import ProjectCopyTool

final class RenamerConfigTests: XCTestCase {
  func testValidateRejectsMissingSource() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let config = makeConfig(
      source: root.appending(path: "missing").path,
      target: root.appending(path: "target").path
    )

    XCTAssertThrowsError(try config.validate()) { error in
      guard case RenamerError.sourceNotFound = error else {
        return XCTFail("Expected sourceNotFound, received \(error)")
      }
    }
  }

  func testValidateRejectsEmptyTarget() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    let config = makeConfig(source: source.path, target: "")

    XCTAssertThrowsError(try config.validate()) { error in
      guard case RenamerError.targetPathEmpty = error else {
        return XCTFail("Expected targetPathEmpty, received \(error)")
      }
    }
  }

  func testValidateRejectsOverlappingSourceAndTarget() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    let nestedTarget = source.appending(path: "copy", directoryHint: .isDirectory)
    let config = makeConfig(source: source.path, target: nestedTarget.path)

    XCTAssertThrowsError(try config.validate()) { error in
      guard case RenamerError.pathsOverlap = error else {
        return XCTFail("Expected pathsOverlap, received \(error)")
      }
    }
  }

  func testValidateRejectsExistingTargetFile() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let targetFile = root.appending(path: "target.txt")
    try "not a directory".write(to: targetFile, atomically: true, encoding: .utf8)

    let config = makeConfig(source: source.path, target: targetFile.path)

    XCTAssertThrowsError(try config.validate()) { error in
      guard case RenamerError.targetNotDirectory = error else {
        return XCTFail("Expected targetNotDirectory, received \(error)")
      }
    }
  }

  func testValidateRejectsIdenticalPrefixes() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    let config = makeConfig(source: source.path, target: root.appending(path: "target").path, oldPrefix: "Same", newPrefix: "Same")

    XCTAssertThrowsError(try config.validate()) { error in
      guard case RenamerError.prefixesIdentical = error else {
        return XCTFail("Expected prefixesIdentical, received \(error)")
      }
    }
  }

  func testExecuteReturnsReadableValidationFailure() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let missingSource = root.appending(path: "missing", directoryHint: .isDirectory)
    let target = root.appending(path: "target", directoryHint: .isDirectory)
    let renamer = ProjectRenamer(config: makeConfig(source: missingSource.path, target: target.path))

    let result = renamer.execute()

    XCTAssertFalse(result.success)
    XCTAssertEqual(result.errors.count, 1)
    XCTAssertTrue(result.errors[0].contains(missingSource.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
  }

  private func makeConfig(
    source: String,
    target: String,
    oldPrefix: String = "GDC",
    newPrefix: String = "JYB"
  ) -> RenamerConfig {
    RenamerConfig(
      sourceTargetPairs: [SourceTargetPair(sourcePath: source, targetPath: target)],
      oldPrefix: oldPrefix,
      newPrefix: newPrefix,
      modifyConfigFiles: false
    )
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "ProjectCopyToolTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
