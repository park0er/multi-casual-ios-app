#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import Observation

@Observable
@MainActor
public final class IssueDetailViewModel {
    public let issueId: String
    public var issue: Issue?
    public var agentRuns: [AgentTask] = []
    public let commentLoader = PaginatedLoader<Comment>()
    public var commentDraft = ""
    public var isSubmittingComment = false
    public var error: String?

    private let api: APIClient

    public init(issueId: String, api: APIClient) {
        self.issueId = issueId; self.api = api
    }

    public func loadIssue() async {
        do { issue = try await api.getIssue(id: issueId) }
        catch { self.error = error.localizedDescription }
    }

    public func loadComments() async {
        commentLoader.reset()
        await loadMoreComments()
    }

    public func loadMoreComments() async {
        do {
            try await commentLoader.loadNext { [api, issueId] offset in
                try await api.listComments(issueId: issueId, limit: 50, offset: offset)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func loadAgentRuns() async {
        agentRuns = (try? await api.listAgentRuns(issueId: issueId)) ?? []
    }

    public func submitComment() async {
        guard !commentDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSubmittingComment = true; defer { isSubmittingComment = false }
        do {
            let comment = try await api.addComment(issueId: issueId, content: commentDraft)
            commentDraft = ""
            commentLoader.items.append(comment)
            await DataStore.shared.invalidateIssue(issueId)
        } catch { self.error = error.localizedDescription }
    }
}
#endif
