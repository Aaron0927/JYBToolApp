# 统一日志系统实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建 JYBLog 包和 LogPanelView，实现类似 Xcode Debug 区域的统一日志面板

**Architecture:** 创建独立的 JYBLog Swift Package，包含 LogEntry 模型和 LogManager 管理器。LogPanelView 作为 SwiftUI 视图组件添加到 ContentView 底部

**Tech Stack:** Swift, SwiftUI, @Observable, Swift Package Manager

---

## 文件结构

```
JYBToolApp/
├── Packages/
│   └── JYBLog/                              # 新建日志包
│       ├── Package.swift
│       └── Sources/JYBLog/
│           ├── Models/
│           │   └── LogEntry.swift         # 日志条目 + 级别枚举
│           ├── LogManager.swift            # 中央日志管理器
│           └── JYBLog.swift               # 包入口
├── JYBToolApp/
│   └── Views/
│       └── LogPanelView.swift             # 新建日志面板视图
└── JYBToolApp/Views/ContentView.swift     # 修改：集成日志面板
```

---

## Task 1: 创建 JYBLog Package.swift

**Files:**
- Create: `Packages/JYBLog/Package.swift`

- [ ] **Step 1: 创建 Package.swift**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JYBLog",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "JYBLog",
            targets: ["JYBLog"]
        ),
    ],
    targets: [
        .target(
            name: "JYBLog",
            dependencies: []
        ),
    ]
)
```

---

## Task 2: 创建 LogEntry 模型

**Files:**
- Create: `Packages/JYBLog/Sources/JYBLog/Models/LogEntry.swift`

- [ ] **Step 1: 创建 LogLevel 枚举和 LogEntry 结构体**

```swift
import Foundation
import SwiftUI

public enum LogLevel: String, CaseIterable, Codable, Sendable {
    case debug
    case info
    case success
    case warning
    case error

    public var icon: String {
        switch self {
        case .debug:   return "ladybug"
        case .info:    return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.circle"
        }
    }

    public var color: Color {
        switch self {
        case .debug:   return .gray
        case .info:    return .blue
        case .success: return .green
        case .warning: return .orange
        case .error:   return .red
        }
    }

    public var label: String {
        switch self {
        case .debug:   return "调试"
        case .info:    return "信息"
        case .success: return "成功"
        case .warning: return "警告"
        case .error:   return "错误"
        }
    }
}

public struct LogEntry: Identifiable, Equatable, Sendable {
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

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
```

---

## Task 3: 创建 LogManager

**Files:**
- Create: `Packages/JYBLog/Sources/JYBLog/LogManager.swift`

- [ ] **Step 1: 创建 LogManager 类**

```swift
import Foundation
import SwiftUI

@Observable
@MainActor
public final class LogManager: Sendable {
    public static let shared = LogManager()

    public var entries: [LogEntry] = []
    public var isExpanded: Bool = false
    public var panelHeight: CGFloat = 200
    public var visibleLevels: Set<LogLevel> = Set(LogLevel.allCases)

    public let minHeight: CGFloat = 100
    public let maxHeight: CGFloat = 400
    public let collapsedHeight: CGFloat = 40

    private init() {}

    public func debug(_ message: String) {
        addEntry(.debug, message: message)
    }

    public func info(_ message: String) {
        addEntry(.info, message: message)
    }

    public func success(_ message: String) {
        addEntry(.success, message: message)
    }

    public func warning(_ message: String) {
        addEntry(.warning, message: message)
    }

    public func error(_ message: String) {
        addEntry(.error, message: message)
    }

    public func clear() {
        entries.removeAll()
    }

    public func toggleLevel(_ level: LogLevel) {
        if visibleLevels.contains(level) {
            visibleLevels.remove(level)
        } else {
            visibleLevels.insert(level)
        }
    }

    public func filteredEntries() -> [LogEntry] {
        entries.filter { visibleLevels.contains($0.level) }
    }

