import Foundation
import SwiftUI

@Observable
@MainActor
public final class LogManager: Sendable {
    public static let shared = LogManager()

    public var entries: [LogEntry] = []
    public var isExpanded: Bool = false
    public var panelHeight: CGFloat = 200
    public var visibleLevels: Set<LogLevel> = Set(LogLevel.allCases)

    public let minHeight: CGFloat = 100
    public let maxHeight: CGFloat = 400
    public let collapsedHeight: CGFloat = 40

    private init() {}

    public func debug(_ message: String) {
        addEntry(.debug, message: message)
    }

    public func info(_ message: String) {
        addEntry(.info, message: message)
    }

    public func success(_ message: String) {
        addEntry(.success, message: message)
    }

    public func warning(_ message: String) {
        addEntry(.warning, message: message)
    }

    public func error(_ message: String) {
        addEntry(.error, message: message)
    }

    public func clear() {
        entries.removeAll()
    }

    public func toggleLevel(_ level: LogLevel) {
        if visibleLevels.contains(level) {
            visibleLevels.remove(level)
        } else {
            visibleLevels.insert(level)
        }
    }

    public func filteredEntries() -> [LogEntry] {
        entries.filter { visibleLevels.contains($0.level) }
    }

    private func addEntry(_ level: LogLevel, message: String) {
        let entry = LogEntry(level: level, message: message)
        entries.append(entry)

        // 自动展开
        if !isExpanded {
            isExpanded = true
        }
    }
}
