import Foundation
import Observation

@Observable
@MainActor
public final class ProjectsViewModel {
    public let loader = PaginatedLoader<Project>()
    public var lastError: Error?
    public var isMutating = false
    public var isLoadingProjectOptions = false
    public var searchQuery = ""
    public var projectLeadOptions: [IssueAssigneeOption] = []
    public var workspaceRepoURLs: [String] = []
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
            try await loader.loadNext { [api, wsId, searchQuery] offset in
                if searchQuery.isEmpty {
                    try await api.listProjects(workspaceId: wsId, limit: 50, offset: offset)
                } else {
                    try await api.searchProjects(workspaceId: wsId, query: searchQuery, limit: 50, offset: offset)
                }
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func refresh() async { loader.reset(); await loadNext() }

    public func setSearchQuery(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != searchQuery else { return }
        searchQuery = trimmed
        await refresh()
    }

    public func loadProjectOptions() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before editing projects.")
            return
        }
        guard !isLoadingProjectOptions else { return }
        isLoadingProjectOptions = true
        lastError = nil
        defer { isLoadingProjectOptions = false }

        do {
            workspaceRepoURLs = authSession.currentWorkspace?.repos.map(\.url) ?? []
            async let members = WorkspaceMetadataCache.shared.members(workspaceId: workspaceId, api: api)
            async let agents = WorkspaceMetadataCache.shared.agents(workspaceId: workspaceId, api: api)
            async let squads = WorkspaceMetadataCache.shared.squads(workspaceId: workspaceId, api: api)
            let loadedMembers = try await members
            let loadedAgents = try await agents
            let loadedSquads = try await squads
            projectLeadOptions = loadedMembers.map {
                IssueAssigneeOption(
                    id: "member:\($0.userId)",
                    type: "member",
                    assigneeId: $0.userId,
                    displayName: $0.name,
                    subtitle: $0.email
                )
            } + loadedAgents.filter { $0.archivedAt == nil }.map {
                IssueAssigneeOption(
                    id: "agent:\($0.id)",
                    type: "agent",
                    assigneeId: $0.id,
                    displayName: $0.name,
                    subtitle: "Agent"
                )
            } + loadedSquads.filter { $0.archivedAt == nil }.map {
                IssueAssigneeOption(
                    id: "squad:\($0.id)",
                    type: "squad",
                    assigneeId: $0.id,
                    displayName: $0.name,
                    subtitle: $0.description.isEmpty ? "Squad" : "Squad · \($0.description)"
                )
            }
        } catch {
            projectLeadOptions = []
            lastError = error
        }
    }

    public func createProject(
        title: String,
        description: String?,
        status: ProjectStatus,
        priority: IssuePriority,
        icon: String? = nil,
        leadType: String? = nil,
        leadId: String? = nil,
        resourceURLs: [String] = []
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
                priority: priority,
                icon: normalizedOptional(icon),
                leadType: leadType,
                leadId: leadId,
                resourceURLs: resourceURLs
            )
        }
    }

    public func updateProject(
        id: String,
        title: String,
        description: String?,
        status: ProjectStatus,
        priority: IssuePriority,
        icon: String? = nil,
        leadType: String? = nil,
        leadId: String? = nil
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
                priority: priority,
                icon: normalizedOptional(icon),
                leadType: leadType,
                leadId: leadId
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

    private func normalizedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
