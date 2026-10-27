# 技术与交付约束

## 平台和架构

- 主应用最低版本为 macOS 14.6；应用与自有 Packages 使用 Swift 6 语言模式。
- 继续按现有功能包维护 Git 切换、项目复制和日志；公共 SwiftUI 组件集中在内部 UI package，不引入外部 UI 框架。
- Xcode 项目中的本地包引用使用相对路径，禁止依赖开发者个人目录的绝对路径。
- 视图模型是 `@MainActor @Observable`；仓库读取、Git 操作和文件复制在后台执行，UI 更新回主 actor。
- 跨任务数据类型明确满足 `Sendable`；共享可变状态使用 actor 隔离。

## 测试

- 为分支切换、过时子模块、独立拉取、Tag 创建并推送、复制校验和受保护前缀补充单元测试。
- 使用临时 Git 仓库和临时目录隔离测试数据；测试不读写真实用户仓库或 DerivedData。
- 构建主 app；运行全部 package 和 app test targets；对空、加载、成功、部分失败和错误状态做 SwiftUI 预览或手动检查。

## 发布

- 版本号由 `scripts/release.sh` 管理；Tag 触发 GitHub Actions 构建 DMG、更新 Appcast 并部署到 GitHub Pages。
- 发布验收检查构建成功、DMG 产物、Appcast 版本和下载链接，以及 Sparkle 更新通道。
- Appcast 与签名私钥仍由现有 CI 流程维护，私钥不落入仓库。
