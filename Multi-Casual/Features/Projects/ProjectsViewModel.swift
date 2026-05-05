import Foundation
import Observation

@Observable
@MainActor
public final class ProjectsViewModel {
    public let loader = PaginatedLoader<Project>()
    public var lastError: Error?
    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api; self.authSession = authSession
    }

    public func loadNext() async {
        guard let wsId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before opening Projects.")
            return
        }
        do {
            try await loader.loadNext { [api, wsId] offset in
                try await api.listProjects(workspaceId: wsId, limit: 50, offset: offset)
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func refresh() async { loader.reset(); await loadNext() }
}
