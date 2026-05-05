#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct IssueDetailView: View {
    public let issueId: String
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: IssueDetailViewModel?
    @State private var showTranscript = false
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
                    await viewModel?.loadIssue()
                    await viewModel?.loadMetadata()
                    await viewModel?.loadComments()
                    await viewModel?.loadAgentRuns()
                }
            }
        }
        .fullScreenCover(isPresented: $showTranscript) {
            if let taskId = selectedTaskId { AgentTranscriptView(taskId: taskId) }
        }
    }

    @ViewBuilder
    private func content(vm: IssueDetailViewModel) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let error = vm.error {
                        ErrorMessageRow(message: error) {
                            Task { await vm.loadIssue() }
                        }
                    }
                    if let issue = vm.issue { issueHeader(issue: issue, vm: vm) }
                    Divider()
                    if !vm.agentRuns.isEmpty || vm.agentRunsError != nil || vm.isLoadingAgentRuns {
                        agentRunsSection(vm: vm)
                        Divider()
                    }
                    Text("Comments").font(.headline).padding(.horizontal)
                    if let commentsError = vm.commentsError {
                        ErrorMessageRow(message: commentsError) {
                            Task { await vm.loadComments() }
                        }
                    }
                    ForEach(vm.commentLoader.items) { comment in CommentRowView(comment: comment) }
                    if vm.commentLoader.hasMore { ProgressView().onAppear {
                        Task { await vm.loadMoreComments() }
                    }}
                }.padding(.vertical)
            }
            commentInputBar(vm: vm)
        }
    }

    private func issueHeader(issue: Issue, vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(issue.title).font(.title2.bold())
            HStack(spacing: 12) {
                Label(issue.status.displayName, systemImage: issue.status.icon)
                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.secondary.opacity(0.12), in: Capsule())
                Label(issue.priority.displayName, systemImage: "flag")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let desc = issue.description, !desc.isEmpty {
                Text(desc).font(.body)
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

            Button { Task { await vm.submitComment() } } label: {
                if vm.isSubmittingComment { ProgressView() }
                else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(vm.commentDraft.isEmpty ? Color.secondary : Color.blue)
                }
            }
            .disabled(vm.commentDraft.isEmpty || vm.isSubmittingComment)
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
            Text(comment.content).font(.body)
        }.padding(.horizontal).padding(.vertical, 6)
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
