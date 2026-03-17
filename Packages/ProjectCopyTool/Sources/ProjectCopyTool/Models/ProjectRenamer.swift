import Foundation
import AppKit

public final class ProjectRenamer {
    private let config: RenamerConfig
    private let fileProcessor: FileProcessor
    private var stepStatuses: [String: StepStatus] = [:]

    private let steps: [(String, () throws -> Void)] = [
        ("复制源码路径", { }),
        ("替换源代码内容", { }),
        ("替换 .plist 内容", { }),
        ("替换 Xcode 项目文件", { }),
        ("替换 Podfile 内容", { }),
        ("替换 pbxproj.json 内容", { }),
        ("修改文件权限", { }),
        ("重命名目录", { }),
        ("重命名文件", { }),
        ("清理旧 Pods 配置", { }),
        ("清理 Xcode DerivedData 缓存", { }),
        ("验证重命名结果", { })
    ]

    public init(config: RenamerConfig) {
        self.config = config
        self.fileProcessor = FileProcessor(config: config)
    }

    public func execute(onStepChange: ((String, StepStatus) -> Void)? = nil) -> RenameResult {
        let startTime = Date()

        do {
            try config.validate()
        } catch {
            return .failure([error.localizedDescription])
        }

        updateStatus("复制源码路径", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.copyProject()
            updateStatus("复制源码路径", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("复制源码路径", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("替换源代码内容", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.replaceSourceContent()
            updateStatus("替换源代码内容", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("替换源代码内容", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("替换 .plist 内容", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.replacePlistContent()
            updateStatus("替换 .plist 内容", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("替换 .plist 内容", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("替换 Xcode 项目文件", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.replaceXcodeProjectFiles()
            updateStatus("替换 Xcode 项目文件", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("替换 Xcode 项目文件", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("替换 Podfile 内容", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.replacePodfileContent()
            updateStatus("替换 Podfile 内容", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("替换 Podfile 内容", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("替换 pbxproj.json 内容", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.replacePbxprojJson()
            updateStatus("替换 pbxproj.json 内容", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("替换 pbxproj.json 内容", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("修改文件权限", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.fixPermissions()
            updateStatus("修改文件权限", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("修改文件权限", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("重命名目录", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.renameDirectories()
            updateStatus("重命名目录", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("重命名目录", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("重命名文件", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.renameFiles()
            updateStatus("重命名文件", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("重命名文件", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("清理旧 Pods 配置", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.cleanPods()
            updateStatus("清理旧 Pods 配置", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("清理旧 Pods 配置", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("清理 Xcode DerivedData 缓存", status: .inProgress, handler: onStepChange)
        do {
            try fileProcessor.cleanDerivedData()
            updateStatus("清理 Xcode DerivedData 缓存", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("清理 Xcode DerivedData 缓存", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }

        updateStatus("验证重命名结果", status: .inProgress, handler: onStepChange)
        do {
            let _ = try fileProcessor.verify()
            updateStatus("验证重命名结果", status: .completed, handler: onStepChange)
        } catch {
            updateStatus("验证重命名结果", status: .failed(error.localizedDescription), handler: onStepChange)
            return .failure([error.localizedDescription])
        }
        
        if config.autoOpenProject {
            openProjects()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return RenameResult.success(
            filesReplaced: fileProcessor.filesReplaced,
            directoriesRenamed: fileProcessor.directoriesRenamed,
            filesRenamed: fileProcessor.filesRenamed,
            duration: duration
        )
    }

    public func getStepStatuses() -> [String: StepStatus] {
        return stepStatuses
    }

    private func updateStatus(_ step: String, status: StepStatus, handler: ((String, StepStatus) -> Void)?) {
        stepStatuses[step] = status
        handler?(step, status)
    }
    
    private func openProjects() {
        for projectURL in config.projectURLs {
            NSWorkspace.shared.open(projectURL)
        }
    }
}
