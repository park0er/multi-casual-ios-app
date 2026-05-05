import Foundation
import Observation

@Observable
@MainActor
public final class IssueListViewModel {
    public enum ViewMode { case list, board }
    public let loader = PaginatedLoader<Issue>()
    public var viewMode: ViewMode = .list
    public var showCreateSheet = false
    public var lastError: Error?
    public private(set) var issuesByStatus: [IssueStatus: [Issue]] = [:]

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api; self.authSession = authSession
    }

    public func loadNext() async {
        guard let wsId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before opening Issues.")
            return
        }
        do {
            try await loader.loadNext { [api, wsId] offset in
                try await api.listIssues(workspaceId: wsId, limit: 50, offset: offset)
            }
            issuesByStatus = Dictionary(grouping: loader.items, by: \.status)
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func refresh() async { loader.reset(); await loadNext() }
}
