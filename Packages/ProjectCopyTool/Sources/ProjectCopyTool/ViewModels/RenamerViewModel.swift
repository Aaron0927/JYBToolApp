import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
public final class RenamerViewModel {
    public var sourceTargetPairs: [SourceTargetPair] = []
    public var oldPrefix: String = ""
    public var newPrefix: String = ""
    public var autoOpenProject: Bool = false
    public var modifyConfigFiles: Bool = true
    
    public var isRunning: Bool = false
    public var isCompleted: Bool = false
    public var isSuccess: Bool = false
    public var showError: Bool = false
    public var errorMessage: String = ""
    
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
            !pair.sourcePath.isEmpty && 
            !pair.targetPath.isEmpty &&
            fileManager.fileExists(atPath: pair.sourcePath)
        }
    }
    
    public var canStart: Bool {
        !sourceTargetPairs.isEmpty && !oldPrefix.isEmpty && !newPrefix.isEmpty && !isRunning && isValidPairs
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
        let filteredPairs = sourceTargetPairs.filter { 
            !$0.sourcePath.isEmpty && !$0.targetPath.isEmpty 
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
            showError = true
            return
        }
        
        isRunning = true
        isCompleted = false
        stepStatuses = [:]
        
        for step in steps {
            stepStatuses[step] = .pending
        }
        
        renameTask = Task { @MainActor in
            let renamer = ProjectRenamer(config: config)
            
            let renameResult = renamer.execute { [weak self] step, status in
                Task { @MainActor in
                    self?.stepStatuses[step] = status
                }
            }
            
            self.isRunning = false
            self.isCompleted = true
            self.result = renameResult
            self.isSuccess = renameResult.success
            
            if !renameResult.success {
                self.errorMessage = renameResult.errors.joined(separator: "\n")
                self.showError = true
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
        isCompleted = false
        isSuccess = false
        showError = false
        errorMessage = ""
        stepStatuses = [:]
        result = nil
    }
}
