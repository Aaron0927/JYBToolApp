# JYBToolApp 开发指南

JYBToolApp 是一款面向开发团队的 macOS 工具箱，使用 SwiftUI 和本地 Swift Packages。

## 技术基线

- 主应用最低支持 macOS 14.6；Packages 可保持各自 manifest 声明的平台下限。
- 主应用和自有 Packages 使用 Swift 6 语言模式，并修复严格并发检查发现的问题。
- 共享界面状态使用 `@MainActor @Observable`，由视图通过 `@State`、`@Bindable` 或 `@Environment` 持有和传递。
- 优先使用 async/await、原生 Swift 与现代 Foundation API。避免 `ObservableObject`、`@Published`、`@StateObject`、GCD、强制解包和强制 `try`。
- 不引入第三方依赖；如需求确实需要新增依赖，先更新技术方案。

## SwiftUI 与交互

- 遵循 macOS 人机界面与辅助功能习惯；支持键盘操作、系统外观和可调整窗口尺寸。
- 用户操作必须有明确的标签、可见的禁用条件、运行状态和结果反馈。批量或高影响操作先展示范围与目标。
- 使用 `foregroundStyle`、`clipShape(.rect(cornerRadius:))`、`NavigationStack` 和现代 `onChange` API。
- 视图只负责呈现与交互；可验证的业务规则放入模型、服务或视图模型。
- 产品流程与 UI 规则以 [`docs/product/PRD.md`](docs/product/PRD.md)、[`docs/product/UI.md`](docs/product/UI.md) 和 [`docs/product/TECHNICAL.md`](docs/product/TECHNICAL.md) 为准。

## 并发与错误处理

- 明确隔离 UI 状态；跨任务传递的值类型满足 `Sendable`，共享可变状态由 actor 隔离。
- 用具名错误表达可恢复故障，以 `do-catch` 在边界转换为可读的用户提示并记录日志。
- 后台文件与 Git 操作不得阻塞主线程；取消任务时保持文件和工作区处于可解释状态。
- 不用 `@Published` 保存错误状态；在 `@Observable` 类型中使用普通存储属性。

## 代码与测试

- 缩进 2 个空格；类型名使用 PascalCase，成员使用 camelCase；新增注释使用简体中文。
- 每个功能修改都补充适当测试。优先测试服务和业务逻辑；仅当单元测试无法覆盖时使用 UI 测试。
- 本地构建：

  ```bash
  xcodebuild -project JYBToolApp.xcodeproj -scheme JYBToolApp -configuration Debug -destination 'platform=macOS' build
  ```

- 本地测试：

  ```bash
  xcodebuild test -project JYBToolApp.xcodeproj -scheme JYBToolApp -destination 'platform=macOS'
  ```

- 如果 Xcode MCP 当前打开的是本项目，优先用其 Build、Test、Preview 和诊断工具；否则使用上面的命令。
- 每项功能验收后，将该功能与对应测试作为一个 Git commit。

## 发布与安全

- 发布沿用 `scripts/release.sh`、GitHub Actions、DMG 和 Sparkle Appcast 流程；检查更新只在需求要求时执行。
- 密钥只从受控环境注入，不写入源码、文档、日志或测试资源。
- 修改产品行为后同步更新产品文档；技术约束只在本文件维护，避免重复来源。
