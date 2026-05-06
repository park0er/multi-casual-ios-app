import Foundation
import Observation

@Observable
@MainActor
public final class IssueDetailViewModel {
    public let issueId: String
    public let workspaceId: String?
    public var issue: Issue?
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
    public var didLoadComments = false
    public var didLoadAgentRuns = false
    public var didLoadSubscribers = false
    public var error: String?
    public var commentsError: String?
    public var agentRunsError: String?
    public var subscribersError: String?
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
        await loadMetadata()
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
        isSubmittingComment = true; defer { isSubmittingComment = false }
        do {
            let comment = try await api.addComment(issueId: issueId, content: content, workspaceId: workspaceId)
            commentDraft = ""
            commentLoader.items.append(comment)
            await loadIssue()
            await DataStore.shared.invalidateIssue(issueId)
        } catch { self.error = error.localizedDescription }
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
}
