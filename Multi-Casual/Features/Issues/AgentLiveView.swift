#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct AgentLiveView: View {
    public let taskId: String
    public let workspaceId: String?
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @Environment(\.appLanguage) private var appLanguage
    @State private var viewModel: AgentTimelineViewModel?
    @State private var isCollapsed = false
    @State private var showTranscript = false
    @State private var subscriptionTask: Task<Void, Never>?

    public init(taskId: String, workspaceId: String? = nil) {
        self.taskId = taskId
        self.workspaceId = workspaceId
    }

    public var body: some View {
        let timeline = viewModel?.timeline ?? []
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() }
            } label: {
                HStack {
                    Image(systemName: "bolt.fill").foregroundStyle(.blue)
                    Text("Agent").font(.subheadline.bold())
                    Spacer()
                    if !timeline.isEmpty {
                        MarkdownText(
                            timeline.count == 1
                                ? AppStrings.localized("1 event", language: appLanguage)
                                : "\(timeline.count) \(AppStrings.localized("events", language: appLanguage))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    if viewModel?.isLoading == true {
                        ProgressView().padding(.vertical, 4)
                    }
                    if let error = viewModel?.errorMessage {
                        ErrorRetryView(message: error) {
                            Task { await viewModel?.loadHistory() }
                        }
                    }
                    ForEach(timeline) { item in TimelineRowView(item: item) }
                }
                .padding(.horizontal).padding(.vertical, 8)
            }
        }
        .background(.secondary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .task {
            if viewModel == nil {
                let vm = AgentTimelineViewModel(
                    taskId: taskId,
                    workspaceId: workspaceId ?? authSession.currentWorkspace?.id,
                    api: api
                )
                viewModel = vm
                await vm.loadHistory()
            }
            subscribeToWebSocket()
        }
        .onDisappear {
            subscriptionTask?.cancel()
            subscriptionTask = nil
        }
        .sheet(isPresented: $showTranscript) {
            AgentTranscriptView(taskId: taskId, workspaceId: workspaceId ?? authSession.currentWorkspace?.id)
                .presentationDragIndicator(.visible)
        }
    }

    private func subscribeToWebSocket() {
        subscriptionTask?.cancel()
        guard let token = authSession.token(),
              let workspaceId = workspaceId ?? authSession.currentWorkspace?.id,
              !workspaceId.isEmpty
        else { return }
        subscriptionTask = Task {
            await WebSocketActor.shared.connect(token: token, workspaceId: workspaceId)
            for await event in await WebSocketActor.shared.subscribe(to: "task:message") {
                guard !Task.isCancelled else { break }
                guard event.taskId == taskId else { continue }
                await MainActor.run {
                    viewModel?.applyRealtimePayload(event.payload)
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
            MarkdownText(item.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
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

#endif
