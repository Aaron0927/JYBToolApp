import SwiftUI

public struct ConfigFormView: View {
    @Bindable var viewModel: RenamerViewModel
    
    public init(viewModel: RenamerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sourceTargetPairsSection
                prefixSection
                actionButtons
            }
            .padding(30)
        }
    }
    
    private var sourceTargetPairsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("源路径与目标路径", systemImage: "folder")
                .font(.headline)
            
            if viewModel.sourceTargetPairs.isEmpty {
                Text("点击下方按钮添加源路径和目标路径")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            
            ForEach(Array(viewModel.sourceTargetPairs.enumerated()), id: \.element.id) { index, pair in
                sourceTargetPairRow(index: index)
            }
            
            Button {
                viewModel.addSourceTargetPair()
            } label: {
                Label("添加路径对", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            
            if !viewModel.sourceTargetPairs.isEmpty && !viewModel.isValidPairs {
                Label("部分路径不存在或无效", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
    
    private func sourceTargetPairRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("路径对 \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button {
                    viewModel.removeSourceTargetPair(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("源路径")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("选择源项目文件夹...", text: $viewModel.sourceTargetPairs[index].sourcePath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("浏览") {
                            viewModel.selectSourcePath(at: index)
                        }
                    }
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("目标路径")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("选择目标文件夹...", text: $viewModel.sourceTargetPairs[index].targetPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("浏览") {
                            viewModel.selectTargetPath(at: index)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }
    
    private var prefixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("前缀设置", systemImage: "textformat")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("旧前缀 (原项目)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("例如: GDC", text: $viewModel.oldPrefix)
                        .textFieldStyle(.roundedBorder)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("新前缀 (新项目)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("例如: Test", text: $viewModel.newPrefix)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack {
            Spacer()
            
            Button("开始重命名") {
                viewModel.startRename()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStart)
            
            Button("重置") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 10)
    }
}
