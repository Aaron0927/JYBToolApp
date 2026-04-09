# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

macOS 工具箱应用，使用 SwiftUI 开发。包含两个本地 Swift Package：
- **ProjectSwitchTool** - Git 分支批量切换工具
- **ProjectCopyTool** - 项目复制/重命名工具

## 构建命令

```bash
# 构建主应用
xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug build

# 运行测试
xcodebuild test -project JYBToolApp.xcodeproj -scheme JYBToolApp

# 运行指定测试
xcodebuild test -project JYBToolApp.xcodeproj -scheme ProjectSwitchTool -only-testing:ProjectSwitchToolTests/GitSwitcherTests
```

## 架构

```
JYBToolApp/
├── JYBToolApp/              # 主应用入口
│   ├── JYBToolAppApp.swift  # @main 入口
│   ├── AppDelegate.swift
│   ├── Models/Tool.swift    # 工具定义
│   ├── Views/ContentView.swift
│   └── ViewModels/ContentViewModel.swift
└── Packages/
    ├── ProjectSwitchTool/   # Git 分支切换器
    │   └── Sources/ProjectSwitchTool/
    │       ├── Models/      # Repo, RepoConfig
    │       ├── Services/    # GitService, ProcessRunner
    │       ├── ViewModels/  # GitSwitcherViewModel
    │       └── Views/      # GitSwitcherView
    └── ProjectCopyTool/     # 项目复制工具
        └── Sources/ProjectCopyTool/
            ├── Models/      # ProjectRenamer, FileProcessor, RenameResult
            ├── ViewModels/  # RenamerViewModel
            └── Views/       # ContentView, ConfigFormView, ProgressView
```

## 开发规范

### Swift 并发
- 使用 `@Observable @MainActor` 管理共享数据
- 优先使用 async/await API，不使用基于闭包的异步变体
- 不使用 `ObservableObject`、`@Published`、`@StateObject`

### SwiftUI
- 使用 `foregroundStyle()` 而非 `foregroundColor()`
- 使用 `clipShape(.rect(cornerRadius:))` 而非 `cornerRadius()`
- 使用 `navigationDestination(for:)` 和 `NavigationStack`
- 不使用 `onTapGesture()`（用 `Button`）
- 不使用 `GeometryReader`（优先用 `containerRelativeFrame()`）
- 文本格式化使用 `FormatStyle` API，不使用 `DateFormatter`/`NumberFormatter`

### GitSwitcher 使用方法
1. 在工作目录创建 `repos.yaml`：
```yaml
org: your-org-name
repos:
  repo-name-1: target-branch
  repo-name-2: target-branch
```
2. 在应用中选择工作目录
3. 点击"开始切换"

### 依赖
- **Yams** - YAML 解析（ProjectSwitchTool）
- **Rainbow** - 终端彩色输出（ProjectSwitchTool）

## 已有规范文件

详细开发规范见 `AGENTS.md`，包含 Swift/SwiftUI/SwiftData 指令、代码格式规范、错误处理等。
