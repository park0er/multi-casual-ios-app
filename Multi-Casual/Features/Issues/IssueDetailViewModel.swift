import Foundation
import Observation

@Observable
@MainActor
public final class IssueDetailViewModel {
    public let issueId: String
    public let workspaceId: String?
    public var issue: Issue?
    public var parentIssue: Issue?
    public var childIssues: [Issue] = []
    public var parentSiblingIssues: [Issue] = []
    public var agentRuns: [AgentTask] = []
    public var activeTasks: [AgentTask] = []
    public var timelineEntries: [TimelineEntry] = []
    public var usage: IssueUsageSummary?
    public var subscribers: [IssueSubscriber] = []
    public var subscriberMembers: [WorkspaceMember] = []
    public var subscriberAgents: [Agent] = []
    public let commentLoader = PaginatedLoader<Comment>()
    public var commentDraft = ""
    public var commentAttachments: [Attachment] = []
    public var replyAttachments: [String: [Attachment]] = [:]
    public var isSubmittingComment = false
    public var isUploadingCommentAttachment = false
    public var uploadingReplyAttachmentIds: Set<String> = []
    public var isLoadingIssue = false
    public var isLoadingComments = false
    public var isLoadingAgentRuns = false
    public var isLoadingActiveTasks = false
    public var isLoadingTimeline = false
    public var isLoadingUsage = false
    public var isLoadingSubscribers = false
    public var isLoadingIssueRelations = false
    public var isDeletingIssue = false
    public var cancellingTaskIds: Set<String> = []
    public var didLoadComments = false
    public var didLoadAgentRuns = false
    public var didLoadActiveTasks = false
    public var didLoadTimeline = false
    public var didLoadUsage = false
    public var didLoadSubscribers = false
    public var didLoadIssueRelations = false
    public var error: String?
    public var commentsError: String?
    public var agentRunsError: String?
    public var activeTasksError: String?
    public var timelineError: String?
    public var usageError: String?
    public var subscribersError: String?
    public var issueRelationsError: String?
    public var metadataError: String?
    public var deleteIssueError: String?
    public var didDeleteIssue = false
    public var assigneeDisplayName: String?
    public var projectDisplayName: String?
    public var isUpdatingIssue = false

    private let api: APIClient

    private var effectiveWorkspaceId: String? {
        workspaceId ?? issue?.workspaceId
    }

    public init(issueId: String, workspaceId: String? = nil, api: APIClient) {
        self.issueId = issueId
        self.workspaceId = workspaceId
        self.api = api
    }

    public var canSubmitComment: Bool {
        !commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmittingComment &&
        !isUploadingCommentAttachment
    }

    public var childProgressText: String {
        "\(doneCount(in: childIssues))/\(childIssues.count)"
    }

    public var parentChildProgressText: String {
        "\(doneCount(in: parentSiblingIssues))/\(parentSiblingIssues.count)"
    }

    public var timelineActivities: [TimelineEntry] {
        timelineEntries.filter { $0.type == .activity }
    }

    public var usageSummaryText: String {
        guard let usage else { return "No usage recorded" }
        let taskUnit = usage.taskCount == 1 ? "task" : "tasks"
        return "\(formatTokenCount(usage.totalTokens)) tokens across \(usage.taskCount) \(taskUnit)"
    }

    public func loadInitialData() async {
        await loadIssueAndMetadata()
        guard issue != nil, error == nil else { return }
        async let comments: Void = loadComments()
        async let agentRuns: Void = loadAgentRuns()
        async let activeTasks: Void = loadActiveTasks()
        async let timeline: Void = loadTimeline()
        async let usage: Void = loadUsage()
        async let subscribers: Void = loadSubscribers()
        _ = await (comments, agentRuns, activeTasks, timeline, usage, subscribers)
    }

