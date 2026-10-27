import SwiftUI

public struct ToolValueRow: View {
  private let title: String
  private let value: String

  public init(_ title: String, value: String) {
    self.title = title
    self.value = value
  }

  public var body: some View {
    LabeledContent(title) {
      Text(value)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .lineLimit(2)
        .multilineTextAlignment(.trailing)
    }
  }
}
