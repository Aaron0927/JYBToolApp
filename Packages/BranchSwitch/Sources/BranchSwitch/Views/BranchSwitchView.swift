import SwiftUI

public struct BranchSwitchView: View {
    @State private var viewModel = BranchSwitchViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 仓库选择区
            HStack {
                Text("仓库路径：")
                TextField("选择仓库目录", text: $viewModel.repoPath)
                    .textFieldStyle(.roundedBorder)
                Button("浏览...") {
                    viewModel.selectRepository()
                }
            }

            // 分支选择
            if !viewModel.branches.isEmpty {
                HStack {
                    Text("分支：")
                    Picker("", selection: $viewModel.selectedBranch) {
                        ForEach(viewModel.branches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            Divider()

            // 子模块预览
            if !viewModel.submodules.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("子模块预览")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.submodules) { submodule in
                                HStack {
                                    Text(submodule.name)
                                    Text("→")
                                        .foregroundStyle(.secondary)
                                    Text(submodule.branch)
                                        .foregroundStyle(.blue)
                                    Spacer()
                                }
                                .font(.system(.body, design: .monospaced))
                            }
                        }
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
            }

            Divider()

            // 日志区
            VStack(alignment: .leading, spacing: 8) {
                Text("日志")
                    .font(.headline)

                ScrollView {
                    ScrollViewReader { proxy in
                        ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .id(index)
                        }
                        .onChange(of: viewModel.logs.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo(viewModel.logs.count - 1)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