    public func loadIssue() async {
        isLoadingIssue = true
        error = nil
        defer { isLoadingIssue = false }
        do {
            issue = try await api.getIssue(id: issueId, workspaceId: effectiveWorkspaceId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func loadIssueAndMetadata() async {
        await loadIssue()
        guard issue != nil, error == nil else { return }
        async let metadata: Void = loadMetadata()
        async let relations: Void = loadIssueRelations()
        _ = await (metadata, relations)
    }

    public func loadIssueRelations() async {
        guard let issue else { return }
        isLoadingIssueRelations = true
        issueRelationsError = nil
        defer { isLoadingIssueRelations = false }

        do {
            let workspaceId = effectiveWorkspaceId
            childIssues = try await api.listChildIssues(issueId: issue.id, workspaceId: workspaceId)
            if let parentIssueId = issue.parentIssueId {
                parentIssue = try await api.getIssue(id: parentIssueId, workspaceId: workspaceId)
                parentSiblingIssues = try await api.listChildIssues(issueId: parentIssueId, workspaceId: workspaceId)
            } else {
                parentIssue = nil
                parentSiblingIssues = []
            }
            didLoadIssueRelations = true
        } catch {
            childIssues = []
            parentIssue = nil
            parentSiblingIssues = []
            didLoadIssueRelations = true
            issueRelationsError = error.localizedDescription
        }
    }

    public func loadMetadata() async {
        guard let issue, let workspaceId = effectiveWorkspaceId else { return }
        metadataError = nil
        assigneeDisplayName = nil
        projectDisplayName = nil

        do {
            async let members = api.listMembers(workspaceId: workspaceId)
            async let agents = api.listAgents(workspaceId: workspaceId)
            async let projectsPage = api.listProjects(workspaceId: workspaceId, limit: 50, offset: 0)

            let loadedMembers = try await members
            let loadedAgents = try await agents
            let loadedProjects = try await projectsPage
            subscriberMembers = loadedMembers
            subscriberAgents = loadedAgents.filter { $0.archivedAt == nil }

            if let assigneeId = issue.assigneeId, let assigneeType = issue.assigneeType {
                switch assigneeType {
                case "member":
                    assigneeDisplayName = loadedMembers.first { $0.userId == assigneeId || $0.id == assigneeId }?.name
                case "agent":
                    assigneeDisplayName = loadedAgents.first { $0.id == assigneeId }?.name
                default:
                    assigneeDisplayName = nil
                }
            }

            if let projectId = issue.projectId {
                if let project = loadedProjects.items.first(where: { $0.id == projectId }) {
                    projectDisplayName = project.name
                } else {
                    projectDisplayName = try await api.getProject(id: projectId, workspaceId: workspaceId).name
                }
            }
        } catch {
            metadataError = error.localizedDescription
        }
    }

    public func loadSubscribers() async {
        isLoadingSubscribers = true
        subscribersError = nil
        defer { isLoadingSubscribers = false }
        do {
            subscribers = try await api.listIssueSubscribers(issueId: issueId, workspaceId: effectiveWorkspaceId)
            didLoadSubscribers = true
        } catch {
            subscribers = []
            didLoadSubscribers = true
            subscribersError = error.localizedDescription
        }
    }

    public func isSubscribed(userId: String, userType: String) -> Bool {
        subscribers.contains { $0.userId == userId && $0.userType == userType }
    }

    public func displayName(for subscriber: IssueSubscriber) -> String {
        switch subscriber.userType {
        case "member":
            return subscriberMembers.first { $0.userId == subscriber.userId || $0.id == subscriber.userId }?.name
                ?? "Member \(subscriber.userId.prefix(8))"
        case "agent":
            return subscriberAgents.first { $0.id == subscriber.userId }?.name
                ?? "Agent \(subscriber.userId.prefix(8))"
        default:
            return "\(subscriber.userType.capitalized) \(subscriber.userId.prefix(8))"
        }
    }

    public func toggleSubscriber(userId: String, userType: String) async {
        guard !isLoadingSubscribers else { return }
        isLoadingSubscribers = true
        subscribersError = nil
        let currentlySubscribed = isSubscribed(userId: userId, userType: userType)
        do {
            let workspaceId = effectiveWorkspaceId
            if currentlySubscribed {
                try await api.unsubscribeFromIssue(issueId: issueId, userId: userId, userType: userType, workspaceId: workspaceId)
            } else {
                try await api.subscribeToIssue(issueId: issueId, userId: userId, userType: userType, workspaceId: workspaceId)
            }
            isLoadingSubscribers = false
            await loadSubscribers()
        } catch {
            isLoadingSubscribers = false
            subscribersError = error.localizedDescription
        }
    }

    public func toggleIssueReaction(emoji: String, currentUserId: String?) async {
        guard let currentUserId, let currentIssue = issue else { return }
        error = nil
        let existing = currentIssue.reactions.first {
            $0.emoji == emoji && $0.actorType == "member" && $0.actorId == currentUserId
        }

        do {
            if existing != nil {
                try await api.removeIssueReaction(issueId: issueId, emoji: emoji, workspaceId: effectiveWorkspaceId)
                issue = currentIssue.replacingReactions(
                    currentIssue.reactions.filter {
                        !($0.emoji == emoji && $0.actorType == "member" && $0.actorId == currentUserId)
                    }
                )
            } else {
                let reaction = try await api.addIssueReaction(issueId: issueId, emoji: emoji, workspaceId: effectiveWorkspaceId)
                issue = currentIssue.replacingReactions(currentIssue.reactions + [reaction])
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func toggleCommentReaction(commentId: String, emoji: String, currentUserId: String?) async {
        guard let currentUserId,
              let index = commentLoader.items.firstIndex(where: { $0.id == commentId })
        else { return }
        error = nil
        let comment = commentLoader.items[index]
        let existing = comment.reactions.first {
            $0.emoji == emoji && $0.actorType == "member" && $0.actorId == currentUserId
        }

        do {
            if existing != nil {
                try await api.removeReaction(commentId: commentId, emoji: emoji, workspaceId: effectiveWorkspaceId)
                commentLoader.items[index] = comment.replacingReactions(
                    comment.reactions.filter {
                        !($0.emoji == emoji && $0.actorType == "member" && $0.actorId == currentUserId)
                    }
                )
            } else {
                let reaction = try await api.addReaction(commentId: commentId, emoji: emoji, workspaceId: effectiveWorkspaceId)
                commentLoader.items[index] = comment.replacingReactions(comment.reactions + [reaction])
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func loadComments() async {
        didLoadComments = false
        commentLoader.reset()
        await loadMoreComments()
    }

    public func loadMoreComments() async {
        isLoadingComments = true
        commentsError = nil
        defer { isLoadingComments = false }
        do {
            let workspaceId = effectiveWorkspaceId
            try await commentLoader.loadNext { [api, issueId, workspaceId] offset in
                try await api.listComments(issueId: issueId, workspaceId: workspaceId, limit: 50, offset: offset)
            }
            didLoadComments = true
        } catch {
            commentsError = error.localizedDescription
        }
    }

    public func loadAgentRuns() async {
        isLoadingAgentRuns = true
        agentRunsError = nil
        defer { isLoadingAgentRuns = false }
        do {
            agentRuns = try await api.listAgentRuns(issueId: issueId, workspaceId: effectiveWorkspaceId)
            didLoadAgentRuns = true
        } catch {
            agentRuns = []
            didLoadAgentRuns = true
            agentRunsError = error.localizedDescription
        }
    }

    public func loadActiveTasks() async {
        isLoadingActiveTasks = true
        activeTasksError = nil
        defer { isLoadingActiveTasks = false }
        do {
            activeTasks = try await api.getActiveTasksForIssue(issueId: issueId, workspaceId: effectiveWorkspaceId)
            didLoadActiveTasks = true
        } catch {
            activeTasks = []
            didLoadActiveTasks = true
            activeTasksError = error.localizedDescription
        }
    }

    public func cancelActiveTask(id taskId: String) async {
        guard !cancellingTaskIds.contains(taskId) else { return }
        cancellingTaskIds.insert(taskId)
        activeTasksError = nil
        defer { cancellingTaskIds.remove(taskId) }

        do {
            let cancelled = try await api.cancelTask(issueId: issueId, taskId: taskId, workspaceId: effectiveWorkspaceId)
            activeTasks.removeAll { $0.id == taskId }
            if let index = agentRuns.firstIndex(where: { $0.id == taskId }) {
                agentRuns[index] = cancelled
            } else {
                agentRuns.insert(cancelled, at: 0)
            }
        } catch {
            activeTasksError = error.localizedDescription
        }
    }

    public func loadTimeline() async {
        isLoadingTimeline = true
        timelineError = nil
        defer { isLoadingTimeline = false }
        do {
            timelineEntries = try await api.listTimeline(issueId: issueId, workspaceId: effectiveWorkspaceId)
            didLoadTimeline = true
        } catch {
            timelineEntries = []
            didLoadTimeline = true
            timelineError = error.localizedDescription
        }
    }

    public func loadUsage() async {
        isLoadingUsage = true
        usageError = nil
        defer { isLoadingUsage = false }
        do {
            usage = try await api.getIssueUsage(issueId: issueId, workspaceId: effectiveWorkspaceId)
            didLoadUsage = true
        } catch {
            usage = nil
            didLoadUsage = true
            usageError = error.localizedDescription
        }
    }

    public func deleteIssue() async {
        isDeletingIssue = true
        deleteIssueError = nil
        defer { isDeletingIssue = false }
        do {
            try await api.deleteIssue(id: issueId, workspaceId: effectiveWorkspaceId)
            didDeleteIssue = true
        } catch {
            didDeleteIssue = false
            deleteIssueError = error.localizedDescription
        }
    }

    public func activityText(for entry: TimelineEntry) -> String {
        switch entry.action {
        case "created":
            return "created this issue"
        case "status_changed":
            return "changed status from \(statusLabel(entry.detailString("from"))) to \(statusLabel(entry.detailString("to")))"
        case "priority_changed":
            return "changed priority from \(priorityLabel(entry.detailString("from"))) to \(priorityLabel(entry.detailString("to")))"
        case "assignee_changed":
            if entry.detailString("to_id") == nil, entry.detailString("from_id") != nil {
                return "removed assignee"
            }
            if let toType = entry.detailString("to_type"), let toId = entry.detailString("to_id") {
                return "assigned to \(toType.capitalized) \(toId.prefix(8))"
            }
            return "changed assignee"
        case "due_date_changed":
            guard let dueDate = entry.detailString("to"), !dueDate.isEmpty else {
                return "removed due date"
            }
            return "set due date to \(shortDate(dueDate))"
        case "title_changed":
            return "renamed this issue from \"\(entry.detailString("from") ?? "?")\" to \"\(entry.detailString("to") ?? "?")\""
        case "description_updated":
            return "updated the description"
        case "task_completed":
            return "completed the task"
        case "task_failed":
            return "task failed"
        case .some(let action):
            return action.replacingOccurrences(of: "_", with: " ").capitalized
        case .none:
            return "updated this issue"
        }
    }

    public func timelineActorName(for entry: TimelineEntry) -> String {
        switch entry.actorType {
        case "member":
            return subscriberMembers.first { $0.userId == entry.actorId || $0.id == entry.actorId }?.name
                ?? "Member \(entry.actorId.prefix(8))"
        case "agent":
            return subscriberAgents.first { $0.id == entry.actorId }?.name
                ?? "Agent \(entry.actorId.prefix(8))"
        default:
            return "\(entry.actorType.capitalized) \(entry.actorId.prefix(8))"
        }
    }

    public func submitComment() async {
        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard await submitComment(content: content, parentId: nil) else { return }
        commentDraft = ""
        commentAttachments = []
    }

    public func uploadCommentAttachment(filename: String, data: Data, contentType: String) async -> Bool {
        guard !data.isEmpty else {
            error = "Attachment is empty."
            return false
        }
        guard !isUploadingCommentAttachment else { return false }

        isUploadingCommentAttachment = true
        error = nil
        defer { isUploadingCommentAttachment = false }

        do {
            let attachment = try await api.uploadFile(
                filename: filename,
                data: data,
                contentType: contentType,
                issueId: issueId,
                workspaceId: effectiveWorkspaceId
            )
            commentAttachments.append(attachment)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    public func uploadReplyAttachment(parentId: String, filename: String, data: Data, contentType: String) async -> Bool {
        guard !data.isEmpty else {
            error = "Attachment is empty."
            return false
        }
        guard !uploadingReplyAttachmentIds.contains(parentId) else { return false }

        uploadingReplyAttachmentIds.insert(parentId)
        error = nil
        defer { uploadingReplyAttachmentIds.remove(parentId) }

        do {
            let attachment = try await api.uploadFile(
                filename: filename,
                data: data,
                contentType: contentType,
                issueId: issueId,
                workspaceId: effectiveWorkspaceId
            )
            replyAttachments[parentId, default: []].append(attachment)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    public func submitReply(parentId: String, content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let didSubmit = await submitComment(content: trimmed, parentId: parentId)
        if didSubmit {
            replyAttachments[parentId] = []
        }
        return didSubmit
    }

    public func updateComment(commentId: String, content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        error = nil
        do {
            let updated = try await api.updateComment(commentId: commentId, content: trimmed, workspaceId: effectiveWorkspaceId)
            if let index = commentLoader.items.firstIndex(where: { $0.id == commentId }) {
                commentLoader.items[index] = updated
            }
            await DataStore.shared.invalidateIssue(issueId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    public func deleteComment(commentId: String) async -> Bool {
        error = nil
        do {
            try await api.deleteComment(commentId: commentId, workspaceId: effectiveWorkspaceId)
            let removedIds = descendantCommentIds(of: commentId).union([commentId])
            commentLoader.items.removeAll { removedIds.contains($0.id) }
            await DataStore.shared.invalidateIssue(issueId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func submitComment(content: String, parentId: String?) async -> Bool {
        isSubmittingComment = true; defer { isSubmittingComment = false }
        do {
            let comment = try await api.addComment(
                issueId: issueId,
                content: content,
                parentId: parentId,
                attachmentIds: attachmentIds(forParentId: parentId),
                workspaceId: effectiveWorkspaceId
            )
            commentLoader.items.append(comment)
            await loadIssue()
            await DataStore.shared.invalidateIssue(issueId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func descendantCommentIds(of commentId: String) -> Set<String> {
        var ids = Set<String>()
        var changed = true
        while changed {
            changed = false
            for comment in commentLoader.items {
                guard let parentId = comment.parentId,
                      (parentId == commentId || ids.contains(parentId)),
                      !ids.contains(comment.id)
                else { continue }
                ids.insert(comment.id)
                changed = true
            }
        }
        return ids
    }

    private func attachmentIds(forParentId parentId: String?) -> [String]? {
        let attachments = parentId.flatMap { replyAttachments[$0] } ?? commentAttachments
        return attachments.isEmpty ? nil : attachments.map(\.id)
    }

    public func updateStatus(_ status: IssueStatus) async {
        await updateIssue(status: status, priority: nil)
    }

    public func updatePriority(_ priority: IssuePriority) async {
        await updateIssue(status: nil, priority: priority)
    }

    public func applyUpdatedIssue(_ updated: Issue) async {
        issue = updated
        await DataStore.shared.invalidateIssue(updated.id)
        await loadMetadata()
        await loadIssueRelations()
    }

    private func updateIssue(status: IssueStatus?, priority: IssuePriority?) async {
        guard !isUpdatingIssue else { return }
        isUpdatingIssue = true
        error = nil
        defer { isUpdatingIssue = false }

        do {
            issue = try await api.updateIssue(
                id: issueId,
                workspaceId: effectiveWorkspaceId,
                status: status,
                priority: priority
            )
            await DataStore.shared.invalidateIssue(issueId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func doneCount(in issues: [Issue]) -> Int {
        issues.filter { $0.status == .done }.count
    }

    private func statusLabel(_ raw: String?) -> String {
        guard let raw else { return "?" }
        return IssueStatus(rawValue: raw)?.displayName ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func priorityLabel(_ raw: String?) -> String {
        guard let raw else { return "?" }
        return IssuePriority(rawValue: raw)?.displayName ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func shortDate(_ raw: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatTokenCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
