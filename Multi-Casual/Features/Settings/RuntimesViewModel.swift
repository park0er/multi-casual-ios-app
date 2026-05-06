import Foundation
import Observation

@Observable
@MainActor
public final class RuntimesViewModel {
    public var runtimes: [AgentRuntime] = []
    public var isLoading = false
    public var isMutating = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func load() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing runtimes."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            runtimes = try await api.listRuntimes(workspaceId: workspaceId)
                .sorted { lhs, rhs in
                    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteRuntime(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing runtimes."
            return
        }
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            try await api.deleteRuntime(id: id, workspaceId: workspaceId)
            runtimes.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
