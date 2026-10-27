import Foundation
import SwiftUI
import AppKit
import JYBLog

@Observable
@MainActor
public final class RenamerViewModel {
    public var sourceTargetPairs: [SourceTargetPair] = []
    public var oldPrefix: String = ""
    public var newPrefix: String = ""
    public var autoOpenProject: Bool = false
    public var modifyConfigFiles: Bool = true

    public var isRunning: Bool = false
    public var isSuccess: Bool = false
    public var errorMessage: String?

    public var stepStatuses: [String: StepStatus] = [:]
    public var result: RenameResult?
    
    public var projectURLs: [URL] {
        sourceTargetPairs.compactMap { pair in
            let targetURL = URL(fileURLWithPath: pair.targetPath)
            let xcworkspace = targetURL.appendingPathExtension("xcworkspace")
            let xcodeproj = targetURL.appendingPathExtension("xcodeproj")
            
            if FileManager.default.fileExists(atPath: xcworkspace.path) {
                return xcworkspace
            } else if FileManager.default.fileExists(atPath: xcodeproj.path) {
                return xcodeproj
            }
            return nil
        }
    }
    
    private var renameTask: Task<Void, Never>?

    public var steps: [String] {
        [
            "复制源码路径",
            "替换源代码内容",
            "替换 .plist 内容",
            "替换 Xcode 项目文件",
            "替换 Podfile 内容",
            "替换 pbxproj.json 内容",
            "修改文件权限",
            "重命名目录",
            "重命名文件",
            "清理旧 Pods 配置",
            "清理 Xcode DerivedData 缓存",
            "验证重命名结果"
        ]
    }
    
    public var isValidPairs: Bool {
        guard !sourceTargetPairs.isEmpty else { return false }
        let fileManager = FileManager.default
        return sourceTargetPairs.allSatisfy { pair in
            let sourcePath = pair.sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetPath = pair.targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sourcePath.isEmpty, !targetPath.isEmpty else { return false }

            var sourceIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourcePath, isDirectory: &sourceIsDirectory),
                  sourceIsDirectory.boolValue else { return false }

            let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
            let targetURL = URL(fileURLWithPath: targetPath, isDirectory: true).standardizedFileURL
            let sourceURLPath = sourceURL.path.hasSuffix("/") ? sourceURL.path : sourceURL.path + "/"
            let targetURLPath = targetURL.path.hasSuffix("/") ? targetURL.path : targetURL.path + "/"
            guard sourceURL != targetURL,
                  !targetURL.path.hasPrefix(sourceURLPath),
                  !sourceURL.path.hasPrefix(targetURLPath) else { return false }

            var targetIsDirectory: ObjCBool = false
            return !fileManager.fileExists(atPath: targetPath, isDirectory: &targetIsDirectory) || targetIsDirectory.boolValue
        }
    }
    
    public var canStart: Bool {
        !sourceTargetPairs.isEmpty &&
          !oldPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
          !newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
          oldPrefix.trimmingCharacters(in: .whitespacesAndNewlines) != newPrefix.trimmingCharacters(in: .whitespacesAndNewlines) &&
          !isRunning &&
          isValidPairs
    }
    
    public init() {}
    
    public func addSourceTargetPair() {
        sourceTargetPairs.append(SourceTargetPair())
    }
    
    public func removeSourceTargetPair(at index: Int) {
        guard index >= 0 && index < sourceTargetPairs.count else { return }
        sourceTargetPairs.remove(at: index)
    }
    
    public func selectSourcePath(at index: Int) {
        guard index >= 0 && index < sourceTargetPairs.count else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择源项目文件夹"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourceTargetPairs[index].sourcePath = url.path
        }
    }
    
    public func selectTargetPath(at index: Int) {
        guard index >= 0 && index < sourceTargetPairs.count else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "选择目标文件夹"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourceTargetPairs[index].targetPath = url.path
        }
    }
    
    public func startRename() {
        let filteredPairs = sourceTargetPairs.map { pair in
            SourceTargetPair(
                id: pair.id,
                sourcePath: pair.sourcePath.trimmingCharacters(in: .whitespacesAndNewlines),
                targetPath: pair.targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let config = RenamerConfig(
            sourceTargetPairs: filteredPairs,
            oldPrefix: oldPrefix.trimmingCharacters(in: .whitespacesAndNewlines),
            newPrefix: newPrefix.trimmingCharacters(in: .whitespacesAndNewlines),
            autoOpenProject: autoOpenProject,
            modifyConfigFiles: modifyConfigFiles
        )

        do {
            try config.validate()
        } catch {
            errorMessage = error.localizedDescription
            LogManager.shared.error("配置验证失败: \(error.localizedDescription)")
            return
        }

        isRunning = true
        errorMessage = nil
        result = nil
        stepStatuses = [:]

        for step in steps {
            stepStatuses[step] = .pending
        }

        LogManager.shared.info("开始复制项目...")

        renameTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let viewModel = self
            let renameResult = await Task.detached(priority: .userInitiated) { [viewModel] in
                let renamer = ProjectRenamer(config: config)
                return renamer.execute { [viewModel] step, status in
                    Task { @MainActor in
                        viewModel.stepStatuses[step] = status
                        switch status {
                        case .inProgress:
                            LogManager.shared.info("执行中: \(step)")
                        case .completed:
                            LogManager.shared.success("完成: \(step)")
                        case .failed(let error):
                            LogManager.shared.error("失败: \(step) - \(error)")
                        case .pending:
                            break
                        }
                    }
                }
            }.value

            self.isRunning = false
            self.result = renameResult
            self.isSuccess = renameResult.success

            if renameResult.success {
                if self.autoOpenProject {
                    for projectURL in config.projectURLs {
                        NSWorkspace.shared.open(projectURL)
                    }
                }
                LogManager.shared.success("项目复制成功！耗时: \(renameResult.duration.formatted(.number.precision(.fractionLength(2))))秒")
                LogManager.shared.info("替换文件数: \(renameResult.filesReplaced), 重命名目录数: \(renameResult.directoriesRenamed), 重命名文件数: \(renameResult.filesRenamed)")
            } else {
                LogManager.shared.error("项目复制失败: \(renameResult.errors.joined(separator: ", "))")
            }
        }
    }

    public func reset() {
        renameTask?.cancel()
        sourceTargetPairs = []
        oldPrefix = ""
        newPrefix = ""
        autoOpenProject = false
        modifyConfigFiles = true
        isRunning = false
        isSuccess = false
        errorMessage = nil
        stepStatuses = [:]
        result = nil
    }
}
