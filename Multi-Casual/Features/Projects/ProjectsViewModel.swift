import Foundation
import Observation

@Observable
@MainActor
public final class ProjectsViewModel {
    public let loader = PaginatedLoader<Project>()
    public var lastError: Error?
    public var isMutating = false
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

    public func createProject(
        title: String,
        description: String?,
        status: ProjectStatus,
        priority: IssuePriority
    ) async -> Project? {
        guard let wsId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before creating a project.")
            return nil
        }
        return await mutate {
            try await api.createProject(
                title: title,
                description: description,
                workspaceId: wsId,
                status: status,
                priority: priority
            )
        }
    }

    public func updateProject(
        id: String,
        title: String,
        description: String?,
        status: ProjectStatus,
        priority: IssuePriority
    ) async -> Project? {
        guard let wsId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before editing a project.")
            return nil
        }
        return await mutate {
            try await api.updateProject(
                id: id,
                workspaceId: wsId,
                title: title,
                description: description,
                status: status,
                priority: priority
            )
        }
    }

    public func deleteProject(id: String) async {
        guard !isMutating else { return }
        guard let wsId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before deleting a project.")
            return
        }
        isMutating = true
        lastError = nil
        defer { isMutating = false }

        do {
            try await api.deleteProject(id: id, workspaceId: wsId)
            loader.items.removeAll { $0.id == id }
        } catch {
            lastError = error
        }
    }

    private func mutate(_ operation: () async throws -> Project) async -> Project? {
        guard !isMutating else { return nil }
        isMutating = true
        lastError = nil
        defer { isMutating = false }

        do {
            let project = try await operation()
            upsert(project)
            return project
        } catch {
            lastError = error
            return nil
        }
    }

    private func upsert(_ project: Project) {
        if let index = loader.items.firstIndex(where: { $0.id == project.id }) {
            loader.items[index] = project
        } else {
            loader.items.append(project)
        }
        loader.items.sort { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
