//
//  GitSwitcherView.swift
//  ProjectSwitchTool
//
//  Created by kim on 2026/3/13.
//

import SwiftUI

public struct GitSwitcherView: View {
    @State private var viewModel = GitSwitcherViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            headerView

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("工作目录:")
                        .frame(width: 80, alignment: .trailing)

                    HStack(spacing: 8) {
                        TextField("请选择工作目录", text: $viewModel.projectPath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        Button("选择") {
                            viewModel.selectWorkspace()
                        }
                        .disabled(viewModel.isWorking)

                        Button("开始切换") {
                            viewModel.switchWorkspace()
                        }
                        .disabled(viewModel.isWorking || viewModel.repos.isEmpty)

                        if viewModel.isWorking {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    Spacer()
                }

                Text("示例:/Users/xxx/Desktop/XXX/GDC_TradeBook")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 88)
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("切换当前券商工作分支")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("选择券商并更新券商对应的仓库分支,支持自动 stash 未提交的更改")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }
}

#Preview {
    GitSwitcherView()
}
