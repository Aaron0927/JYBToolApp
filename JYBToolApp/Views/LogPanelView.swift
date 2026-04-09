import SwiftUI
import JYBLog

struct LogPanelView: View {
    @State private var logManager = LogManager.shared
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

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
                HStack(spacing: 4) {
                    Image(systemName: logManager.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text("日志 (\(logManager.entries.count))")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.plain)

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

            // 清空按钮
            Button {
                logManager.clear()
            } label: {
                Text("清空")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // 关闭按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    logManager.isExpanded = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logManager.filteredEntries()) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .onChange(of: logManager.entries.count) { _, _ in
                if let lastEntry = logManager.entries.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
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
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
            )
    }
}

struct FilterButton: View {
    let level: LogLevel
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: level.icon)
                    .font(.system(size: 9))
                Text(level.label)
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isActive ? level.color.opacity(0.2) : Color.clear)
            .foregroundStyle(isActive ? level.color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? level.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(entry.formattedTime)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("[\(entry.level.label)]")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(entry.level.color)
                .frame(width: 40, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer()
        }
    }
}
