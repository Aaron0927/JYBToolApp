//
//  ContentView.swift
//  JYBToolApp
//
//  Created by kim on 2026/3/13.
//

import SwiftUI
import ProjectSwitchTool
import ProjectCopyTool
import BranchSwitch
import JYBLog

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    @State private var branchSwitchViewModel = BranchSwitch.BranchSwitchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
            List(selection: $viewModel.selectedToolId) {
                ForEach(viewModel.sortedCategories, id: \.self) { category in
                    Section(category) {
                        ForEach(viewModel.groupedTools[category] ?? []) { tool in
                            Label(tool.name, systemImage: tool.icon)
                                .tag(tool.id)
                        }
                    }
                }
            }
            .navigationTitle("工具箱")

        } detail: {
            if let tool = viewModel.selectedTool {
                switch tool.id {
                case "switch":
                    ProjectSwitchTool.GitSwitcherView()

                case "copy":
                    ProjectCopyTool.ContentView()

                case "branch":
                    BranchSwitchView(viewModel: branchSwitchViewModel)

                default:
                    Text("未知工具")
                }
            } else {
                Text("请选择一个工具")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
            LogPanelView()
        }
    }
}

#Preview {
    ContentView()
}
