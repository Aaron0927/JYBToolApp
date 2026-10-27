import SwiftUI

struct TagInputSheet: View {
  @Binding var tagName: String
  @Binding var tagMessage: String

  let selectedRepositoryCount: Int
  let isBusy: Bool
  let onCancel: () -> Void
  let onContinue: () -> Void

  private var canContinue: Bool {
    !isBusy &&
      !tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !tagMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 5) {
        Text("设置 Tag")
          .font(.title2)
          .bold()
        Text("将对选中的 \(selectedRepositoryCount) 个仓库使用同一个 Tag。")
          .foregroundStyle(.secondary)
      }

      TextField("Tag 名称，例如 v8.4.21", text: $tagName)
        .font(.system(.body, design: .monospaced))
        .accessibilityLabel("Tag 名称")
        .disabled(isBusy)

      TextField("附注说明", text: $tagMessage, axis: .vertical)
        .lineLimit(3...5)
        .accessibilityLabel("Tag 附注说明")
        .disabled(isBusy)

      HStack {
        Text("Tag 会基于每个仓库当前 HEAD 创建，并推送到 origin。")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
      }

      HStack {
        Spacer()
        Button("取消", role: .cancel, action: onCancel)
        Button("继续确认", systemImage: "arrow.right", action: onContinue)
          .buttonStyle(.borderedProminent)
          .disabled(!canContinue)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 480)
  }
}
