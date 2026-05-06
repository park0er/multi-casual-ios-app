#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct IssueDetailView: View {
    public let issueId: String
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: IssueDetailViewModel?
    @State private var showTranscript = false
    @State private var showEditIssue = false
    @State private var selectedTaskId: String?

    public init(issueId: String) { self.issueId = issueId }

    public var body: some View {
        Group {
            if let vm = viewModel { content(vm: vm) }
            else { ProgressView() }
        }
        .navigationTitle(viewModel?.issue?.identifier ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = IssueDetailViewModel(
                    issueId: issueId,
                    workspaceId: authSession.currentWorkspace?.id,
                    api: api
                )
                Task {
                    await viewModel?.loadInitialData()
                }
            }
        }
        .sheet(isPresented: $showTranscript) {
            if let taskId = selectedTaskId {
                AgentTranscriptView(taskId: taskId)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showEditIssue) {
            if let vm = viewModel, let issue = vm.issue {
                IssueEditSheet(issue: issue) { updated in
                    Task { await vm.applyUpdatedIssue(updated) }
                }
                .presentationDragIndicator(.visible)
            }
        }
        .toolbar {
            if viewModel?.issue != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditIssue = true
                    } label: {
                        Label("Edit Issue", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("IssueDetailEditButton")
                }
            }
        }
    }

    @ViewBuilder
    private func content(vm: IssueDetailViewModel) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let error = vm.error {
                        ErrorMessageRow(message: error) {
                            Task { await vm.loadIssueAndMetadata() }
                        }
                    }
                    if let issue = vm.issue { issueHeader(issue: issue, vm: vm) }
                    Divider()
                    if vm.didLoadAgentRuns || vm.agentRunsError != nil || vm.isLoadingAgentRuns {
                        agentRunsSection(vm: vm)
                        Divider()
                    }
                    Text("Comments").font(.headline).padding(.horizontal)
                    if let commentsError = vm.commentsError {
                        ErrorMessageRow(message: commentsError) {
                            Task { await vm.loadComments() }
                        }
                    }
                    if vm.didLoadComments && vm.commentLoader.items.isEmpty && vm.commentsError == nil && !vm.isLoadingComments {
                        ContentUnavailableView("No Comments", systemImage: "text.bubble", description: Text("This issue has no comments yet."))
                            .padding(.horizontal)
                    }
                    ForEach(vm.commentLoader.items) { comment in CommentRowView(comment: comment) }
                    if vm.commentLoader.hasMore { ProgressView().onAppear {
                        Task { await vm.loadMoreComments() }
                    }}
                }.padding(.vertical)
            }
            .accessibilityIdentifier("IssueDetailScrollView")
            commentInputBar(vm: vm)
        }
    }

    private func issueHeader(issue: Issue, vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MarkdownText(issue.title).font(.title2.bold())
            HStack(spacing: 12) {
                Menu {
                    ForEach(IssueStatus.displayCases, id: \.self) { status in
                        Button {
                            Task { await vm.updateStatus(status) }
                        } label: {
                            Label(status.displayName, systemImage: status.icon)
                        }
                    }
                } label: {
                    Label(issue.status.displayName, systemImage: issue.status.icon)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
                .disabled(vm.isUpdatingIssue)

                Menu {
                    ForEach(IssuePriority.allCases.filter { $0 != .unknown }, id: \.self) { priority in
                        Button {
                            Task { await vm.updatePriority(priority) }
                        } label: {
                            Label(priority.displayName, systemImage: "flag")
                        }
                    }
                } label: {
                    Label(issue.priority.displayName, systemImage: "flag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(vm.isUpdatingIssue)
            }
            if let desc = issue.description, !desc.isEmpty {
                MarkdownText(desc).font(.body)
            }
            if !issue.labels.isEmpty {
                LabelWrapView(labels: issue.labels)
            }
            if !issue.attachments.isEmpty {
                AttachmentListView(attachments: issue.attachments)
            }
            VStack(alignment: .leading, spacing: 6) {
                detailLine(
                    icon: "person.crop.circle",
                    title: "Assignee",
                    value: assigneeText(issue: issue, vm: vm)
                )
                detailLine(
                    icon: "folder",
                    title: "Project",
                    value: projectText(issue: issue, vm: vm)
                )
                detailLine(
                    icon: "calendar",
                    title: "Created",
                    value: iso8601DateOnlyFormatter.string(from: issue.createdAt)
                )
                detailLine(
                    icon: "clock",
                    title: "Updated",
                    value: iso8601DateOnlyFormatter.string(from: issue.updatedAt)
                )
            }
            if let metadataError = vm.metadataError {
                ErrorMessageRow(message: metadataError) {
                    Task { await vm.loadMetadata() }
                }
            }
        }.padding(.horizontal)
    }

    private func detailLine(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func assigneeText(issue: Issue, vm: IssueDetailViewModel) -> String {
        guard let assigneeId = issue.assigneeId, let assigneeType = issue.assigneeType else {
            return "Unassigned"
        }
        return vm.assigneeDisplayName ?? "\(assigneeType.capitalized) \(assigneeId.prefix(8))"
    }

    private func projectText(issue: Issue, vm: IssueDetailViewModel) -> String {
        guard let projectId = issue.projectId else {
            return "No Project"
        }
        return vm.projectDisplayName ?? String(projectId.prefix(8))
    }

    private func agentRunsSection(vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Activity").font(.headline).padding(.horizontal)
            if vm.isLoadingAgentRuns {
                ProgressView().padding(.horizontal)
            }
            if let agentRunsError = vm.agentRunsError {
                ErrorMessageRow(message: agentRunsError) {
                    Task { await vm.loadAgentRuns() }
                }
            }
            if vm.didLoadAgentRuns && vm.agentRuns.isEmpty && vm.agentRunsError == nil && !vm.isLoadingAgentRuns {
                ContentUnavailableView("No Agent Activity", systemImage: "bolt", description: Text("This issue has no agent runs yet."))
                    .padding(.horizontal)
            }
            if let running = vm.agentRuns.first(where: { $0.status == "running" }) {
                AgentLiveView(taskId: running.id)
            }
            ForEach(vm.agentRuns) { run in
                Button { selectedTaskId = run.id; showTranscript = true } label: {
                    AgentRunRowView(run: run)
                }.buttonStyle(.plain)
            }
        }
    }

    private func commentInputBar(vm: IssueDetailViewModel) -> some View {
        HStack(spacing: 12) {
            TextField("Add a comment…", text: Binding(
                get: { vm.commentDraft }, set: { vm.commentDraft = $0 }
            ), axis: .vertical)
            .lineLimit(1...4).padding(.horizontal, 12).padding(.vertical, 8)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityIdentifier("IssueDetailCommentInput")

            Button { Task { await vm.submitComment() } } label: {
                if vm.isSubmittingComment { ProgressView() }
                else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(vm.canSubmitComment ? Color.blue : Color.secondary)
                }
            }
            .disabled(!vm.canSubmitComment)
            .accessibilityIdentifier("IssueDetailCommentSendButton")
        }
        .padding(.horizontal).padding(.vertical, 8).background(.background)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct ErrorMessageRow: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        Group {
            if let retry {
                ErrorRetryView(message: message, retry: retry)
            } else {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
    }
}

public struct CommentRowView: View {
    public let comment: Comment
    public init(comment: Comment) { self.comment = comment }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: comment.authorType == "agent" ? "bolt.circle" : "person.circle")
                Text(comment.authorType == "agent" ? "Agent" : "Member").font(.caption.bold())
                Spacer()
                Text(iso8601DateOnlyFormatter.string(from: comment.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }
            MarkdownText(comment.content).font(.body)
            if !comment.attachments.isEmpty {
                AttachmentListView(attachments: comment.attachments)
            }
        }.padding(.horizontal).padding(.vertical, 6)
    }
}

