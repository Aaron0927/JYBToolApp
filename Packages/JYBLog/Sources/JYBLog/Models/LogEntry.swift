import Foundation
import SwiftUI

public enum LogLevel: String, CaseIterable, Codable, Sendable {
    case debug
    case info
    case success
    case warning
    case error

    public var icon: String {
        switch self {
        case .debug:   return "ladybug"
        case .info:    return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.circle"
        }
    }

    public var color: Color {
        switch self {
        case .debug:   return .gray
        case .info:    return .blue
        case .success: return .green
        case .warning: return .orange
        case .error:   return .red
        }
    }

    public var label: String {
        switch self {
        case .debug:   return "调试"
        case .info:    return "信息"
        case .success: return "成功"
        case .warning: return "警告"
        case .error:   return "错误"
        }
    }
}

public struct LogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String

    public init(level: LogLevel, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.message = message
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}