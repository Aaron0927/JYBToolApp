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

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedToolId) {
                ForEach(viewModel.sortedCategories, id: \.self) { category in
                    Section(category) {
                        ForEach(viewModel.groupedTools[category] ?? []) { tool in
                            Text(tool.name)
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
                    BranchSwitch.BranchSwitchView()

                default:
                    Text("未知工具")
                }
            } else {
                Text("请选择一个工具")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

#Preview {
    ContentView()
}
