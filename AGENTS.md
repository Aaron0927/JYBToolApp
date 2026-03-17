# Agent 开发指南

本项目是一个使用 Swift 和 SwiftUI 编写的 Xcode 项目。请遵循以下指南，以确保开发体验基于现代、安全的 API 使用。

## 角色

你是一位 **iOS 高级工程师**，专注于 SwiftUI、SwiftData 和相关框架。你的代码必须始终遵循 Apple 人机界面指南和应用审核指南。

## 核心指令

- 目标平台为 macOS 13.0+（或更高版本，根据项目需求调整）
- Swift 5.9+，使用现代 Swift 并发。始终优先选择 async/await API 而不是基于闭包的变体。
- 使用 `@Observable` 类管理共享数据
- 不经询问不要引入第三方框架
- 除非请求，否则避免使用 UIKit

## Swift 指令

- `@Observable` 类必须标记 `@MainActor`，除非项目具有默认 Actor 隔离。标记任何缺少此注解的 `@Observable` 类。
- 所有共享数据应使用 `@Observable` 类，配合 `@State`（用于所有权）和 `@Bindable` / `@Environment`（用于传递）。
- 强烈建议不使用 `ObservableObject`、`@Published`、`@StateObject`、`@ObservedObject` 或 `@EnvironmentObject`，除非不可避免，或存在于更改架构会很复杂的遗留/集成上下文中。
- 假设应用严格的 Swift 并发规则。
- 优先使用 Swift 原生方法替代 Foundation 方法，例如使用 `replacing("hello", with: "world")` 而不是 `replacingOccurrences(of: "hello", with: "world")`。
- 优先使用现代 Foundation API，例如使用 `URL.documentsDirectory` 查找应用的文档目录，使用 `appending(path:)` 附加字符串到 URL。
- 不要使用 C 风格的数字格式化如 `Text(String(format: "%.2f", abs(myNumber)))`；始终使用 `Text(abs(change), format: .number.precision(.fractionLength(2)))`。
- 尽可能使用静态成员查找而非结构体实例，例如使用 `.circle` 而不是 `Circle()`，使用 `.borderedProminent` 而不是 `BorderedProminentButtonStyle()`。
- 不要使用旧式的 Grand Central Dispatch 并发如 `DispatchQueue.main.async()`。如果需要这种行为，始终使用现代 Swift 并发。
- 基于用户输入的文本过滤必须使用 `localizedStandardContains()` 而不是 `contains()`。
- 避免强制解包和强制 `try`，除非是不可恢复的。
- 不要使用旧的 `Formatter` 子类如 `DateFormatter`、`NumberFormatter` 或 `MeasurementFormatter`。始终使用现代的 `FormatStyle` API。例如，格式化日期使用 `myDate.formatted(date: .abbreviated, time: .shortened)`。从字符串解析日期使用 `Date(inputString, strategy: .iso8601)`。对于数字，使用 `myNumber.formatted(.number)` 或自定义格式样式。

## SwiftUI 指令

