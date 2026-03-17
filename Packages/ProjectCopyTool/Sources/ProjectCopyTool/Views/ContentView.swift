import SwiftUI
import AppKit

public struct ContentView: View {
    @State private var viewModel = RenamerViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if viewModel.isRunning {
                RenameProgressView(viewModel: viewModel)
            } else if viewModel.isCompleted {
                resultView
            } else {
                ConfigFormView(viewModel: viewModel)
            }
            
            Divider()
            
            footerView
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("私版项目复制")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("复制并重命名指定路径项目，支持批量替换前缀、文件内容、plist 等")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }
    
    private var resultView: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(viewModel.isSuccess ? .green : .red)
            
            Text(viewModel.isSuccess ? "重命名成功!" : "重命名失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let result = viewModel.result {
                VStack(alignment: .leading, spacing: 8) {
                    resultRow(icon: "doc.text", title: "替换文件数", value: "\(result.filesReplaced)")
                    resultRow(icon: "folder", title: "重命名目录数", value: "\(result.directoriesRenamed)")
                    resultRow(icon: "doc", title: "重命名文件数", value: "\(result.filesRenamed)")
                    resultRow(icon: "clock", title: "耗时", value: String(format: "%.2f 秒", result.duration))
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(.rect(cornerRadius: 8))
            }
            
            HStack(spacing: 16) {
                Button("返回") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
                
                if viewModel.isSuccess && !viewModel.projectURLs.isEmpty {
                    Button {
                        for url in viewModel.projectURLs {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("打开项目", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func resultRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    private var footerView: some View {
        HStack {
            Text("保护关键词: \(Constants.protectedKeywords.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
