import Foundation
import AppKit
import JYBLog

public struct SubmoduleBranchInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let currentBranch: String
    public let targetBranch: String

    public init(id: String = UUID().uuidString, name: String, path: String, currentBranch: String, targetBranch: String) {
        self.id = id
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
        self.targetBranch = targetBranch
    }
}

@Observable
@MainActor
public final class BranchSwitchViewModel {
    private static let lastRepoPathKey = "BranchSwitch.lastRepoPath"
    private static let lastSelectedBranchKey = "BranchSwitch.lastSelectedBranch"

    public var repoPath: String = ""
    public var branches: [String] = []
    public var currentBranch: String = ""
    public var selectedBranch: String = ""
    public var submoduleBranches: [SubmoduleBranchInfo] = []
    public var isLoading: Bool = false
    public var isConfirmEnabled: Bool = false
    public var errorMessage: String?
    public var operationSummary: String?
    public var switchResults: [String: String] = [:]

    // 保存当前切换 Task 的引用，用于取消和超时处理
    private var currentSwitchTask: Task<Void, Never>?

    public var hasWorkspace: Bool {
        guard !repoPath.isEmpty else { return false }
        if findWorkspace(in: repoPath) != nil {
            return true
        }
        for info in submoduleBranches {
            let submodulePath = (repoPath as NSString).appendingPathComponent(info.path)
            if findWorkspace(in: submodulePath) != nil {
                return true
            }
        }
        return false
    }

    private let service = GitModuleService()

    public init() {
        // 加载上次选择的仓库路径
        if let lastPath = UserDefaults.standard.string(forKey: Self.lastRepoPathKey) {
            repoPath = lastPath
        }
    }

    private func saveLastRepoPath() {
        UserDefaults.standard.set(repoPath, forKey: Self.lastRepoPathKey)
    }

    private func saveLastSelectedBranch() {
        UserDefaults.standard.set(selectedBranch, forKey: Self.lastSelectedBranchKey)
    }

    private func loadLastSelectedBranch() -> String? {
        return UserDefaults.standard.string(forKey: Self.lastSelectedBranchKey)
    }

