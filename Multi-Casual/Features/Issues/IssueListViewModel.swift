#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import Observation

@Observable
@MainActor
public final class IssueListViewModel {
    public enum ViewMode { case list, board }
    public let loader = PaginatedLoader<Issue>()
    public var viewMode: ViewMode = .list
    public var showCreateSheet = false

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api; self.authSession = authSession
    }

    public func loadNext() async {
        guard let wsId = authSession.currentWorkspace?.id else { return }
        await loader.loadNext { [api, wsId] offset in
            try await api.listIssues(workspaceId: wsId, limit: 50, offset: offset)
        }
    }

    public func refresh() async { loader.reset(); await loadNext() }

    public var issuesByStatus: [IssueStatus: [Issue]] {
        Dictionary(grouping: loader.items, by: \.status)
    }
}
#endif
