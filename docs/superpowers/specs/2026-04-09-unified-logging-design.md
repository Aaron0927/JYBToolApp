# 统一日志系统设计文档

## 概述

为 JYBToolApp 项目创建一个统一的日志包 `JYBLog`，实现类似 Xcode Debug 区域的日志面板功能。

## 需求

- 日志面板位于页面底部，可收起/展开
- 收起状态：40px 高度，只显示标题栏和展开按钮
- 展开状态：100px - 400px 可调节高度
- 高度可通过拖动调整
- 日志内容可滚动查看

## 日志级别

5 级日志系统：
- `debug` - 调试信息（灰色）
- `info` - 一般信息（蓝色）
- `success` - 成功操作（绿色）
- `warning` - 警告（橙色）
- `error` - 错误（红色）

## 日志格式

每条日志显示：`[HH:mm:ss] [level] 消息内容`

示例：
```
[10:30:15] [info] 开始切换分支...
[10:30:16] [success] repo1 分支切换成功
[10:30:17] [error] repo2 分支切换失败: branch not found
```

## 架构设计

### Package 结构

```
Packages/
└── JYBLog/                          # 新增日志包
    └── Sources/JYBLog/
        ├── Models/
        │   └── LogEntry.swift       # 日志条目模型
        ├── LogManager.swift         # 中央日志管理器 (@Observable)
        └── JYBLog.swift            # 包入口（导出）
```

### LogEntry 模型

```swift
public struct LogEntry: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String

    public init(level: LogLevel, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}

public enum LogLevel: String, CaseIterable {
    case debug, info, success, warning, error

    public var icon: String { /* SF Symbol */ }
    public var color: Color { /* 级别对应颜色 */ }
}
```

### LogManager 设计

```swift
@Observable
@MainActor
public final class LogManager {
    public static let shared = LogManager()

    public var entries: [LogEntry] = []
    public var isExpanded: Bool = false
    public var expandedHeight: CGFloat = 200
    public var visibleLevels: Set<LogLevel> = Set(LogLevel.allCases)

    public func debug(_ message: String)
    public func info(_ message: String)
    public func success(_ message: String)
    public func warning(_ message: String)
    public func error(_ message: String)
    public func clear()
}
```

## UI 设计

### LogPanelView

```
┌─────────────────────────────────────────────────────────────┐
│ ▼ 日志 (128)              [全部] [debug] [info] [success]  │
│                          [warning] [error]      [清空] [×]  │
├─────────────────────────────────────────────────────────────┤
│ [10:30:15] [info]    开始切换分支...                        │
│ [10:30:16] [success] repo1 分支切换成功                     │
│ [10:30:17] [error]   repo2 分支切换失败                     │
│ [10:30:18] [debug]   重试次数: 1/3                           │
│ ...                                                         │
│                    (可滚动)                                 │
└─────────────────────────────────────────────────────────────┘
                         ↑ 可拖动调整高度 (100-400px)
```

### 组件层级

```
ContentView
└── VStack(spacing: 0)
    ├── NavigationSplitView (主内容)
    │   └── Tool Views (GitSwitcherView, etc.)
    └── LogPanelView
        ├── DragHandle (拖动把手)
        ├── HeaderBar (标题栏 + 过滤器 + 按钮)
        └── LogScrollView (日志列表)
```

### 交互

1. **收起/展开**：点击标题栏或拖动把手指上下拖动
2. **拖动调整高度**：拖动把手区域，限制在 100-400px
3. **滚动**：鼠标滚轮或触控板
4. **清空**：点击清空按钮
5. **过滤**：点击级别按钮切换该级别显示/隐藏
6. **自动展开**：当有新日志且处于收起状态时，自动展开

## 集成方式

### 主应用集成

```swift
// ContentView.swift
import JYBLog

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView { ... }
            LogPanelView()
        }
    }
}
```

### 各工具使用

```swift
// GitSwitcherViewModel.swift
LogManager.shared.info("开始切换分支...")
LogManager.shared.success("\(repo.name) 切换成功")
LogManager.shared.error("\(repo.name) 切换失败: \(error)")
```

## 实现文件清单

| 文件 | 用途 |
|------|------|
| `Packages/JYBLog/Sources/JYBLog/Models/LogEntry.swift` | 日志条目模型 |
| `Packages/JYBLog/Sources/JYBLog/LogManager.swift` | 中央日志管理器 |
| `Packages/JYBLog/Sources/JYBLog/JYBLog.swift` | 包入口 |
| `JYBToolApp/Views/LogPanelView.swift` | 日志面板视图 |
| `JYBToolApp/Views/ContentView.swift` | 集成日志面板 |

## 依赖

无外部依赖，纯 SwiftUI 实现。

## 验证方式

1. 构建成功：`xcodebuild build`
2. 功能验证：
   - 打开应用，日志面板默认收起
   - 点击展开，拖动调整高度
   - 各工具操作，验证日志记录
   - 测试过滤、清空功能
   - 验证自动展开行为
