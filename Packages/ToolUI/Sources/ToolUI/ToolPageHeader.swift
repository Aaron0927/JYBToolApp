import SwiftUI

public struct ToolPageHeader: View {
  private let title: String
  private let subtitle: String
  private let systemImage: String

  public init(title: String, subtitle: String, systemImage: String) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .font(.title2)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.tint)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.title2)
          .bold()

        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(.bottom, 8)
  }
}
