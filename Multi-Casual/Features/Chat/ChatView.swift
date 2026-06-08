#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct ChatView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: ChatViewModel?
    @State private var showCreateSheet = false

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.isLoading && vm.sessions.isEmpty {
                        ProgressView()
                    } else if vm.sessions.isEmpty && vm.errorMessage == nil {
                        ContentUnavailableView(
                            "No Chats",
                            systemImage: "message",
                            description: Text("Start a chat with an agent in this workspace.")
                        )
                    } else {
                        ForEach(vm.sessions) { session in
                            NavigationLink {
                                ChatSessionDetailView(viewModel: vm, session: session)
                            } label: {
                                ChatSessionRow(session: session, agentName: vm.agentName(for: session.agentId), pendingCount: vm.pendingTaskCount(for: session))
                            }
                        }
                    }

                    if let errorMessage = vm.errorMessage {
                        Section {
                            ErrorRetryView(message: errorMessage) {
                                Task { await vm.load() }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.load() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("New Chat", systemImage: "plus")
                        }
                        .accessibilityIdentifier("ChatNewButton")
                    }
                }
                .sheet(isPresented: $showCreateSheet) {
                    ChatCreateSheet(viewModel: vm) { showCreateSheet = false }
                        .presentationDragIndicator(.visible)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Chat")
        .onAppear {
            if viewModel == nil {
                let vm = ChatViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.load() }
        }
    }
}

