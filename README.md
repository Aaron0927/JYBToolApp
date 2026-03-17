# JYBToolApp

macOS 工具箱应用，使用 SwiftUI 开发。

## 功能列表

### 项目工具

- **Git 分支切换器** - 批量切换 Git 仓库分支

### 工具 (开发中)

- 文本工具
- 图片工具

## 项目结构

```
JYBToolApp/
├── Packages/
│   └── GitSwitcher/          # Git 分支切换器包
├── JYBToolApp/                # 主应用
│   ├── Models/
│   ├── Views/
│   └── ViewModels/
└── AGENTS.md
```

## GitSwitcher 包

Git 分支切换器是一个独立的 Swift Package，包含以下功能：

- 批量扫描 Git 仓库
- 读取当前分支和目标分支
- 自动 stash 未提交的更改
- 批量切换分支并 pull

### 依赖

- [Yams](https://github.com/jpsim/Yams) - YAML 解析

### 使用方法

1. 在工作目录下创建 `repos.yaml` 文件：

```yaml
org: your-org-name
repos:
  repo-name-1: target-branch
  repo-name-2: target-branch
```

2. 在应用中选择工作目录（repos.yaml 所在目录）
3. 点击"开始切换"按钮

### API 使用

```swift
import GitSwitcher

// 使用 ViewModel
let viewModel = GitSwitcherViewModel()
viewModel.selectWorkspace()
viewModel.switchWorkspace()

// 或使用视图
GitSwitcherView()
```

## 开发

### 构建项目

```bash
xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug build
```

### 运行测试

```bash
# 运行所有测试
xcodebuild test -project JYBToolApp.xcodeproj -scheme GitSwitcher

# 运行特定测试
xcodebuild test -project JYBToolApp.xcodeproj -scheme GitSwitcher -only-testing:RepoTests
```

## 添加新工具

1. 在 `JYBToolApp/Models/Tool.swift` 中添加工具定义
2. 在 `ContentViewModel` 中处理工具逻辑
3. 在 `ContentView` 的 detail 区域添加对应的视图

## 许可证

MIT License
