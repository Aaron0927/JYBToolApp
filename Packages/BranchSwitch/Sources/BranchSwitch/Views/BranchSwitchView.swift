import SwiftUI
import ToolUI

public struct BranchSwitchView: View {
  @Bindable var viewModel: BranchSwitchViewModel
  @State private var isConfirmingSwitch = false

  public init(viewModel: BranchSwitchViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      ToolPageHeader(
        title: "主仓库子模块切换",
        subtitle: "已过时工具。选择主仓库分支后，可查看并同步子模块目标。",
        systemImage: "arrow.triangle.branch"
      )

      ToolPanel("已过时", systemImage: "exclamationmark.triangle") {
        HStack(alignment: .top, spacing: 10) {
          ToolStatusBadge("已过时", kind: .warning)
          Text("该入口暂时保留供既有流程使用，不建议用于新流程。")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      ToolPanel("主仓库", systemImage: "folder") {
        HStack {
          TextField("请选择仓库目录", text: $viewModel.repoPath)
            .disabled(true)
            .accessibilityLabel("主仓库路径")

          Button("浏览…", systemImage: "folder") {
            viewModel.selectRepository()
          }
          .disabled(viewModel.isLoading)

          Button("在 Xcode 中打开", systemImage: "hammer") {
            viewModel.openInXcode()
          }
          .disabled(!viewModel.hasWorkspace || viewModel.isLoading)
        }

        if !viewModel.branches.isEmpty {
          Picker("主仓库分支", selection: $viewModel.selectedBranch) {
            ForEach(viewModel.branches, id: \.self) { branch in
              Text(branch).tag(branch)
            }
          }
          .pickerStyle(.menu)
          if !viewModel.currentBranch.isEmpty {
            ToolStatusBadge("当前分支：\(viewModel.currentBranch)")
          }
        }

        if viewModel.isLoading {
          ProgressView("正在读取仓库…")
            .controlSize(.small)
        } else if let errorMessage = viewModel.errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .accessibilityAddTraits(.updatesFrequently)
        } else if viewModel.repoPath.isEmpty {
          ContentUnavailableView(
            "请选择主仓库",
            systemImage: "folder.badge.questionmark",
            description: Text("读取本地分支和子模块配置后，可预览同步目标。")
          )
          .frame(minHeight: 140)
        } else if viewModel.branches.isEmpty {
          ContentUnavailableView(
            "未读取到分支",
            systemImage: "exclamationmark.triangle",
            description: Text("检查路径是否为有效 Git 仓库，然后重新选择目录。")
          )
          .frame(minHeight: 140)
        }
      }

      if !viewModel.submoduleBranches.isEmpty {
        ToolPanel("子模块目标预览", systemImage: "arrow.triangle.branch") {
          Text("切换后将按所选主仓库分支中的配置更新子模块。")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          if let operationSummary = viewModel.operationSummary {
            ToolStatusBadge(operationSummary, kind: viewModel.errorMessage == nil ? .success : .warning)
          }

          ForEach(viewModel.submoduleBranches) { info in
            LabeledContent(info.name) {
              HStack(spacing: 8) {
                Text(info.currentBranch)
                  .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                  .foregroundStyle(.tertiary)
                  .accessibilityHidden(true)
                Text(info.targetBranch)
                  .foregroundStyle(.tint)
              }
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
            }
            if let result = viewModel.switchResults[info.name] {
              ToolStatusBadge(result, kind: result == "成功" ? .success : .failure)
            }
          }

          HStack {
            if viewModel.isLoading {
              ProgressView()
                .controlSize(.small)
            }
            Spacer()
            Button("确认切换", systemImage: "arrow.triangle.branch") {
              isConfirmingSwitch = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isConfirmEnabled || viewModel.isLoading)
          }
        }
      }

      if let errorMessage = viewModel.errorMessage, !viewModel.submoduleBranches.isEmpty {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
          .accessibilityAddTraits(.updatesFrequently)
      }

      Spacer(minLength: 0)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .confirmationDialog(
      "确认切换主仓库和子模块？",
      isPresented: $isConfirmingSwitch,
      titleVisibility: .visible
    ) {
      Button("切换到 \(viewModel.selectedBranch)", role: .destructive) {
        viewModel.switchBranch()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("主仓库工作区可能包含未提交修改。请先确认这些修改已提交或妥善保存。")
    }
  }
}
