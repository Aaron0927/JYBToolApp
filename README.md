# JYBToolApp

macOS 工具箱应用，使用 SwiftUI 开发，包含多个实用工具提升开发效率。

## 功能列表

### 公版工具

- **主仓库子模块切换** - 切换主仓库分支并同步该分支配置的子模块
- **公版依赖仓库** - 读取 `fastlane/repos.yml`，按配置切换分支或 Tag，并一键拉取全部仓库

### 私版工具

- **私版券商切换** - 按 `repos.yaml` 逐仓切换分支，支持自动保存与恢复本地修改
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
    ├── ToolUI/              # 跨工具共享的 SwiftUI 组件
    ├── JYBLog/              # 统一日志包
    ├── ProjectSwitchTool/    # 私版券商仓库切换
    ├── BranchSwitch/         # 子模块与公版依赖仓库切换
    └── ProjectCopyTool/      # 项目复制工具
```

全应用需求、交互原型、UI 规则和工程约束见 [`docs/product/README.md`](docs/product/README.md)。

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

# 运行 Swift Package 测试
swift test --package-path Packages/ProjectCopyTool
swift test --package-path Packages/BranchSwitch
swift test --package-path Packages/ProjectSwitchTool
```

## 工具使用

### 私版券商切换

1. 在工作目录创建 `repos.yaml`：

```yaml
org: your-org-name
repos:
  repo-name-1: target-branch
  repo-name-2: target-branch
```

2. 在应用中选择配置仓库
3. 检查逐仓目标和工作区状态
4. 确认批量切换

### 主仓库子模块切换

1. 选择主仓库目录
2. 读取主仓库分支和子模块配置
3. 检查当前与目标分支后确认切换

### 公版依赖仓库

1. 选择主工程目录
2. 读取本地分支并加载 `fastlane/repos.yml`
3. 检查分支或 Tag 目标后确认切换，或确认拉取全部最新代码

### 私版项目复制

1. 添加源项目和目标路径
2. 输入旧前缀和新前缀
3. 预览替换摘要并确认复制

## 开发规范

- 使用 `@Observable @MainActor` 管理共享数据
- 优先使用 async/await API
- SwiftUI 规范见 `AGENTS.md`

## 许可证

MIT License
