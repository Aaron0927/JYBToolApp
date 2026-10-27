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
    @State private var reposSwitchViewModel = BranchSwitch.ReposSwitchViewModel()
    @State private var pullLatestViewModel = BranchSwitch.ReposSwitchViewModel()
    @State private var tagManagementViewModel = BranchSwitch.TagManagementViewModel()

    var body: some View {
    VStack(spacing: 0) {
      NavigationSplitView {
        List(selection: $viewModel.selectedToolId) {
          ForEach(viewModel.sortedCategories, id: \.self) { category in
            Section(category) {
              ForEach(viewModel.groupedTools[category] ?? []) { tool in
                HStack {
                  Label(tool.name, systemImage: tool.icon)
                  Spacer(minLength: 8)
                  if tool.isDeprecated && !tool.name.contains("已过时") {
                    Text("已过时")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .padding(.horizontal, 6)
                      .padding(.vertical, 3)
                      .background(.quaternary, in: .capsule)
                  }
                }
                  .tag(tool.id)
                  .accessibilityIdentifier("tool-\(tool.id)")
                  .accessibilityLabel(tool.isDeprecated && !tool.name.contains("已过时") ? "\(tool.name)，已过时" : tool.name)
              }
            }
          }
        }
        .listStyle(.sidebar)
        .navigationTitle("JYBToolApp")
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 270)
      } detail: {
        Group {
          if let tool = viewModel.selectedTool {
            switch tool.id {
            case Tool.switchTool.id:
              ProjectSwitchTool.GitSwitcherView()
            case Tool.copyTool.id:
              ProjectCopyTool.ContentView()
            case Tool.branchTool.id:
              BranchSwitchView(viewModel: branchSwitchViewModel)
            case Tool.reposBranchTool.id:
              ReposSwitchView(viewModel: reposSwitchViewModel)
            case Tool.reposPullTool.id:
              PullLatestView(viewModel: pullLatestViewModel)
            case Tool.reposTagTool.id:
              TagManagementView(viewModel: tagManagementViewModel)
            default:
              ContentUnavailableView("找不到工具", systemImage: "questionmark.folder")
            }
          } else {
            ContentUnavailableView("请选择一个工具", systemImage: "sidebar.left")
          }
        }
        .frame(minWidth: 470, minHeight: 420)
      }
      .navigationSplitViewStyle(.balanced)

      LogPanelView()
    }
    .frame(minWidth: 740, minHeight: 560)
    }
}

#Preview {
    ContentView()
}
