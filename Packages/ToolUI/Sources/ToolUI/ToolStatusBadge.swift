import SwiftUI

public struct ToolStatusBadge: View {
  public enum Kind: Sendable {
    case neutral
    case success
    case warning
    case failure
  }

  private let title: String
  private let kind: Kind

  public init(_ title: String, kind: Kind = .neutral) {
    self.title = title
    self.kind = kind
  }

  public var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption)
      .foregroundStyle(foregroundStyle)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(foregroundStyle.opacity(0.12), in: .capsule)
      .accessibilityElement(children: .combine)
  }

  private var systemImage: String {
    switch kind {
    case .neutral: "circle.dashed"
    case .success: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .failure: "xmark.circle.fill"
    }
  }

  private var foregroundStyle: Color {
    switch kind {
    case .neutral: .secondary
    case .success: .green
    case .warning: .orange
    case .failure: .red
    }
  }
}
