# JYBToolApp

macOS 工具箱应用，使用 SwiftUI 开发，包含多个实用工具提升开发效率。

## 功能列表

### Git 工具

- **切换券商** - 批量切换 Git 仓库分支，支持自动 stash/pull
- **公版切换** - 批量更新子模块到指定分支

### 项目工具

- **私版项目复制** - 复制并重命名项目，支持批量替换前缀、文件内容、plist 等

## 项目结构

```
JYBToolApp/
├── JYBToolApp/              # 主应用入口
│   ├── JYBToolAppApp.swift  # @main 入口
│   ├── AppDelegate.swift
│   ├── Models/Tool.swift    # 工具定义
│   ├── Views/
│   │   ├── ContentView.swift
│   │   └── LogPanelView.swift  # 统一日志面板
│   └── ViewModels/ContentViewModel.swift
└── Packages/
    ├── JYBLog/              # 统一日志包
    ├── ProjectSwitchTool/    # Git 分支切换器
    ├── BranchSwitch/         # 公版分支切换
    └── ProjectCopyTool/      # 项目复制工具
```

## 统一日志

日志系统（JYBLog）提供统一的日志输出：

- 5 个日志级别：debug、info、success、warning、error
- 可折叠/展开的底部面板
- 可拖动调整高度（收起 40px，展开 100-400px）
- 日志级别过滤
- 自动滚动到最新日志

## 构建命令

```bash
# 构建主应用
xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug build

# 运行测试
xcodebuild test -project JYBToolApp.xcodeproj -scheme JYBToolApp

# 运行指定测试
xcodebuild test -project JYBToolApp.xcodeproj -scheme ProjectSwitchTool -only-testing:ProjectSwitchToolTests/GitSwitcherTests
```

## 工具使用

### 切换券商

1. 在工作目录创建 `repos.yaml`：

```yaml
org: your-org-name
repos:
  repo-name-1: target-branch
  repo-name-2: target-branch
```

2. 在应用中选择工作目录
3. 点击"开始切换"

### 公版切换

1. 选择主仓库路径
2. 从下拉列表选择目标分支
3. 确认切换所有子模块

### 私版项目复制

1. 添加源项目和目标路径
2. 输入旧前缀和新前缀
3. 点击开始复制

## 开发规范

- 使用 `@Observable @MainActor` 管理共享数据
- 优先使用 async/await API
- SwiftUI 规范见 `AGENTS.md`

## 许可证

MIT License
