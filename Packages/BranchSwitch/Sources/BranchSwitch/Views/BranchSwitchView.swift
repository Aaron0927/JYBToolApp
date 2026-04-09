import SwiftUI

public struct BranchSwitchView: View {
    @Bindable var viewModel: BranchSwitchViewModel

    public init(viewModel: BranchSwitchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.title)
                        .foregroundStyle(.blue)
                    Text("公版分支切换")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }

                Text("选择一个主仓库分支，确认后自动更新所有子模块到各自预定的分支")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(.rect(cornerRadius: 8))

            // 仓库选择区
            HStack {
                Text("仓库路径：")
                    .frame(width: 80, alignment: .trailing)

                HStack(spacing: 8) {
                    TextField("请选择仓库目录", text: $viewModel.repoPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button("浏览...") {
                        viewModel.selectRepository()
                    }
                    .disabled(viewModel.isLoading)

                    Button("在 Xcode 中打开") {
                        viewModel.openInXcode()
                    }
                    .disabled(!viewModel.hasWorkspace || viewModel.isLoading)
                    .opacity(viewModel.hasWorkspace ? 1 : 0.5)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)

            // 分支选择
            if !viewModel.repoPath.isEmpty && !viewModel.branches.isEmpty {
                HStack {
                    Text("分支：")
                        .frame(width: 80, alignment: .trailing)

                    Picker("", selection: $viewModel.selectedBranch) {
                        ForEach(viewModel.branches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Spacer()
                }
                .padding(.horizontal)
            }

            Divider()

            // 子模块分支
            if !viewModel.repoPath.isEmpty && !viewModel.submoduleBranches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("子模块分支")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.submoduleBranches) { info in
                                HStack {
                                    Text(info.name)
                                    Text(info.targetBranch)
                                        .foregroundStyle(.blue)
                                    Spacer()
                                }
                                .font(.system(.body, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color.black.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 8))

                    HStack {
                        Spacer()
                        Button("确认切换") {
                            viewModel.switchBranch()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.isConfirmEnabled || viewModel.isLoading)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
