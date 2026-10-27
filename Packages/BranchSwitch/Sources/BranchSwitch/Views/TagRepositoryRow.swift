import SwiftUI
import ToolUI

struct TagRepositoryRow: View {
  let repository: RepoSwitchInfo
  let isSelected: Bool
  let isDisabled: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(repository.name)
            .font(.headline)
            .foregroundStyle(.primary)
          Text(repository.absolutePath)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }

        Spacer(minLength: 12)

        VStack(alignment: .trailing, spacing: 4) {
          ToolStatusBadge(repository.isCloned ? "已克隆" : "未克隆", kind: repository.isCloned ? .success : .warning)
          if repository.isCloned {
            Text("分支：\(repository.currentBranch.isEmpty ? "未知" : repository.currentBranch)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
      .padding(12)
      .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 9))
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .accessibilityLabel("\(repository.name)，\(repository.isCloned ? "已克隆" : "未克隆")")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
