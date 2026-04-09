import Foundation
import AppKit

@Observable
@MainActor
public final class BranchSwitchViewModel {
    public var repoPath: String = ""
    public var branches: [String] = []
    public var selectedBranch: String = ""
    public var submodules: [Submodule] = []
    public var logs: [String] = []
    public var isLoading: Bool = false
    public var isConfirmEnabled: Bool = false

    private let service = GitModuleService()

    public init() {}

    public func selectRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
            loadData()
        }
    }

    public func loadData() {
        guard !repoPath.isEmpty else { return }
        isLoading = true
        logs.append("正在加载数据...")

        do {
            branches = try service.getBranches(at: repoPath)
            submodules = try service.getSubmodules(at: repoPath)

            if let first = branches.first {
                selectedBranch = first
            }

            logs.append("已加载 \(branches.count) 个分支")
            logs.append("已加载 \(submodules.count) 个子模块")
            isConfirmEnabled = true
        } catch {
            logs.append("加载失败: \(error.localizedDescription)")
            isConfirmEnabled = false
        }

        isLoading = false
    }

    public func switchBranch() {
        guard !selectedBranch.isEmpty, !repoPath.isEmpty else { return }
        isLoading = true
        logs.append("正在切换到分支 \(selectedBranch)...")

        do {
            try service.checkoutMainRepo(branch: selectedBranch, at: repoPath)
            logs.append("✓ 主仓库切换成功")

            for submodule in submodules {
                logs.append("更新子模块: \(submodule.name) -> \(submodule.branch)")
                let result = service.updateSubmodule(submodule, at: repoPath)

                if result.success {
                    logs.append("✓ \(submodule.name) 更新成功")
                } else {
                    logs.append("✗ \(submodule.name) 更新失败: \(result.error ?? "未知错误")")
                }
            }

            logs.append("切换完成")
        } catch {
            logs.append("✗ 切换失败: \(error.localizedDescription)")
        }

        isLoading = false
    }
}