    private func addEntry(_ level: LogLevel, message: String) {
        let entry = LogEntry(level: level, message: message)
        entries.append(entry)

        // 自动展开
        if !isExpanded {
            isExpanded = true
        }
    }
}
```

---

## Task 4: 创建 JYBLog 包入口

**Files:**
- Create: `Packages/JYBLog/Sources/JYBLog/JYBLog.swift`

- [ ] **Step 1: 创建包入口文件**

```swift
// JYBLog - 统一日志系统
// 使用方法: LogManager.shared.info("message")
public enum JYBLog {
    public static let version = "1.0.0"
}
```

---

## Task 5: 创建 LogPanelView

**Files:**
- Create: `JYBToolApp/JYBToolApp/Views/LogPanelView.swift`

- [ ] **Step 1: 创建 LogPanelView**

```swift
import SwiftUI
import JYBLog

struct LogPanelView: View {
    @State private var logManager = LogManager.shared
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    private var currentHeight: CGFloat {
        if logManager.isExpanded {
            return min(max(logManager.panelHeight + dragOffset, logManager.minHeight), logManager.maxHeight)
        }
        return logManager.collapsedHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // 拖动把手
            DragHandle()
                .gesture(dragGesture)

            // 标题栏
            headerBar

            // 日志列表
            if logManager.isExpanded {
                logListView
            }
        }
        .frame(height: currentHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.separator),
            alignment: .top
        )
    }

    private var headerBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    logManager.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: logManager.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text("日志 (\(logManager.entries.count))")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // 级别过滤器
            HStack(spacing: 4) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    FilterButton(
                        level: level,
                        isActive: logManager.visibleLevels.contains(level)
                    ) {
                        logManager.toggleLevel(level)
                    }
                }
            }

            Spacer()

            // 清空按钮
            Button {
                logManager.clear()
            } label: {
                Text("清空")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // 关闭按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    logManager.isExpanded = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logManager.filteredEntries()) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .onChange(of: logManager.entries.count) { _, _ in
                if let lastEntry = logManager.entries.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                if logManager.isExpanded {
                    dragOffset = -value.translation.height
                }
            }
            .onEnded { value in
                if logManager.isExpanded {
                    logManager.panelHeight = min(
                        max(logManager.panelHeight - value.translation.height, logManager.minHeight),
                        logManager.maxHeight
                    )
                }
                dragOffset = 0
            }
    }
}

struct DragHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
            )
    }
}

struct FilterButton: View {
    let level: LogLevel
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: level.icon)
                    .font(.system(size: 9))
                Text(level.label)
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isActive ? level.color.opacity(0.2) : Color.clear)
            .foregroundStyle(isActive ? level.color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? level.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(entry.formattedTime)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("[\(entry.level.label)]")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(entry.level.color)
                .frame(width: 40, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer()
        }
    }
}
```

---

## Task 6: 修改 ContentView 集成 LogPanelView

**Files:**
- Modify: `JYBToolApp/JYBToolApp/Views/ContentView.swift`

- [ ] **Step 1: 在 ContentView 中添加 LogPanelView**

在 `NavigationSplitView` 外包装 `VStack(spacing: 0)`，底部添加 `LogPanelView()`

修改后结构:
```swift
struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                // sidebar
            } detail: {
                // detail
            }
            LogPanelView()
        }
    }
}
```

---

## Task 7: 更新 GitSwitcherViewModel 使用 LogManager

**Files:**
- Modify: `Packages/ProjectSwitchTool/Sources/ProjectSwitchTool/ViewModels/GitSwitcherViewModel.swift`

- [ ] **Step 1: 替换 print 为 LogManager 调用**

将现有的 `logs.append(...)` 和 `print()` 调用替换为 `LogManager.shared.xxx()` 方法

---

## Task 8: 更新 BranchSwitchViewModel 使用 LogManager

**Files:**
- Modify: `Packages/BranchSwitch/Sources/BranchSwitch/ViewModels/BranchSwitchViewModel.swift`

- [ ] **Step 1: 替换日志调用为 LogManager**

---

## Task 9: 验证构建

- [ ] **Step 1: 运行构建命令**

```bash
cd /Users/kim/Desktop/开发工具/JYBToolApp
xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug build
```

**预期结果:** BUILD SUCCEEDED

---

## Task 10: 提交代码

- [ ] **Step 1: 提交所有更改**

```bash
git add Packages/JYBLog JYBToolApp/JYBToolApp/Views/LogPanelView.swift JYBToolApp/JYBToolApp/Views/ContentView.swift
git add Packages/ProjectSwitchTool/Sources/ProjectSwitchTool/ViewModels/GitSwitcherViewModel.swift
git add Packages/BranchSwitch/Sources/BranchSwitch/ViewModels/BranchSwitchViewModel.swift
git commit -m "feat(JYBLog): 添加统一日志系统

- 新增 JYBLog Package
- LogPanelView 类似 Xcode Debug 区域
- 5级日志: debug/info/success/warning/error
- 支持收起/展开、拖动高度、级别过滤"
```

---

## 验证清单

- [ ] 日志面板默认收起 (40px)
- [ ] 点击可展开
- [ ] 可拖动调整高度 (100-400px)
- [ ] 日志显示时间戳、级别、消息
- [ ] 级别过滤器可切换显示/隐藏
- [ ] 清空按钮可清除所有日志
- [ ] 新日志自动展开
- [ ] 各工具日志正确显示
