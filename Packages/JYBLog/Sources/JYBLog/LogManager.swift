import Foundation
import SwiftUI
import OSLog

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

    private let logger = Logger(subsystem: "com.aaron.dev.JYBToolApp", category: "JYBLog")

    private init() {}

    public func debug(_ message: String) {
        addEntry(.debug, message: message)
        logger.debug("\(message, privacy: .public)")
    }

    public func info(_ message: String) {
        addEntry(.info, message: message)
        logger.info("\(message, privacy: .public)")
    }

    public func success(_ message: String) {
        addEntry(.success, message: message)
        logger.notice("\(message, privacy: .public)")
    }

    public func warning(_ message: String) {
        addEntry(.warning, message: message)
        logger.warning("\(message, privacy: .public)")
    }

    public func error(_ message: String) {
        addEntry(.error, message: message)
        logger.error("\(message, privacy: .public)")
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
