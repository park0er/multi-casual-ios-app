#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct TimelineItem: Identifiable, Sendable {
    public let id = UUID()
    public let seq: Int
    public let type: TaskMessage.MessageType
    public let tool: String?
    public let summary: String
}

public struct AgentLiveView: View {
    public let taskId: String
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var timeline: [TimelineItem] = []
    @State private var isLoaded = false
    @State private var isCollapsed = false
    @State private var showTranscript = false
    @State private var subscriptionTask: Task<Void, Never>?

    public init(taskId: String) { self.taskId = taskId }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() }
            } label: {
                HStack {
                    Image(systemName: "bolt.fill").foregroundStyle(.blue)
                    Text("Agent").font(.subheadline.bold())
                    Spacer()
                    if !timeline.isEmpty {
                        Text("\(timeline.count) events").font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { showTranscript = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption)
                    }.buttonStyle(.plain)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal).padding(.vertical, 10)
            .background(.secondary.opacity(0.06))

            if !isCollapsed {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(timeline) { item in TimelineRowView(item: item) }
                }
                .padding(.horizontal).padding(.vertical, 8)
            }
        }
        .background(.secondary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .task {
            if !isLoaded {
                if let messages = try? await api.listRunMessages(taskId: taskId) {
                    timeline = messages.map(TimelineItem.init(from:))
                }
                isLoaded = true
            }
            subscribeToWebSocket()
        }
        .onDisappear {
            subscriptionTask?.cancel()
            subscriptionTask = nil
        }
        .fullScreenCover(isPresented: $showTranscript) {
            AgentTranscriptView(taskId: taskId)
        }
    }

    private func subscribeToWebSocket() {
        subscriptionTask?.cancel()
        guard let token = authSession.token() else { return }
        subscriptionTask = Task {
            await WebSocketActor.shared.connect(token: token)
            for await event in await WebSocketActor.shared.subscribe(to: "task.message") {
                guard !Task.isCancelled else { break }
                guard event.taskId == taskId else { continue }
                if let msg = try? JSONDecoder().decode(TaskMessage.self, from: event.payload) {
                    timeline.append(TimelineItem(from: msg))
                }
            }
        }
    }
}

public struct TimelineRowView: View {
    public let item: TimelineItem
    public init(item: TimelineItem) { self.item = item }
    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(iconColor).frame(width: 16)
            Text(item.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }.padding(.vertical, 2)
    }

    private var icon: String {
        switch item.type {
        case .toolUse: return "wrench"
        case .toolResult: return "checkmark.circle"
        case .thinking: return "brain"
        case .text: return "text.bubble"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .error: return .red
        case .thinking: return .purple
        default: return .secondary
        }
    }
}

extension TimelineItem {
    init(from msg: TaskMessage) {
        seq = msg.seq; type = msg.type; tool = msg.tool
        switch msg.type {
        case .toolUse:
            let toolName = msg.tool ?? "tool"
            let inputSummary = msg.input?.first(where: { ["file_path","query","command"].contains($0.key) })
                .map { Self.shortenPath($0.value.displayString) } ?? ""
            summary = "\(toolName) \(inputSummary)".trimmingCharacters(in: .whitespaces)
        case .toolResult: summary = String((msg.output ?? "").prefix(80))
        case .thinking, .text: summary = String((msg.content ?? "").prefix(120))
        case .error: summary = msg.content ?? "Error"
        }
    }

    private static func shortenPath(_ s: String) -> String {
        let parts = s.split(separator: "/")
        guard parts.count > 3 else { return s }
        return ".../" + parts.suffix(2).joined(separator: "/")
    }
}
#endif