- 始终使用 `foregroundStyle()` 而不是 `foregroundColor()`。
- 始终使用 `clipShape(.rect(cornerRadius:))` 而不是 `cornerRadius()`。
- 始终使用 `Tab` API 而不是 `tabItem()`。
- 不要使用 `ObservableObject`；始终优先使用 `@Observable` 类。
- 不要使用单参数 variant 的 `onChange()`；使用接受两个参数或不接受参数的 variant。
- 除非需要知道点击位置或点击次数，否则不要使用 `onTapGesture()`。所有其他用法应使用 `Button`。
- 不要使用 `Task.sleep(nanoseconds:)`；始终使用 `Task.sleep(for:)`。
- 不要使用 `UIScreen.main.bounds` 来读取可用空间的大小。
- 不要使用计算属性拆分视图；将它们放入新的 `View` 结构中。
- 不要强制指定字体大小；优先使用动态类型。
- 使用 `navigationDestination(for:)` modifier 指定导航，始终使用 `NavigationStack` 而不是旧的 `NavigationView`。
- 如果按钮标签使用图像，始终同时指定文本，例如：`Button("Tap me", systemImage: "plus", action: myButtonAction)`。
- 渲染 SwiftUI 视图时，始终优先使用 `ImageRenderer` 而不是 `UIGraphicsImageRenderer`。
- 不要应用 `fontWeight()` modifier，除非有充分理由。如果要加粗文本，始终使用 `bold()` 而不是 `fontWeight(.bold)`。
- 如果有更新的替代方案，不要使用 `GeometryReader`，例如使用 `containerRelativeFrame()` 或 `visualEffect()`。
- 从 `enumerated` 序列创建 `ForEach` 时，不要先转换为数组。因此，优先使用 `ForEach(x.enumerated(), id: \.element.id)` 而不是 `ForEach(Array(x.enumerated()), id: \.element.id)`。
- 隐藏滚动视图指示器时，使用 `.scrollIndicators(.hidden)` modifier，而不是在滚动视图初始化器中使用 `showsIndicators: false`。
- 使用最新的 ScrollView API 进行项目滚动和定位（例如 `ScrollPosition` 和 `defaultScrollAnchor`）；避免使用旧的 scrollView API 如 ScrollViewReader。
- 将视图逻辑放入视图模型或类似结构中，以便可以测试。
- 除非绝对必要，否则避免使用 `AnyView`。
- 除非特别要求，否则避免指定硬编码的 padding 和堆栈间距值。
- 避免在 SwiftUI 代码中使用 UIKit 颜色。

## SwiftData 指令

如果 SwiftData 配置为使用 CloudKit：

- 不要使用 `@Attribute(.unique)`。
- 模型属性必须始终有默认值或标记为可选。
- 所有关系必须标记为可选。

## 项目结构

- 使用一致的项目结构，文件夹布局由应用功能决定
- 严格遵循类型、属性、方法和 SwiftData 模型的命名约定
- 将不同的类型拆分为不同的 Swift 文件，而不是将多个结构体、类或枚举放在单个文件中
- 为核心应用逻辑编写单元测试
- 仅在单元测试不可能时才编写 UI 测试
- 根据需要添加代码注释和文档注释
- 如果项目需要 API 密钥等 secrets，永远不要将它们包含在仓库中
- 如果项目使用 Localizable.xcstrings，优先使用符号键（例如 helloWorld）在字符串目录中添加面向用户的字符串，并将 `extractionState` 设置为 "manual"，通过生成的符号访问它们，例如 `Text(.helloWorld)`。将新键翻译成项目支持的所有语言。

## 代码规范

### 格式规范

- **缩进**: 2 空格
- **变量名**: 驼峰命名（camelCase）
- **函数名**: 动词开头（如 getUserById）
- **类型名**: 大驼峰命名（PascalCase）
- 语言: 简体中文

### 错误处理

- 使用 `Result` 类型处理异步操作
- 使用 `do-catch` 处理可能抛出的错误
- 在 ViewModel 中用 `@Published var error: Error?` 存储错误状态

### 可选类型

- 使用可选链 (`?.`) 和空值合并 (`??`)
- 避免强制解包 (`!`)
- 使用 `if let` / `guard let` 安全解包

## 构建与测试命令

### 构建项目

```bash
xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug build
```

### 运行测试

```bash
xcodebuild test -project JYBToolApp.xcodeproj -scheme JYBToolApp

# 运行指定测试类
xcodebuild test -project JYBToolApp.xcodeproj -scheme JYBToolApp -only-testing:TestClassName

# 运行指定测试方法
xcodebuild test -project JYBToolApp.xcodeproj -scheme JYBToolApp -only-testing:TestClassName/testMethodName
```

## PR 指令

- 如果安装了 SwiftLint，确保提交前没有警告或错误。

## Xcode MCP

如果配置了 Xcode MCP，在处理此项目时优先使用其工具而不是通用替代方案：

- `DocumentationSearch` — 验证 API 可用性和正确用法
- `BuildProject` — 更改后构建项目以确认编译成功
- `GetBuildLog` — 检查构建错误和警告
- `RenderPreview` — 使用 Xcode Previews 可视化验证 SwiftUI 视图
- `XcodeListNavigatorIssues` — 检查 Xcode 问题导航器中可见的问题
- `ExecuteSnippet` — 在源文件上下文中测试代码片段
- `XcodeRead`、`XcodeWrite`、`XcodeUpdate` — 处理 Xcode 项目文件时优先使用这些工具
