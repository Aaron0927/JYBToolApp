# BranchSwitch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现公版切换工具 - 选择主仓库并切换分支后，同步更新所有子模块到各自配置的分支。

**Architecture:** 基于已有的 GitModuleService 和 ProcessRunner，新增分支获取和主仓库切换功能，重新设计 ViewModel 和 View。

**Tech Stack:** Swift, SwiftUI, @Observable, BranchSwitch Package

---

## 文件结构

```
Packages/BranchSwitch/
├── Sources/BranchSwitch/
│   ├── Models/
│   │   └── Submodule.swift              # 已有
│   ├── Services/
│   │   ├── GitModuleService.swift       # 修改：新增 getBranches, checkoutMainRepo
│   │   └── ProcessRunner.swift          # 已有
│   ├── ViewModels/
│   │   └── BranchSwitchViewModel.swift  # 重写：新流程
│   └── Views/
│       └── BranchSwitchView.swift       # 重写：新布局
└── Tests/BranchSwitchTests/
    ├── SubmoduleTests.swift             # 已有
    └── GitModuleServiceTests.swift      # 已有
```

---

## Task 1: 扩展 GitModuleService

**Files:**
- Modify: `Packages/BranchSwitch/Sources/BranchSwitch/Services/GitModuleService.swift`

- [ ] **Step 1: 添加 getBranches 方法**

在 `GitModuleService` 类中添加：

```swift
public func getBranches(at repoPath: String) throws -> [String] {
    let processRunner = ProcessRunner()
    let output = try processRunner.run("git branch", at: repoPath)

    var branches: [String] = []
    for line in output.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        // 移除 "* " 前缀（当前分支）
        let branch = trimmed.hasPrefix("* ") ? String(trimmed.dropFirst(2)) : trimmed
        branches.append(branch)
    }
    return branches
}
```

- [ ] **Step 2: 添加 checkoutMainRepo 方法**

```swift
public func checkoutMainRepo(branch: String, at repoPath: String) throws {
    let processRunner = ProcessRunner()
    _ = try processRunner.run("git checkout \(branch)", at: repoPath)
    _ = try processRunner.run("git pull", at: repoPath)
}
```

- [ ] **Step 3: 提交**

```bash
cd /Users/kim/Desktop/开发工具/JYBToolApp
git add Packages/BranchSwitch/Sources/BranchSwitch/Services/GitModuleService.swift
git commit -m "feat(BranchSwitch): add getBranches and checkoutMainRepo methods"
```

---

## Task 2: 重写 BranchSwitchViewModel

**Files:**
- Modify: `Packages/BranchSwitch/Sources/BranchSwitch/ViewModels/BranchSwitchViewModel.swift`

- [ ] **Step 1: 重写 ViewModel**

```swift
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
```

- [ ] **Step 2: 提交**

```bash
git add Packages/BranchSwitch/Sources/BranchSwitch/ViewModels/BranchSwitchViewModel.swift
git commit -m "feat(BranchSwitch): rewrite ViewModel for new flow"
```

---

## Task 3: 重写 BranchSwitchView

**Files:**
- Modify: `Packages/BranchSwitch/Sources/BranchSwitch/Views/BranchSwitchView.swift`

- [ ] **Step 1: 重写 View**

```swift
import SwiftUI

public struct BranchSwitchView: View {
    @State private var viewModel = BranchSwitchViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 仓库选择区
            HStack {
                Text("仓库路径：")
                TextField("选择仓库目录", text: $viewModel.repoPath)
                    .textFieldStyle(.roundedBorder)
                Button("浏览...") {
                    viewModel.selectRepository()
                }
            }

            // 分支选择
            if !viewModel.branches.isEmpty {
                HStack {
                    Text("分支：")
                    Picker("", selection: $viewModel.selectedBranch) {
                        ForEach(viewModel.branches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            Divider()

            // 子模块预览
            if !viewModel.submodules.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("子模块预览")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.submodules) { submodule in
                                HStack {
                                    Text(submodule.name)
                                    Text("→")
                                        .foregroundStyle(.secondary)
                                    Text(submodule.branch)
                                        .foregroundStyle(.blue)
                                    Spacer()
                                }
                                .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color.black.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 8))

                    HStack {
                        Spacer()
                        Button("确认切换") {
                            viewModel.switchBranch()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.isConfirmEnabled || viewModel.isLoading)
                    }
                }
            }

            Divider()

            // 日志区
            VStack(alignment: .leading, spacing: 8) {
                Text("日志")
                    .font(.headline)

                ScrollView {
                    ScrollViewReader { proxy in
                        ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .id(index)
                        }
                        .onChange(of: viewModel.logs.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo(viewModel.logs.count - 1)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add Packages/BranchSwitch/Sources/BranchSwitch/Views/BranchSwitchView.swift
git commit -m "feat(BranchSwitch): rewrite View with new layout"
```

---

## Task 4: 构建并测试

- [ ] **Step 1: 构建项目**

```bash
cd /Users/kim/Desktop/开发工具/JYBToolApp
xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期: BUILD SUCCEEDED

- [ ] **Step 2: 运行测试**

```bash
swift test -C Packages/BranchSwitch
```

预期: All tests passed

- [ ] **Step 3: 提交所有更改**

```bash
git add -A
git commit -m "feat(BranchSwitch): complete implementation"
```

---

## 验证方式

手动测试：
1. 选择一个有子模块的仓库（如 `/Users/kim/Desktop/TradeBook_App`）
2. 验证分支下拉框显示正确
3. 验证子模块预览显示正确（各子模块目标分支）
4. 选择目标分支，点击确认切换
5. 检查日志输出
6. 验证主仓库和子模块分支是否正确切换
