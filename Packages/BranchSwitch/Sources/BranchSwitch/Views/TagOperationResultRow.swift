import SwiftUI
import ToolUI

struct TagOperationResultRow: View {
  let result: TagRepositoryOperationResult

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 8) {
        Text(result.repositoryName)
          .bold()
        Spacer()
        ToolStatusBadge(statusTitle, kind: statusKind)
      }
      Text(result.message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.quaternary, in: .rect(cornerRadius: 8))
  }

  private var statusTitle: String {
    switch result.status {
    case .success: "成功"
    case .pushFailed: "待重试推送"
    case .failed: "失败"
    }
  }

  private var statusKind: ToolStatusBadge.Kind {
    switch result.status {
    case .success: .success
    case .pushFailed: .warning
    case .failed: .failure
    }
  }
}
