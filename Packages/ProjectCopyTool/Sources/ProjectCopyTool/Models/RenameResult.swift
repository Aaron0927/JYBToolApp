import Foundation

public struct RenameResult {
    public let success: Bool
    public let filesReplaced: Int
    public let directoriesRenamed: Int
    public let filesRenamed: Int
    public let errors: [String]
    public let warnings: [String]
    public let duration: TimeInterval

    public static func success(
        filesReplaced: Int = 0,
        directoriesRenamed: Int = 0,
        filesRenamed: Int = 0,
        duration: TimeInterval = 0
    ) -> RenameResult {
        RenameResult(
            success: true,
            filesReplaced: filesReplaced,
            directoriesRenamed: directoriesRenamed,
            filesRenamed: filesRenamed,
            errors: [],
            warnings: [],
            duration: duration
        )
    }

    public static func failure(_ errors: [String]) -> RenameResult {
        RenameResult(
            success: false,
            filesReplaced: 0,
            directoriesRenamed: 0,
            filesRenamed: 0,
            errors: errors,
            warnings: [],
            duration: 0
        )
    }
}

public enum RenamerError: LocalizedError {
    case sourceNotFound(String)
    case sourceNotDirectory(String)
    case emptyPrefix(String)
    case prefixesIdentical
    case targetExists(String)
    case copyFailed(String)
    case replacementFailed(String)
    case renameFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path):
            return "源文件夹不存在: \(path)"
        case .sourceNotDirectory(let path):
            return "源路径不是文件夹: \(path)"
        case .emptyPrefix(let name):
            return "\(name)不能为空"
        case .prefixesIdentical:
            return "旧前缀和新前缀不能相同"
        case .targetExists(let path):
            return "目标文件夹已存在: \(path)"
        case .copyFailed(let reason):
            return "文件复制失败: \(reason)"
        case .replacementFailed(let reason):
            return "内容替换失败: \(reason)"
        case .renameFailed(let reason):
            return "重命名失败: \(reason)"
        }
    }
}

public enum StepStatus {
    case pending
    case inProgress
    case completed
    case failed(String)

    public var symbol: String {
        switch self {
        case .pending: return "○"
        case .inProgress: return "◐"
        case .completed: return "✓"
        case .failed: return "✗"
        }
    }

    public var description: String {
        switch self {
        case .pending: return "等待中"
        case .inProgress: return "处理中"
        case .completed: return "完成"
        case .failed(let msg): return "失败: \(msg)"
        }
    }
}
