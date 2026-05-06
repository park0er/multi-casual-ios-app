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
    public var subscribers: [IssueSubscriber] = []
    public var subscriberMembers: [WorkspaceMember] = []
    public var subscriberAgents: [Agent] = []
    public let commentLoader = PaginatedLoader<Comment>()
    public var commentDraft = ""
    public var isSubmittingComment = false
    public var isLoadingIssue = false
    public var isLoadingComments = false
    public var isLoadingAgentRuns = false
    public var isLoadingSubscribers = false
    public var isLoadingIssueRelations = false
    public var didLoadComments = false
    public var didLoadAgentRuns = false
    public var didLoadSubscribers = false
    public var didLoadIssueRelations = false
    public var error: String?
    public var commentsError: String?
    public var agentRunsError: String?
    public var subscribersError: String?
    public var issueRelationsError: String?
    public var metadataError: String?
    public var assigneeDisplayName: String?
    public var projectDisplayName: String?
    public var isUpdatingIssue = false

    private let api: APIClient

    public init(issueId: String, workspaceId: String? = nil, api: APIClient) {
        self.issueId = issueId
        self.workspaceId = workspaceId
        self.api = api
    }

    public var canSubmitComment: Bool {
        !commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmittingComment
    }

    public var childProgressText: String {
        "\(doneCount(in: childIssues))/\(childIssues.count)"
    }

    public var parentChildProgressText: String {
        "\(doneCount(in: parentSiblingIssues))/\(parentSiblingIssues.count)"
    }

    public func loadInitialData() async {
        async let issueAndMetadata: Void = loadIssueAndMetadata()
        async let comments: Void = loadComments()
        async let agentRuns: Void = loadAgentRuns()
        async let subscribers: Void = loadSubscribers()
        _ = await (issueAndMetadata, comments, agentRuns, subscribers)
    }

    public func loadIssue() async {
        isLoadingIssue = true
        error = nil
        defer { isLoadingIssue = false }
        do {
            issue = try await api.getIssue(id: issueId, workspaceId: workspaceId)
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
            childIssues = try await api.listChildIssues(issueId: issue.id)
            if let parentIssueId = issue.parentIssueId {
                parentIssue = try await api.getIssue(id: parentIssueId, workspaceId: workspaceId)
                parentSiblingIssues = try await api.listChildIssues(issueId: parentIssueId)
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
        guard let issue, let workspaceId else { return }
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
            subscribers = try await api.listIssueSubscribers(issueId: issueId)
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
            if currentlySubscribed {
                try await api.unsubscribeFromIssue(issueId: issueId, userId: userId, userType: userType)
            } else {
                try await api.subscribeToIssue(issueId: issueId, userId: userId, userType: userType)
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
                try await api.removeIssueReaction(issueId: issueId, emoji: emoji)
                issue = currentIssue.replacingReactions(
                    currentIssue.reactions.filter {
                        !($0.emoji == emoji && $0.actorType == "member" && $0.actorId == currentUserId)
                    }
                )
            } else {
                let reaction = try await api.addIssueReaction(issueId: issueId, emoji: emoji)
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
                try await api.removeReaction(commentId: commentId, emoji: emoji)
                commentLoader.items[index] = comment.replacingReactions(
                    comment.reactions.filter {
                        !($0.emoji == emoji && $0.actorType == "member" && $0.actorId == currentUserId)
                    }
                )
            } else {
                let reaction = try await api.addReaction(commentId: commentId, emoji: emoji)
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
            agentRuns = try await api.listAgentRuns(issueId: issueId, workspaceId: workspaceId)
            didLoadAgentRuns = true
        } catch {
            agentRuns = []
            didLoadAgentRuns = true
            agentRunsError = error.localizedDescription
        }
    }

    public func submitComment() async {
        let content = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard await submitComment(content: content, parentId: nil) else { return }
        commentDraft = ""
    }

    public func submitReply(parentId: String, content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return await submitComment(content: trimmed, parentId: parentId)
    }

    public func updateComment(commentId: String, content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        error = nil
        do {
            let updated = try await api.updateComment(commentId: commentId, content: trimmed)
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
            try await api.deleteComment(commentId: commentId)
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
            let comment = try await api.addComment(issueId: issueId, content: content, parentId: parentId, workspaceId: workspaceId)
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
                workspaceId: workspaceId,
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
}
