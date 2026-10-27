import SwiftUI
import ToolUI

public struct ConfigFormView: View {
  @Bindable var viewModel: RenamerViewModel
  @State private var isConfirmingCopy = false

  public init(viewModel: RenamerViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ToolPanel("源路径与目标路径", systemImage: "folder") {
          Text("每组路径单独复制。目标目录中的同名文件可能被替换。")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          if viewModel.sourceTargetPairs.isEmpty {
            ContentUnavailableView(
              "还没有路径对",
              systemImage: "folder.badge.plus",
              description: Text("添加源项目和目标目录后，可检查前缀替换设置。")
            )
            .frame(minHeight: 120)
          }

          ForEach(viewModel.sourceTargetPairs.indices, id: \.self) { index in
            sourceTargetPairRow(index: index)
          }

          Button("添加路径对", systemImage: "plus") {
            viewModel.addSourceTargetPair()
          }
          .buttonStyle(.bordered)

          if !viewModel.sourceTargetPairs.isEmpty && !viewModel.isValidPairs {
            Label("请检查源路径和目标路径；源目录必须存在。", systemImage: "exclamationmark.triangle.fill")
              .font(.callout)
              .foregroundStyle(.orange)
          }
        }

        ToolPanel("前缀替换", systemImage: "textformat") {
          Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
              Text("旧前缀")
              TextField("例如 GDC", text: $viewModel.oldPrefix)
                .accessibilityLabel("旧项目名称前缀")
            }
            GridRow {
              Image(systemName: "arrow.down")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
              Text("代码和文件名中的旧前缀将替换为新前缀。")
                .foregroundStyle(.secondary)
            }
            GridRow {
              Text("新前缀")
              TextField("例如 GDCNew", text: $viewModel.newPrefix)
                .accessibilityLabel("新项目名称前缀")
            }
          }

          Toggle("修改项目配置文件", isOn: $viewModel.modifyConfigFiles)
          Toggle("完成后在 Xcode 中打开", isOn: $viewModel.autoOpenProject)
        }

        if let errorMessage = viewModel.errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .accessibilityAddTraits(.updatesFrequently)
        }

        HStack {
          Button("重置", systemImage: "arrow.counterclockwise") {
            viewModel.reset()
          }
          .disabled(viewModel.isRunning)

          Spacer()

          Button("预览并开始复制", systemImage: "doc.on.doc") {
            isConfirmingCopy = true
          }
          .buttonStyle(.borderedProminent)
          .disabled(!viewModel.canStart)
          .keyboardShortcut(.defaultAction)
        }

        if let result = viewModel.result {
          ToolPanel(result.success ? "复制完成" : "复制失败", systemImage: result.success ? "checkmark.circle" : "xmark.circle") {
            Text(result.success
              ? "替换 \(result.filesReplaced) 个文件，重命名 \(result.directoriesRenamed) 个目录和 \(result.filesRenamed) 个文件。"
              : result.errors.joined(separator: "\n"))
              .textSelection(.enabled)
              .foregroundStyle(result.success ? Color.primary : Color.red)
            if !result.warnings.isEmpty {
              Text(result.warnings.joined(separator: "\n"))
                .foregroundStyle(.orange)
                .textSelection(.enabled)
            }
          }
        }
      }
      .padding()
    }
    .confirmationDialog(
      "确认复制并替换项目？",
      isPresented: $isConfirmingCopy,
      titleVisibility: .visible
    ) {
      Button("开始复制", role: .destructive) {
        viewModel.startRename()
      }
      Button("返回检查", role: .cancel) {}
    } message: {
      Text("将复制 \(viewModel.sourceTargetPairs.count) 组路径，并把“\(viewModel.oldPrefix)”替换为“\(viewModel.newPrefix)”。目标目录中的同名文件可能被覆盖；保护关键词：\(Constants.protectedKeywords.joined(separator: "、"))。")
    }
  }

  private func sourceTargetPairRow(index: Int) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("路径对 \(index + 1)")
          .font(.subheadline)
          .bold()
        Spacer()
        Button("移除路径对", systemImage: "minus.circle", role: .destructive) {
          viewModel.removeSourceTargetPair(at: index)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("移除路径对 \(index + 1)")
      }

      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
        GridRow {
          Text("源目录")
          pathField(
            placeholder: "选择源项目文件夹…",
            path: $viewModel.sourceTargetPairs[index].sourcePath,
            browse: { viewModel.selectSourcePath(at: index) }
          )
        }
        GridRow {
          Text("目标目录")
          pathField(
            placeholder: "选择目标文件夹…",
            path: $viewModel.sourceTargetPairs[index].targetPath,
            browse: { viewModel.selectTargetPath(at: index) }
          )
        }
      }
    }
    .padding()
    .background(.quaternary, in: .rect(cornerRadius: 8))
  }

  private func pathField(placeholder: String, path: Binding<String>, browse: @escaping () -> Void) -> some View {
    HStack {
      TextField(placeholder, text: path)
        .textFieldStyle(.roundedBorder)
        .lineLimit(1)
      Button("浏览…", systemImage: "folder", action: browse)
    }
  }
}
