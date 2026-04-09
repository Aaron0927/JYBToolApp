# BranchSwitch 设计文档

## 概述

公版切换工具，用于主仓库切换分支时同步更新所有子模块到各自配置的分支。

## 界面布局

```
┌────────────────────────────────────────────────────────┐
│ 仓库路径: [________________________] [浏览...]         │
│ 分支: [develop ▼]                                      │
├────────────────────────────────────────────────────────┤
│ 子模块预览                                             │
│ ┌──────────────────────────────────────────────────┐  │
│ │ ModuleA  →  develop                               │  │
│ │ ModuleB  →  master                                │  │
│ │ ModuleC  →  develop                               │  │
│ └──────────────────────────────────────────────────┘  │
│                                [确认切换]              │
├────────────────────────────────────────────────────────┤
│ 日志                                                    │
│ [正在切换到分支 develop...]                              │
│ [✓ 主仓库切换成功]                                      │
│ [✓ ModuleA 更新成功]                                    │
└────────────────────────────────────────────────────────┘
```

## 流程

1. **选择仓库** → 浏览按钮选择主仓库目录
2. **加载** → 自动读取主仓库分支列表 + 子模块列表
3. **选择分支** → 下拉框选择目标分支
4. **预览** → 中间区域显示子模块及其各自目标分支（来自 .gitmodules 配置）
5. **确认执行** → 主仓库切换 → 子模块同步

## 执行逻辑

用户点击"确认切换"后：
1. 主仓库 `git checkout <选择的分支>`
2. 主仓库 `git pull`
3. 对每个子模块：
   - `git checkout <子模块配置的分支>`
   - `git pull`

## 组件结构

| 组件 | 文件 | 职责 |
|------|------|------|
| View | `BranchSwitchView.swift` | 主视图，垂直布局 |
| ViewModel | `BranchSwitchViewModel.swift` | 状态管理、流程控制 |
| Service | `GitModuleService.swift` | Git 操作（已有） |
| Model | `Submodule.swift` | 子模块数据模型（已有） |
| Runner | `ProcessRunner.swift` | 命令执行（已有） |

## ViewModel 状态

```swift
- repoPath: String           // 仓库路径
- branches: [String]          // 主仓库分支列表
- selectedBranch: String     // 用户选择的分支
- submodules: [Submodule]    // 子模块列表
- logs: [String]             // 日志输出
- isLoading: Bool            // 加载状态
```

## Service 新增方法

```swift
- getBranches(at: String) -> [String]  // 获取主仓库所有分支
- checkoutMainRepo(branch: String, at: String) -> Bool  // 切换主仓库分支
```

## 验证方式

手动测试：
1. 选择一个有子模块的仓库
2. 选择目标分支
3. 点击确认切换
4. 检查日志输出
5. 验证主仓库和子模块分支是否正确