private struct AttachmentListView: View {
    let attachments: [Attachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(attachments) { attachment in
                AttachmentRowView(attachment: attachment)
            }
        }
    }
}

private struct LabelWrapView: View {
    let labels: [IssueLabel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(labels) { label in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: label.color) ?? .secondary)
                            .frame(width: 8, height: 8)
                        MarkdownText(label.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.1), in: Capsule())
                }
            }
        }
    }
}

private struct AttachmentRowView: View {
    let attachment: Attachment

    var body: some View {
        Group {
            if let url = URL(string: attachment.downloadUrl.isEmpty ? attachment.url : attachment.downloadUrl) {
                Link(destination: url) {
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                MarkdownText(attachment.filename)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(fileDetails)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.down.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        if attachment.contentType.hasPrefix("image/") { return "photo" }
        if attachment.contentType == "application/pdf" { return "doc.richtext" }
        return "paperclip"
    }

    private var fileDetails: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(attachment.sizeBytes))
    }
}

public struct AgentRunRowView: View {
    public let run: AgentTask
    public init(run: AgentTask) { self.run = run }
    public var body: some View {
        HStack {
            Image(systemName: statusIcon).foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent run").font(.subheadline.bold())
                Text(run.startedAt.map(iso8601DisplayFormatter.string(from:)) ?? "")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private var statusIcon: String {
        switch run.status {
        case "completed": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        case "running": return "circle.dotted"
        default: return "clock"
        }
    }

    private var statusColor: Color {
        switch run.status {
        case "completed": return .green
        case "failed": return .red
        case "running": return .blue
        default: return .secondary
        }
    }
}
#endif
