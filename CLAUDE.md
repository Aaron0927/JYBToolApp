# JYBToolApp

macOS 工具箱应用，使用 SwiftUI 开发。

## 技术栈

- Swift 6 / SwiftUI / SwiftData
- Xcode 项目（手动管理包，非 SPM 集成）

## 开发命令

```bash
# 构建
xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug build

# 测试
xcodebuild test -project JYBToolApp.xcodeproj -scheme JYBToolApp
```

## 关键约定

### Swift 并发
- 使用 `@Observable @MainActor` 管理共享数据
- 优先 async/await，不使用基于闭包的异步变体
- 不使用 `ObservableObject`、`@Published`、`@StateObject`

### SwiftUI
- 使用 `foregroundStyle()` 而非 `foregroundColor()`
- 使用 `navigationDestination(for:)` 和 `NavigationStack`
- 不使用 `onTapGesture()`（用 `Button`）
- 文本格式化使用 `FormatStyle` API

### 代码格式
- 缩进: 2 空格
- 注释语言: 简体中文

## 包结构

```
Packages/
├── BranchSwitch/       # Git 分支切换工具
│   └── Sources/BranchSwitch/
│       ├── Models/     # Repo, RepoConfig
│       ├── Services/   # GitModuleService, ProcessRunner
│       ├── ViewModels/ # BranchSwitchViewModel
│       └── Views/      # BranchSwitchView
├── ProjectCopyTool/    # 项目复制工具
│   └── Sources/ProjectCopyTool/
│       ├── Models/     # ProjectRenamer, FileProcessor
│       ├── ViewModels/ # RenamerViewModel
│       └── Views/     # ContentView, ConfigFormView
└── JYBLog/             # 日志模块
    └── Sources/JYBLog/
        └── LogManager.swift
```

## 重要文件

- **AGENTS.md** — 详细开发指南（Swift/SwiftUI/SwiftData 指令、代码规范）