private struct ChatSessionRow: View {
    let session: ChatSession
    let agentName: String
    let pendingCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: pendingCount > 0 ? "message.badge.waveform" : "message")
                .foregroundStyle(session.hasUnread ? Color.accentColor : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    MarkdownText(session.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if session.hasUnread {
                        Text("Unread")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                MarkdownText(agentName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    MarkdownText(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    if pendingCount > 0 {
                        Text("Running")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ChatSessionDetailView: View {
    @Bindable var viewModel: ChatViewModel
    let session: ChatSession
    @Environment(AuthSession.self) private var authSession
    @State private var draft = ""
    @State private var subscriptionTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                MarkdownLabeledContent("Agent", value: viewModel.agentName(for: session.agentId))
                if let pending = viewModel.pendingTask, let status = pending.status {
                    MarkdownLabeledContent("Task", value: status.capitalized)
                    Button(role: .destructive) {
                        Task { await viewModel.cancelPendingTask() }
                    } label: {
                        MarkdownIconLabel(viewModel.isCancellingTask ? "Cancelling" : "Cancel Task", systemImage: "xmark.circle")
                    }
                    .disabled(viewModel.isCancellingTask || pending.taskId?.isEmpty != false)
                    .accessibilityIdentifier("ChatCancelPendingTaskButton")
                }
            }

            Section("Messages") {
                if viewModel.messages.isEmpty && viewModel.errorMessage == nil {
                    MarkdownText("No messages yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.messages) { message in
                        ChatMessageRow(
                            message: message,
                            timeline: viewModel.timelineItems(for: message)
                        )
                    }
                    if viewModel.shouldShowLiveTimeline {
                        ChatLiveTimelineRow(
                            pendingTask: viewModel.pendingTask,
                            timeline: viewModel.visibleTimelineItems,
                            isLoading: viewModel.isSending || viewModel.isLoadingTimeline,
                            errorMessage: viewModel.timelineError
                        )
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    ErrorRetryView(message: errorMessage) {
                        Task { await viewModel.loadMessages() }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("ChatMessageField")
                Button {
                    let content = draft
                    draft = ""
                    Task { await viewModel.sendMessage(content) }
                } label: {
                    Image(systemName: viewModel.isSending ? "hourglass" : "paperplane.fill")
                }
                .disabled(viewModel.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("ChatSendButton")
            }
            .padding()
            .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    Task { await viewModel.archiveSelectedSession() }
                } label: {
                    Image(systemName: "archivebox")
                }
                .accessibilityIdentifier("ChatArchiveButton")
            }
        }
        .markdownNavigationTitle(session.title)
        .task {
            await viewModel.selectSession(session)
            subscribeToWebSocket()
        }
        .onDisappear {
            subscriptionTask?.cancel()
            subscriptionTask = nil
        }
    }

    private func subscribeToWebSocket() {
        subscriptionTask?.cancel()
        guard let token = authSession.token(),
              let workspaceId = authSession.currentWorkspace?.id,
              !workspaceId.isEmpty
        else { return }
        subscriptionTask = Task {
            await WebSocketActor.shared.connect(token: token, workspaceId: workspaceId)
            for await event in await WebSocketActor.shared.subscribe(to: "task:message") {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    viewModel.applyRealtimeTaskMessage(taskId: event.taskId, payload: event.payload)
                }
            }
        }
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    let timeline: [TimelineItem]

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble(alignment: .leading, color: Color.secondary.opacity(0.12))
                Spacer(minLength: 32)
            } else {
                Spacer(minLength: 32)
                bubble(alignment: .trailing, color: Color.accentColor.opacity(0.14))
            }
        }
        .listRowSeparator(.hidden)
    }

    private func bubble(alignment: HorizontalAlignment, color: Color) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            if message.role == .assistant, !timeline.isEmpty {
                ChatTimelineView(items: timeline)
            } else {
                MarkdownText(message.content)
                    .font(.body)
            }
            if let failureReason = message.failureReason, !failureReason.isEmpty {
                MarkdownText(failureReason)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let elapsedMs = message.elapsedMs {
                MarkdownText("Replied in \(max(1, elapsedMs / 1000))s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(color, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 320, alignment: message.role == .assistant ? .leading : .trailing)
    }
}

private struct ChatLiveTimelineRow: View {
    let pendingTask: ChatPendingTask?
    let timeline: [TimelineItem]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    MarkdownText(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    MarkdownText(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if timeline.isEmpty {
                    MarkdownText(isLoading ? "Loading agent activity" : "Waiting for agent updates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ChatTimelineView(items: timeline)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 320, alignment: .leading)
            Spacer(minLength: 32)
        }
        .listRowSeparator(.hidden)
    }

    private var statusText: String {
        if let status = pendingTask?.status, !status.isEmpty {
            switch status {
            case "queued", "pending":
                return "Agent queued"
            case "running", "in_progress":
                return "Agent running"
            default:
                return "Agent \(status.replacingOccurrences(of: "_", with: " "))"
            }
        }
        return "Thinking"
    }
}

private struct ChatTimelineView: View {
    let items: [TimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items) { item in
                ChatTimelineItemRow(item: item)
            }
        }
    }
}

private struct ChatTimelineItemRow: View {
    let item: TimelineItem

    var body: some View {
        switch item.type {
        case .text:
            MarkdownText(item.content ?? item.summary)
                .font(.body)
        case .toolUse:
            DisclosureGroup {
                if let input = item.input, !input.isEmpty {
                    TimelinePreformattedBlock(title: "Tool Input", text: formattedJSON(input))
                }
            } label: {
                timelineLabel(icon: "wrench", title: item.tool ?? "Tool Use", subtitle: item.summary)
            }
            .font(.caption)
        case .toolResult:
            DisclosureGroup {
                TimelinePreformattedBlock(title: "Tool Output", text: item.output ?? "")
            } label: {
                timelineLabel(icon: "checkmark.circle", title: item.tool ?? "Result", subtitle: item.summary)
            }
            .font(.caption)
        case .thinking:
            DisclosureGroup {
                TimelinePreformattedBlock(title: "Thinking", text: item.content ?? "")
            } label: {
                timelineLabel(icon: "brain", title: "Thinking", subtitle: item.summary)
            }
            .font(.caption)
        case .error:
            timelineLabel(icon: "exclamationmark.triangle", title: "Error", subtitle: item.summary)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func timelineLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .frame(width: 16)
            MarkdownText(title)
                .font(.caption.weight(.semibold))
            if !subtitle.isEmpty, subtitle != title {
                MarkdownText(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func formattedJSON(_ value: [String: JSONValue]) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8)
        else { return value.map { "\($0.key): \($0.value.displayString)" }.joined(separator: "\n") }
        return text
    }
}

private struct TimelinePreformattedBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarkdownText(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: true) {
                Text(text)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
            }
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.top, 4)
    }
}

private struct ChatCreateSheet: View {
    @Bindable var viewModel: ChatViewModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAgentId = ""
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent") {
                    Picker("Agent", selection: $selectedAgentId) {
                        ForEach(viewModel.agents) { agent in
                            MarkdownText(agent.name).tag(agent.id)
                        }
                    }
                    .accessibilityIdentifier("ChatCreateAgentPicker")
                }
                Section("Title") {
                    TextField("Optional title", text: $title)
                        .accessibilityIdentifier("ChatCreateTitleField")
                }
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createSession(agentId: selectedAgentId, title: title)
                            if viewModel.errorMessage == nil {
                                onDone()
                                dismiss()
                            }
                        }
                    } label: {
                        MarkdownText(viewModel.isCreating ? "Creating" : "Create")
                    }
                    .disabled(viewModel.isCreating || selectedAgentId.isEmpty)
                    .accessibilityIdentifier("ChatCreateButton")
                }
            }
            .onAppear {
                if selectedAgentId.isEmpty {
                    selectedAgentId = viewModel.agents.first?.id ?? ""
                }
            }
        }
    }
}
#endif
