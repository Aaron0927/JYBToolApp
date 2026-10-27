import SwiftUI

public struct ToolPanel<Content: View>: View {
  private let title: String
  private let systemImage: String
  private let content: Content

  public init(
    _ title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  public var body: some View {
    GroupBox {
      content
        .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Label(title, systemImage: systemImage)
        .font(.headline)
    }
  }
}
