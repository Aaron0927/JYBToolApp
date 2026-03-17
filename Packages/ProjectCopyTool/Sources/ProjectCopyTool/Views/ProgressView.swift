import SwiftUI

public struct RenameProgressView: View {
    @Bindable var viewModel: RenamerViewModel
    
    public init(viewModel: RenamerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在处理...")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.steps, id: \.self) { step in
                    stepRow(step)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func stepRow(_ step: String) -> some View {
        HStack(spacing: 12) {
            statusIcon(for: step)
            
            Text(step)
                .foregroundStyle(textColor(for: step))
            
            Spacer()
            
            if let status = viewModel.stepStatuses[step] {
                Text(status.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func statusIcon(for step: String) -> some View {
        if let status = viewModel.stepStatuses[step] {
            switch status {
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(.gray)
            case .inProgress:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.gray)
        }
    }
    
    private func textColor(for step: String) -> Color {
        if let status = viewModel.stepStatuses[step] {
            switch status {
            case .completed:
                return .primary
            case .failed:
                return .red
            case .inProgress:
                return .blue
            default:
                return .secondary
            }
        }
        return .secondary
    }
}
