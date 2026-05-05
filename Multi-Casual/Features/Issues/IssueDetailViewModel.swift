import Foundation
import Observation

@Observable
@MainActor
public final class IssueDetailViewModel {
    public let issueId: String
    public let workspaceId: String?
    public var issue: Issue?
    public var agentRuns: [AgentTask] = []
    public let commentLoader = PaginatedLoader<Comment>()
    public var commentDraft = ""
    public var isSubmittingComment = false
    public var isLoadingIssue = false
    public var isLoadingComments = false
    public var isLoadingAgentRuns = false
    public var error: String?
    public var commentsError: String?
    public var agentRunsError: String?
    public var metadataError: String?
    public var assigneeDisplayName: String?
    public var projectDisplayName: String?

    private let api: APIClient

    public init(issueId: String, workspaceId: String? = nil, api: APIClient) {
        self.issueId = issueId
        self.workspaceId = workspaceId
        self.api = api
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
                projectDisplayName = loadedProjects.items.first { $0.id == projectId }?.name
            }
        } catch {
            metadataError = error.localizedDescription
        }
    }

    public func loadComments() async {
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
        } catch {
            agentRuns = []
            agentRunsError = error.localizedDescription
        }
    }

    public func submitComment() async {
        guard !commentDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSubmittingComment = true; defer { isSubmittingComment = false }
        do {
            let comment = try await api.addComment(issueId: issueId, content: commentDraft, workspaceId: workspaceId)
            commentDraft = ""
            commentLoader.items.append(comment)
            await loadIssue()
            await DataStore.shared.invalidateIssue(issueId)
        } catch { self.error = error.localizedDescription }
    }
}
