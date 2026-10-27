import SwiftUI
import JYBLog

struct LogPanelView: View {
    @State private var logManager = LogManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var scrollPosition: UUID?

    private var currentHeight: CGFloat {
        if logManager.isExpanded {
            return min(max(logManager.panelHeight + dragOffset, logManager.minHeight), logManager.maxHeight)
        }
        return logManager.collapsedHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // 拖动把手
            DragHandle()
                .gesture(dragGesture)
                .accessibilityHidden(true)

            // 标题栏
            headerBar

            // 日志列表
            if logManager.isExpanded {
                logListView
            }
        }
        .frame(height: currentHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.separator),
            alignment: .top
        )
    }

    private var headerBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    logManager.isExpanded.toggle()
                }
            } label: {
                Label("日志 · \(logManager.entries.count)", systemImage: logManager.isExpanded ? "chevron.down" : "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityHint(logManager.isExpanded ? "收起日志面板" : "展开日志面板")

            Spacer()

            // 级别过滤器
            HStack(spacing: 4) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    FilterButton(
                        level: level,
                        isActive: logManager.visibleLevels.contains(level)
                    ) {
                        logManager.toggleLevel(level)
                    }
                }
            }

            Spacer()

            Button("增加日志高度", systemImage: "arrow.up.to.line") {
                logManager.panelHeight = min(logManager.panelHeight + 40, logManager.maxHeight)
                logManager.isExpanded = true
            }
            .labelStyle(.iconOnly)
            .help("增加日志面板高度")

            Button("减少日志高度", systemImage: "arrow.down.to.line") {
                logManager.panelHeight = max(logManager.panelHeight - 40, logManager.minHeight)
            }
            .labelStyle(.iconOnly)
            .help("减少日志面板高度")

            // 清空按钮
            Button("清空日志", systemImage: "trash") {
                logManager.clear()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(logManager.entries.isEmpty)

            // 关闭按钮
            Button("收起日志", systemImage: "xmark") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    logManager.isExpanded = false
                }
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var logListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(logManager.filteredEntries()) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .scrollPosition(id: $scrollPosition, anchor: .bottom)
        .onChange(of: logManager.entries.count) { _, _ in
            withAnimation {
                scrollPosition = logManager.entries.last?.id
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if logManager.isExpanded {
                    dragOffset = -value.translation.height
                }
            }
            .onEnded { value in
                if logManager.isExpanded {
                    logManager.panelHeight = min(
                        max(logManager.panelHeight - value.translation.height, logManager.minHeight),
                        logManager.maxHeight
                    )
                }
                dragOffset = 0
            }
    }
}

struct DragHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(.tertiary)
                    .frame(width: 36, height: 4)
            )
    }
}

struct FilterButton: View {
    let level: LogLevel
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(level.label, systemImage: level.icon, action: action)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? level.color.opacity(0.2) : Color.clear)
            .foregroundStyle(isActive ? level.color : .secondary)
            .clipShape(.rect(cornerRadius: 6))
        .buttonStyle(.plain)
        .accessibilityLabel("筛选\(level.label)日志")
        .accessibilityValue(isActive ? "已启用" : "已停用")
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTime)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(entry.level.label)
                .font(.caption)
                .bold()
                .foregroundStyle(entry.level.color)
                .frame(minWidth: 36, alignment: .leading)

            Text(entry.message)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
