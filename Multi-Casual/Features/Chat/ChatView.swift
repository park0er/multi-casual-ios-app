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
                    Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
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
    @State private var draft = ""

    var body: some View {
        List {
            Section {
                MarkdownLabeledContent("Agent", value: viewModel.agentName(for: session.agentId))
                if let pending = viewModel.pendingTask, let status = pending.status {
                    MarkdownLabeledContent("Task", value: status.capitalized)
                }
            }

            Section("Messages") {
                if viewModel.messages.isEmpty && viewModel.errorMessage == nil {
                    MarkdownText("No messages yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.messages) { message in
                        ChatMessageRow(message: message)
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
        .task { await viewModel.selectSession(session) }
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage

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
            MarkdownText(message.content)
                .font(.body)
            if let failureReason = message.failureReason, !failureReason.isEmpty {
                MarkdownText(failureReason)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let elapsedMs = message.elapsedMs {
                Text("Replied in \(max(1, elapsedMs / 1000))s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(color, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 320, alignment: message.role == .assistant ? .leading : .trailing)
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
                    Button(viewModel.isCreating ? "Creating" : "Create") {
                        Task {
                            await viewModel.createSession(agentId: selectedAgentId, title: title)
                            if viewModel.errorMessage == nil {
                                onDone()
                                dismiss()
                            }
                        }
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
