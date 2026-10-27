import Foundation
import XCTest
@testable import ProjectCopyTool

final class FileProcessorTests: XCTestCase {
  func testCopyAndReplacePreservesProtectedKeyword() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appending(path: "source", directoryHint: .isDirectory)
    let target = root.appending(path: "target", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

    let sourceFile = source.appending(path: "Example.swift")
    try "GDCModule uses GDCASDK".write(to: sourceFile, atomically: true, encoding: .utf8)
    let oldTargetFile = target.appending(path: "Example.swift")
    try "old content".write(to: oldTargetFile, atomically: true, encoding: .utf8)

    let protectedDirectory = source.appending(path: "GDCASDK", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: protectedDirectory, withIntermediateDirectories: true)
    try "GDC stays here".write(
      to: protectedDirectory.appending(path: "Protected.swift"),
      atomically: true,
      encoding: .utf8
    )

    let config = RenamerConfig(
      sourceTargetPairs: [SourceTargetPair(sourcePath: source.path, targetPath: target.path)],
      oldPrefix: "GDC",
      newPrefix: "JYB",
      modifyConfigFiles: false
    )
    let processor = FileProcessor(config: config)

    try processor.copyProject()
    try processor.replaceSourceContent()

    let copiedText = try String(contentsOf: target.appending(path: "Example.swift"), encoding: .utf8)
    XCTAssertEqual(copiedText, "JYBModule uses GDCASDK")
    XCTAssertFalse(FileManager.default.fileExists(atPath: target.appending(path: "GDCASDK").path))
    XCTAssertEqual(processor.filesReplaced, 1)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "ProjectCopyToolTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
