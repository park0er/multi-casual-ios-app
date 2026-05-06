#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UniformTypeIdentifiers

public struct IssueDetailView: View {
    public let issueId: String
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: IssueDetailViewModel?
    @State private var showTranscript = false
    @State private var showEditIssue = false
    @State private var showCreateSubIssue = false
    @State private var showSubscribers = false
    @State private var showCommentAttachmentImporter = false
    @State private var showDeleteIssueConfirmation = false
    @State private var showCancelTaskConfirmation = false
    @State private var showDeleteAttachmentConfirmation = false
    @State private var pendingCancelTask: AgentTask?
    @State private var pendingDeleteAttachment: Attachment?
    @State private var selectedTaskId: String?
    @State private var selectedTaskWorkspaceId: String?
    @State private var pinViewModel: PinToggleViewModel?

    public init(issueId: String) { self.issueId = issueId }

    public var body: some View {
        Group {
            if let vm = viewModel { content(vm: vm) }
            else { ProgressView() }
        }
        .markdownNavigationTitle(viewModel?.issue?.identifier ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = IssueDetailViewModel(
                    issueId: issueId,
                    workspaceId: authSession.currentWorkspace?.id,
                    api: api
                )
                let pinVM = PinToggleViewModel(itemType: .issue, itemId: issueId, api: api, authSession: authSession)
                pinViewModel = pinVM
                Task {
                    await pinVM.load()
                    await viewModel?.loadInitialData()
                }
            }
        }
        .sheet(isPresented: $showTranscript) {
            if let taskId = selectedTaskId {
                AgentTranscriptView(taskId: taskId, workspaceId: selectedTaskWorkspaceId ?? viewModel?.resolvedWorkspaceId)
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
        .sheet(isPresented: $showSubscribers) {
            if let vm = viewModel {
                SubscriberManagementView(vm: vm)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showCreateSubIssue) {
            if let vm = viewModel, let issue = vm.issue {
                IssueCreateSheet(parentIssue: issue) {
                    Task {
                        await vm.loadIssueRelations()
                        await vm.loadIssue()
                    }
                }
                .presentationDragIndicator(.visible)
            }
        }
        .toolbar {
            if viewModel?.issue != nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let pinViewModel {
                        Button {
                            Task { await pinViewModel.toggle() }
                        } label: {
                            Label(
                                pinViewModel.isPinned ? "Unpin Issue" : "Pin Issue",
                                systemImage: pinViewModel.isPinned ? "pin.slash" : "pin"
                            )
                        }
                        .disabled(pinViewModel.isLoading)
                        .accessibilityIdentifier("IssueDetailPinButton")
                    }
                    Button {
                        showEditIssue = true
                    } label: {
                        Label("Edit Issue", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("IssueDetailEditButton")
                    Button(role: .destructive) {
                        showDeleteIssueConfirmation = true
                    } label: {
                        Label("Delete Issue", systemImage: "trash")
                    }
                    .disabled(viewModel?.isDeletingIssue == true)
                    .accessibilityIdentifier("IssueDetailDeleteButton")
                }
            }
        }
        .destructiveConfirmation(
            deleteIssueConfirmation,
            isPresented: $showDeleteIssueConfirmation
        ) {
            Task {
                await viewModel?.deleteIssue()
                if viewModel?.didDeleteIssue == true {
                    dismiss()
                }
            }
        }
        .destructiveConfirmation(
            cancelTaskConfirmation,
            isPresented: $showCancelTaskConfirmation,
            onConfirm: {
                guard let taskId = pendingCancelTask?.id else { return }
                Task {
                    await viewModel?.cancelActiveTask(id: taskId)
                    pendingCancelTask = nil
                }
            },
            onCancel: {
                pendingCancelTask = nil
            }
        )
        .destructiveConfirmation(
            deleteAttachmentConfirmation,
            isPresented: $showDeleteAttachmentConfirmation,
            onConfirm: {
                guard let attachment = pendingDeleteAttachment else { return }
                Task {
                    await viewModel?.deleteAttachment(id: attachment.id)
                    pendingDeleteAttachment = nil
                }
            },
            onCancel: {
                pendingDeleteAttachment = nil
            }
        )
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
                    if let deleteIssueError = vm.deleteIssueError {
                        ErrorMessageRow(message: deleteIssueError)
                    }
                    if let issue = vm.issue {
                        issueHeader(issue: issue, vm: vm, currentUserId: authSession.currentUser?.id)
                    }
                    Divider()
                    subIssuesSection(vm: vm)
                    Divider()
                    subscribersSection(vm: vm, currentUserId: authSession.currentUser?.id)
                    Divider()
                    if vm.didLoadTimeline || vm.timelineError != nil || vm.isLoadingTimeline {
                        timelineSection(vm: vm)
                        Divider()
                    }
                    if vm.didLoadUsage || vm.usageError != nil || vm.isLoadingUsage {
                        usageSection(vm: vm)
                        Divider()
                    }
                    if vm.didLoadActiveTasks || vm.activeTasksError != nil || vm.isLoadingActiveTasks {
                        activeTasksSection(vm: vm)
                        Divider()
                    }
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
                    ForEach(vm.commentLoader.items) { comment in
                        CommentRowView(
                            comment: comment,
                            currentUserId: authSession.currentUser?.id,
                            replyAttachments: vm.replyAttachments[comment.id] ?? [],
                            isUploadingReplyAttachment: vm.uploadingReplyAttachmentIds.contains(comment.id),
                            onReply: { parentId, content in
                                await vm.submitReply(parentId: parentId, content: content)
                            },
                            onEdit: { commentId, content in
                                await vm.updateComment(commentId: commentId, content: content)
                            },
                            onDelete: { commentId in
                                await vm.deleteComment(commentId: commentId)
                            },
                            onUploadReplyAttachment: { parentId, payload in
                                await vm.uploadReplyAttachment(
                                    parentId: parentId,
                                    filename: payload.filename,
                                    data: payload.data,
                                    contentType: payload.contentType
                                )
                            },
                            onToggleReaction: { emoji in
                                Task {
                                    await vm.toggleCommentReaction(
                                        commentId: comment.id,
                                        emoji: emoji,
                                        currentUserId: authSession.currentUser?.id
                                    )
                                }
                            }
                        )
                    }
                    if vm.commentLoader.hasMore { ProgressView().onAppear {
                        Task { await vm.loadMoreComments() }
                    }}
                }.padding(.vertical)
            }
            .accessibilityIdentifier("IssueDetailScrollView")
            commentInputBar(vm: vm)
        }
    }

    private var deleteIssueConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.deleteIssue(
            identifier: viewModel?.issue?.identifier,
            title: viewModel?.issue?.title
        )
    }

    private var cancelTaskConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.cancelTask(id: pendingCancelTask?.id ?? "")
    }

    private var deleteAttachmentConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.deleteAttachment(filename: pendingDeleteAttachment?.filename ?? "")
    }

    private func issueHeader(issue: Issue, vm: IssueDetailViewModel, currentUserId: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MarkdownText(issue.title).font(.title2.bold())
            if let parentIssue = vm.parentIssue {
                NavigationLink {
                    IssueDetailView(issueId: parentIssue.id)
                } label: {
                    HStack(spacing: 6) {
                        Text("Sub-issue of")
                            .font(.caption.weight(.medium))
                        Image(systemName: parentIssue.status.icon)
                        MarkdownText(parentIssue.identifier)
                            .font(.caption.monospacedDigit())
                        MarkdownText(parentIssue.title)
                            .font(.caption)
                            .lineLimit(1)
                        if !vm.parentSiblingIssues.isEmpty {
                            MarkdownText(vm.parentChildProgressText)
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.12), in: Capsule())
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 12) {
                Menu {
                    ForEach(IssueStatus.displayCases, id: \.self) { status in
                        Button {
                            Task { await vm.updateStatus(status) }
                        } label: {
                            MarkdownIconLabel(status.displayName, systemImage: status.icon)
                        }
                    }
                } label: {
                    MarkdownIconLabel(issue.status.displayName, systemImage: issue.status.icon)
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
                            MarkdownIconLabel(priority.displayName, systemImage: "flag")
                        }
                    }
                } label: {
                    MarkdownIconLabel(issue.priority.displayName, systemImage: "flag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(vm.isUpdatingIssue)
            }
            if let desc = issue.description, !desc.isEmpty {
                MarkdownText(desc).font(.body)
            }
            ReactionBarView(badges: issueReactionBadges(issue.reactions, currentUserId: currentUserId)) { emoji in
                Task { await vm.toggleIssueReaction(emoji: emoji, currentUserId: currentUserId) }
            }
            if !issue.labels.isEmpty {
                LabelWrapView(labels: issue.labels)
            }
            if !issue.attachments.isEmpty {
                AttachmentListView(
                    attachments: issue.attachments,
                    deletingAttachmentIds: vm.deletingAttachmentIds
                ) { attachment in
                    pendingDeleteAttachment = attachment
                    showDeleteAttachmentConfirmation = true
                }
            }
            if let attachmentsError = vm.attachmentsError {
                ErrorMessageRow(message: attachmentsError) {
                    Task { await vm.loadAttachments() }
                }
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
            MarkdownText(title)
                .foregroundStyle(.secondary)
            Spacer()
            MarkdownText(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func subIssuesSection(vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sub-issues").font(.headline)
                if !vm.childIssues.isEmpty {
                    MarkdownText(vm.childProgressText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }
                Spacer()
                Button {
                    showCreateSubIssue = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vm.issue == nil)
                .accessibilityLabel("Add Sub-issue")
                .accessibilityIdentifier("IssueDetailAddSubIssueButton")
            }

            if vm.isLoadingIssueRelations && !vm.didLoadIssueRelations {
                ProgressView()
            }
            if let issueRelationsError = vm.issueRelationsError {
                ErrorMessageRow(message: issueRelationsError) {
                    Task { await vm.loadIssueRelations() }
                }
                .padding(.horizontal, -16)
            }
            if vm.didLoadIssueRelations && vm.childIssues.isEmpty && vm.issueRelationsError == nil && !vm.isLoadingIssueRelations {
                Text("No sub-issues")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(vm.childIssues) { child in
                NavigationLink {
                    IssueDetailView(issueId: child.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: child.status.icon)
                            .foregroundStyle(child.status == .done ? Color.green : Color.secondary)
                            .frame(width: 18)
                        MarkdownText(child.identifier)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        MarkdownText(child.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if child.assigneeType != nil {
                            Image(systemName: child.assigneeType == "agent" ? "bolt.circle" : "person.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
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

    private func issueReactionBadges(_ reactions: [IssueReaction], currentUserId: String?) -> [ReactionBadge] {
        let emojis = Array(Set(reactions.map(\.emoji))).sorted()
        return emojis.map { emoji in
            let matching = reactions.filter { $0.emoji == emoji }
            return ReactionBadge(
                emoji: emoji,
                count: matching.count,
                isSelected: matching.contains { $0.actorType == "member" && $0.actorId == currentUserId }
            )
        }
    }

    private func subscribersSection(vm: IssueDetailViewModel, currentUserId: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Subscribers").font(.headline)
                Spacer()
                if let currentUserId {
                    Button {
                        Task { await vm.toggleSubscriber(userId: currentUserId, userType: "member") }
                    } label: {
                        MarkdownText(vm.isSubscribed(userId: currentUserId, userType: "member") ? "Unsubscribe" : "Subscribe")
                            .font(.caption)
                    }
                    .disabled(vm.isLoadingSubscribers)
                    .accessibilityIdentifier("IssueDetailSubscribeButton")
                }
                Button {
                    showSubscribers = true
                } label: {
                    Image(systemName: "person.2.badge.gearshape")
                }
                .disabled(vm.isLoadingSubscribers)
                .accessibilityLabel("Manage Subscribers")
                .accessibilityIdentifier("IssueDetailManageSubscribersButton")
            }

            if vm.isLoadingSubscribers && !vm.didLoadSubscribers {
                ProgressView()
            }
            if let subscribersError = vm.subscribersError {
                ErrorMessageRow(message: subscribersError) {
                    Task { await vm.loadSubscribers() }
                }
                .padding(.horizontal, -16)
            }
            if vm.didLoadSubscribers && vm.subscribers.isEmpty && vm.subscribersError == nil && !vm.isLoadingSubscribers {
                Text("No subscribers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !vm.subscribers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.subscribers) { subscriber in
                            SubscriberChip(subscriber: subscriber, name: vm.displayName(for: subscriber))
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func activeTasksSection(vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Tasks").font(.headline).padding(.horizontal)
            if vm.isLoadingActiveTasks {
                ProgressView().padding(.horizontal)
            }
            if let activeTasksError = vm.activeTasksError {
                ErrorMessageRow(message: activeTasksError) {
                    Task { await vm.loadActiveTasks() }
                }
            }
            if vm.didLoadActiveTasks && vm.activeTasks.isEmpty && vm.activeTasksError == nil && !vm.isLoadingActiveTasks {
                ContentUnavailableView("No Active Tasks", systemImage: "bolt.slash", description: Text("This issue has no running agent tasks."))
                    .padding(.horizontal)
            }
            ForEach(vm.activeTasks) { task in
                VStack(alignment: .leading, spacing: 8) {
                    AgentLiveView(taskId: task.id, workspaceId: vm.resolvedWorkspaceId)
                    HStack {
                        MarkdownText(task.status.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            pendingCancelTask = task
                            showCancelTaskConfirmation = true
                        } label: {
                            Label("Cancel Task", systemImage: "xmark.circle")
                        }
                        .disabled(vm.cancellingTaskIds.contains(task.id))
                    }
                    .padding(.horizontal)
                }
                .accessibilityIdentifier("IssueDetailActiveTaskRow")
            }
        }
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
            if vm.activeTasks.isEmpty, let running = vm.agentRuns.first(where: { $0.status == "running" }) {
                AgentLiveView(taskId: running.id, workspaceId: vm.resolvedWorkspaceId)
            }
            ForEach(vm.agentRuns) { run in
                Button {
                    selectedTaskId = run.id
                    selectedTaskWorkspaceId = vm.resolvedWorkspaceId
                    showTranscript = true
                } label: {
                    AgentRunRowView(run: run)
                }.buttonStyle(.plain)
            }
        }
    }

    private func timelineSection(vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity").font(.headline).padding(.horizontal)
            if vm.isLoadingTimeline {
                ProgressView().padding(.horizontal)
            }
            if let timelineError = vm.timelineError {
                ErrorMessageRow(message: timelineError) {
                    Task { await vm.loadTimeline() }
                }
            }
            if vm.didLoadTimeline && vm.timelineActivities.isEmpty && vm.timelineError == nil && !vm.isLoadingTimeline {
                ContentUnavailableView("No Activity", systemImage: "clock", description: Text("This issue has no activity yet."))
                    .padding(.horizontal)
            }
            ForEach(vm.timelineActivities) { entry in
                TimelineActivityRow(
                    entry: entry,
                    actorName: vm.timelineActorName(for: entry),
                    activityText: vm.activityText(for: entry)
                )
            }
        }
    }

    private func usageSection(vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage").font(.headline).padding(.horizontal)
            if vm.isLoadingUsage {
                ProgressView().padding(.horizontal)
            }
            if let usageError = vm.usageError {
                ErrorMessageRow(message: usageError) {
                    Task { await vm.loadUsage() }
                }
            }
            if let usage = vm.usage {
                VStack(alignment: .leading, spacing: 8) {
                    MarkdownText(vm.usageSummaryText)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 10) {
                        UsageMetricView(title: "Input", value: usage.totalInputTokens)
                        UsageMetricView(title: "Output", value: usage.totalOutputTokens)
                        UsageMetricView(title: "Cache", value: usage.totalCacheReadTokens + usage.totalCacheWriteTokens)
                    }
                }
                .padding(.horizontal)
            }
            if vm.didLoadUsage && vm.usage == nil && vm.usageError == nil && !vm.isLoadingUsage {
                ContentUnavailableView("No Usage", systemImage: "chart.bar", description: Text("This issue has no recorded task usage."))
                    .padding(.horizontal)
            }
        }
    }

    private func commentInputBar(vm: IssueDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !vm.commentAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.commentAttachments) { attachment in
                            Label {
                                MarkdownText(attachment.filename)
                                    .font(.caption)
                            } icon: {
                                Image(systemName: "paperclip")
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }

            HStack(spacing: 12) {
                Button {
                    showCommentAttachmentImporter = true
                } label: {
                    if vm.isUploadingCommentAttachment {
                        ProgressView()
                    } else {
                        Image(systemName: "paperclip.circle")
                            .font(.title3)
                    }
                }
                .disabled(vm.isUploadingCommentAttachment || vm.isSubmittingComment)
                .accessibilityIdentifier("IssueDetailAddCommentAttachmentButton")

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
        }
        .padding(.horizontal).padding(.vertical, 8).background(.background)
        .overlay(alignment: .top) { Divider() }
        .fileImporter(
            isPresented: $showCommentAttachmentImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleCommentAttachmentImport(result, vm: vm)
        }
    }

    private func handleCommentAttachmentImport(_ result: Result<[URL], Error>, vm: IssueDetailViewModel) {
        do {
            guard let url = try result.get().first else { return }
            let payload = try AttachmentImport.payload(from: url)
            Task {
                await vm.uploadCommentAttachment(
                    filename: payload.filename,
                    data: payload.data,
                    contentType: payload.contentType
                )
            }
        } catch {
            vm.error = error.localizedDescription
        }
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
                MarkdownText(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
    }
}

public struct CommentRowView: View {
    public let comment: Comment
    let currentUserId: String?
    let replyAttachments: [Attachment]
    let isUploadingReplyAttachment: Bool
    let onReply: (String, String) async -> Bool
    let onEdit: (String, String) async -> Bool
    let onDelete: (String) async -> Bool
    let onUploadReplyAttachment: (String, AttachmentPayload) async -> Bool
    let onToggleReaction: (String) -> Void

    @State private var isEditing = false
    @State private var editDraft = ""
    @State private var isReplying = false
    @State private var replyDraft = ""
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var showReplyAttachmentImporter = false
    @State private var replyAttachmentError: String?

    public init(
        comment: Comment,
        currentUserId: String? = nil,
        replyAttachments: [Attachment] = [],
        isUploadingReplyAttachment: Bool = false,
        onReply: @escaping (String, String) async -> Bool = { _, _ in false },
        onEdit: @escaping (String, String) async -> Bool = { _, _ in false },
        onDelete: @escaping (String) async -> Bool = { _ in false },
        onUploadReplyAttachment: @escaping (String, AttachmentPayload) async -> Bool = { _, _ in false },
        onToggleReaction: @escaping (String) -> Void = { _ in }
    ) {
        self.comment = comment
        self.currentUserId = currentUserId
        self.replyAttachments = replyAttachments
        self.isUploadingReplyAttachment = isUploadingReplyAttachment
        self.onReply = onReply
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onUploadReplyAttachment = onUploadReplyAttachment
        self.onToggleReaction = onToggleReaction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: comment.authorType == "agent" ? "bolt.circle" : "person.circle")
                MarkdownText(comment.authorType == "agent" ? "Agent" : "Member").font(.caption.bold())
                Spacer()
                MarkdownText(iso8601DateOnlyFormatter.string(from: comment.createdAt)).font(.caption2).foregroundStyle(.secondary)
                if currentUserId != nil {
                    Menu {
                        Button {
                            replyDraft = ""
                            isReplying.toggle()
                        } label: {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                        }

                        if canEdit {
                            Button {
                                editDraft = comment.content
                                isEditing = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }

                        if canDelete {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Comment Actions")
                }
            }
            if isEditing {
                VStack(alignment: .trailing, spacing: 8) {
                    TextEditor(text: $editDraft)
                        .frame(minHeight: 88)
                        .padding(8)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("CommentEditEditor")
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            editDraft = ""
                            isEditing = false
                        }
                        .buttonStyle(.borderless)

                        Button {
                            Task { await saveEdit() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving || editDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                MarkdownText(comment.content).font(.body)
            }
            if !comment.attachments.isEmpty {
                AttachmentListView(attachments: comment.attachments)
            }
            ReactionBarView(badges: commentReactionBadges(comment.reactions), onToggle: onToggleReaction)
            if isReplying {
                VStack(alignment: .trailing, spacing: 8) {
                    if !replyAttachments.isEmpty {
                        AttachmentListView(attachments: replyAttachments)
                    }
                    if let replyAttachmentError {
                        MarkdownText(replyAttachmentError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    TextEditor(text: $replyDraft)
                        .frame(minHeight: 72)
                        .padding(8)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("CommentReplyEditor")
                    HStack(spacing: 8) {
                        Button {
                            showReplyAttachmentImporter = true
                        } label: {
                            if isUploadingReplyAttachment {
                                ProgressView()
                            } else {
                                Label("Add Attachment", systemImage: "paperclip")
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isSaving || isUploadingReplyAttachment)
                        .accessibilityIdentifier("CommentReplyAddAttachmentButton")

                        Spacer()

                        Button("Cancel") {
                            replyDraft = ""
                            isReplying = false
                        }
                        .buttonStyle(.borderless)

                        Button {
                            Task { await submitReply() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Reply")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving || isUploadingReplyAttachment || replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }.padding(.horizontal).padding(.vertical, 6)
            .fileImporter(
                isPresented: $showReplyAttachmentImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                handleReplyAttachmentImport(result)
            }
            .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        isSaving = true
                        _ = await onDelete(comment.id)
                        isSaving = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This comment and its replies will be deleted.")
            }
    }

    private var canEdit: Bool {
        comment.authorType == "member" && comment.authorId == currentUserId
    }

    private var canDelete: Bool {
        comment.authorId == currentUserId
    }

    private func saveEdit() async {
        isSaving = true
        defer { isSaving = false }
        let saved = await onEdit(comment.id, editDraft)
        if saved {
            editDraft = ""
            isEditing = false
        }
    }

    private func submitReply() async {
        isSaving = true
        defer { isSaving = false }
        let submitted = await onReply(comment.id, replyDraft)
        if submitted {
            replyDraft = ""
            isReplying = false
        }
    }

    private func handleReplyAttachmentImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let payload = try AttachmentImport.payload(from: url)
            replyAttachmentError = nil
            Task {
                let uploaded = await onUploadReplyAttachment(comment.id, payload)
                if !uploaded {
                    replyAttachmentError = "Upload failed."
                }
            }
        } catch {
            replyAttachmentError = error.localizedDescription
        }
    }

    private func commentReactionBadges(_ reactions: [Reaction]) -> [ReactionBadge] {
        let emojis = Array(Set(reactions.map(\.emoji))).sorted()
        return emojis.map { emoji in
            let matching = reactions.filter { $0.emoji == emoji }
            return ReactionBadge(
                emoji: emoji,
                count: matching.count,
                isSelected: matching.contains { $0.actorType == "member" && $0.actorId == currentUserId }
            )
        }
    }
}

private let quickReactionEmojis = ["👍", "👀", "🚀", "❤️", "🎉"]

private struct ReactionBadge: Identifiable {
    let emoji: String
    let count: Int
    let isSelected: Bool

    var id: String { emoji }
}

private struct ReactionBarView: View {
    let badges: [ReactionBadge]
    let onToggle: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(badges) { badge in
                Button {
                    onToggle(badge.emoji)
                } label: {
                    MarkdownText("\(badge.emoji) \(badge.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            badge.isSelected ? Color.blue.opacity(0.16) : Color.secondary.opacity(0.1),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Menu {
                ForEach(quickReactionEmojis, id: \.self) { emoji in
                    Button(emoji) {
                        onToggle(emoji)
                    }
                }
            } label: {
                Image(systemName: "face.smiling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.secondary.opacity(0.08), in: Capsule())
            }
            .accessibilityLabel("Add Reaction")
        }
    }
}

private struct SubscriberChip: View {
    let subscriber: IssueSubscriber
    let name: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: subscriber.userType == "agent" ? "bolt.circle" : "person.circle")
                .foregroundStyle(.secondary)
            MarkdownText(name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.secondary.opacity(0.1), in: Capsule())
    }
}

private struct SubscriberManagementView: View {
    @Bindable var vm: IssueDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if vm.subscriberMembers.isEmpty && vm.subscriberAgents.isEmpty {
                    Section {
                        if vm.isLoadingSubscribers {
                            ProgressView()
                        } else {
                            Text("No people or agents available")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !vm.subscriberMembers.isEmpty {
                    Section("Members") {
                        ForEach(uniqueMembers(vm.subscriberMembers)) { member in
                            SubscriberToggleRow(
                                title: member.name,
                                subtitle: member.email,
                                icon: "person.circle",
                                isSelected: vm.isSubscribed(userId: member.userId, userType: "member"),
                                isLoading: vm.isLoadingSubscribers
                            ) {
                                Task { await vm.toggleSubscriber(userId: member.userId, userType: "member") }
                            }
                        }
                    }
                }
                if !vm.subscriberAgents.isEmpty {
                    Section("Agents") {
                        ForEach(vm.subscriberAgents) { agent in
                            SubscriberToggleRow(
                                title: agent.name,
                                subtitle: agent.status.capitalized,
                                icon: "bolt.circle",
                                isSelected: vm.isSubscribed(userId: agent.id, userType: "agent"),
                                isLoading: vm.isLoadingSubscribers
                            ) {
                                Task { await vm.toggleSubscriber(userId: agent.id, userType: "agent") }
                            }
                        }
                    }
                }
                if let subscribersError = vm.subscribersError {
                    Section {
                        ErrorMessageRow(message: subscribersError) {
                            Task { await vm.loadSubscribers() }
                        }
                        .padding(.horizontal, -16)
                    }
                }
            }
            .navigationTitle("Subscribers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if !vm.didLoadSubscribers {
                    await vm.loadSubscribers()
                }
            }
        }
    }

    private func uniqueMembers(_ members: [WorkspaceMember]) -> [WorkspaceMember] {
        var seen = Set<String>()
        return members.filter { member in
            guard !seen.contains(member.userId) else { return false }
            seen.insert(member.userId)
            return true
        }
    }
}

private struct SubscriberToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    MarkdownText(title)
                        .font(.body)
                        .lineLimit(1)
                    MarkdownText(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

private struct AttachmentListView: View {
    let attachments: [Attachment]
    var deletingAttachmentIds: Set<String> = []
    var onDelete: ((Attachment) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(attachments) { attachment in
                AttachmentRowView(
                    attachment: attachment,
                    isDeleting: deletingAttachmentIds.contains(attachment.id),
                    onDelete: onDelete
                )
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
    var isDeleting = false
    var onDelete: ((Attachment) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
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

            if let onDelete {
                Button(role: .destructive) {
                    onDelete(attachment)
                } label: {
                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .disabled(isDeleting)
                .accessibilityLabel("Delete \(attachment.filename)")
                .accessibilityIdentifier("AttachmentDeleteButton-\(attachment.id)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
                MarkdownText(fileDetails)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.down.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
                MarkdownText(run.startedAt.map(iso8601DisplayFormatter.string(from:)) ?? "")
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

private struct TimelineActivityRow: View {
    let entry: TimelineEntry
    let actorName: String
    let activityText: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    MarkdownText(actorName)
                        .font(.caption.weight(.semibold))
                    MarkdownText(iso8601DateOnlyFormatter.string(from: entry.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                MarkdownText(activityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch entry.action {
        case "status_changed":
            return "circle.dotted"
        case "priority_changed":
            return "flag"
        case "assignee_changed":
            return "person.crop.circle"
        case "due_date_changed":
            return "calendar"
        case "task_completed":
            return "checkmark.circle"
        case "task_failed":
            return "exclamationmark.triangle"
        default:
            return "clock"
        }
    }
}

private struct UsageMetricView: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MarkdownText(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            MarkdownText(value.formatted())
                .font(.caption.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