    public func selectRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
            branches = []
            currentBranch = ""
            selectedBranch = ""
            submoduleBranches = []
            errorMessage = nil
            saveLastRepoPath()
            loadData()
        }
    }

    public func loadData() {
        guard !repoPath.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            await loadDataAsync()
        }
    }

    private func loadDataAsync() async {
        LogManager.shared.info("正在加载数据...")

        // 在 Task 开始前捕获需要的值
        let currentRepoPath = repoPath

        // 在后台执行所有 git 操作
        let result = await Task.detached { () -> LoadResult? in
            do {
                let service = GitModuleService()
                let allBranches = try service.getBranches(at: currentRepoPath)
                let submodules = try service.getSubmodules(at: currentRepoPath)
                let currentMainBranch = service.getCurrentBranch(at: currentRepoPath) ?? allBranches.first ?? ""

                var branchInfos: [SubmoduleBranchInfo] = []
                for submodule in submodules {
                    let submodulePath = (currentRepoPath as NSString).appendingPathComponent(submodule.path)
                    let currentBranch = service.getCurrentBranch(at: submodulePath) ?? "unknown"
                    branchInfos.append(SubmoduleBranchInfo(
                        name: submodule.name,
                        path: submodule.path,
                        currentBranch: currentBranch,
                        targetBranch: submodule.branch
                    ))
                }

                return LoadResult(
                    branches: allBranches,
                    currentBranch: currentMainBranch,
                    submoduleBranches: branchInfos
                )
            } catch {
                Task { @MainActor in
                    LogManager.shared.error("加载失败: \(error.localizedDescription)")
                }
                return nil
            }
        }.value

        // 在主线程更新 UI
        if let result = result {
            branches = result.branches
            currentBranch = result.currentBranch

            // 直接使用当前分支
            selectedBranch = result.currentBranch

            submoduleBranches = result.submoduleBranches
            LogManager.shared.success("已加载 \(branches.count) 个分支")
            LogManager.shared.success("已加载 \(submoduleBranches.count) 个子模块")
            isConfirmEnabled = true
        } else {
            currentBranch = ""
            errorMessage = "无法读取仓库信息；请检查路径、Git 状态和子模块配置。"
            LogManager.shared.error("加载失败")
            isConfirmEnabled = false
        }
        isLoading = false
        saveLastRepoPath()
    }

    private struct LoadResult: Sendable {
        let branches: [String]
        let currentBranch: String
        let submoduleBranches: [SubmoduleBranchInfo]
    }

    public func switchBranch() {
        guard !selectedBranch.isEmpty, !repoPath.isEmpty else { return }

        currentSwitchTask?.cancel()
        isLoading = true
        errorMessage = nil
        operationSummary = nil
        switchResults = [:]
        LogManager.shared.info("正在切换到分支 \(selectedBranch)...")

        let currentSelectedBranch = selectedBranch
        let currentRepoPath = repoPath

        currentSwitchTask = Task { @MainActor in
            do {
                let switchResult = try await self.performSwitchBranch(
                    branch: currentSelectedBranch,
                    repoPath: currentRepoPath,
                    timeout: 120
                )
                self.finishSwitchBranch(switchResult)
            } catch {
                self.finishSwitchBranch(SwitchResult(
                    success: false,
                    submoduleResults: [],
                    error: error.localizedDescription
                ))
            }
        }
    }

    private func performSwitchBranch(
        branch: String,
        repoPath: String,
        timeout: TimeInterval
    ) async throws -> SwitchResult {
        try await withThrowingTaskGroup(of: SwitchResult.self) { group in
            // 主工作任务
            group.addTask {
                try await Task.detached { () throws -> SwitchResult in
                    let service = GitModuleService()

                    // 1. 切换主仓库
                    try service.checkoutMainRepoWithLog(branch: branch, at: repoPath) { msg in
                        Task { @MainActor in LogManager.shared.debug(msg) }
                    }

                    // 2. 重新读取 .gitmodules 获取切换后的最新配置
                    Task { @MainActor in LogManager.shared.debug("读取 submodule 配置...") }
                    let newSubmodules = try service.getSubmodules(at: repoPath)
                    Task { @MainActor in LogManager.shared.debug("读取到 \(newSubmodules.count) 个 submodule") }

                    // 3. 并发更新所有子模块
                    var submoduleResults: [SubmoduleSwitchResult] = []
                    await withTaskGroup(of: SubmoduleSwitchResult.self) { subGroup in
                        for submodule in newSubmodules {
                            subGroup.addTask {
                                Task { @MainActor in LogManager.shared.debug("更新 submodule: \(submodule.name)") }
                                let result = await Task.detached {
                                    service.updateSubmodule(submodule, at: repoPath)
                                }.value
                                return SubmoduleSwitchResult(
                                    name: submodule.name,
                                    success: result.success,
                                    error: result.error
                                )
                            }
                        }
                        for await result in subGroup {
                            submoduleResults.append(result)
                        }
                    }

                    return SwitchResult(success: true, submoduleResults: submoduleResults, error: nil)
                }.value
            }

            // 超时任务：120s 后抛错，解除 UI 阻塞
            group.addTask {
                try await Task.sleep(for: .milliseconds(Int64(timeout * 1_000)))
                throw ProcessRunnerError.executionFailed("操作超时 (\(Int(timeout))秒)")
            }

            // 取第一个完成的结果（工作完成或超时）
            guard let result = try await group.next() else {
                throw ProcessRunnerError.executionFailed("内部错误：任务组为空")
            }
            group.cancelAll()
            return result
        }
    }

    @MainActor
    private func finishSwitchBranch(_ switchResult: SwitchResult) {
        let failedSubmoduleCount = switchResult.submoduleResults.filter { !$0.success }.count
        switchResults = Dictionary(uniqueKeysWithValues: switchResult.submoduleResults.map {
            ($0.name, $0.success ? "成功" : "失败")
        })
        operationSummary = "主仓库：\(switchResult.success ? "成功" : "失败")；子模块：成功 \(switchResult.submoduleResults.count - failedSubmoduleCount)，失败 \(failedSubmoduleCount)"
        if let error = switchResult.error {
            errorMessage = error
        } else if failedSubmoduleCount > 0 {
            errorMessage = "主仓库已切换，但有 \(failedSubmoduleCount) 个子模块更新失败。请查看日志。"
        } else {
            errorMessage = nil
        }

        // 在主线程更新 UI 和日志
        if switchResult.success {
            LogManager.shared.success("✓ 主仓库切换成功")

            for result in switchResult.submoduleResults {
                if result.success {
                    LogManager.shared.success("✓ \(result.name) 更新成功")
                } else {
                    LogManager.shared.error("✗ \(result.name) 更新失败: \(result.error ?? "未知错误")")
                }
            }
            LogManager.shared.success("切换完成")
            // 切换成功后保存分支选择
            saveLastSelectedBranch()
        } else {
            LogManager.shared.error("✗ 切换失败: \(switchResult.error ?? "未知错误")")
        }

        isLoading = false
        currentSwitchTask = nil
    }

    private struct SwitchResult: Sendable {
        let success: Bool
        let submoduleResults: [SubmoduleSwitchResult]
        let error: String?
    }

    private struct SubmoduleSwitchResult: Sendable {
        let name: String
        let success: Bool
        let error: String?
    }

    public func openInXcode() {
        guard !repoPath.isEmpty else { return }

        // 先检查主仓库是否有 workspace 或 project
        if let xcworkspace = findWorkspace(in: repoPath) {
            NSWorkspace.shared.openApplication(at: xcworkspace, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        // 遍历子仓库查找
        for info in submoduleBranches {
            let submodulePath = (repoPath as NSString).appendingPathComponent(info.path)
            if let xcworkspace = findWorkspace(in: submodulePath) {
                NSWorkspace.shared.openApplication(at: xcworkspace, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
    }

    private func findWorkspace(in path: String) -> URL? {
        let url = URL(fileURLWithPath: path)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return nil
        }
        if let workspace = entries.first(where: { $0.pathExtension == "xcworkspace" }) {
            return workspace
        }
        return entries.first(where: { $0.pathExtension == "xcodeproj" })
    }
}
