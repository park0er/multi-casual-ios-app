import Foundation
import Observation

@Observable
@MainActor
public final class WorkspaceAccessViewModel {
    public var invitations: [Invitation] = []
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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            invitations = try await api.listMyInvitations().filter { $0.status == "pending" }
                .sorted(by: invitationSort)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createWorkspace(name: String, slug: String, description: String?, context: String?) async -> Workspace? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Workspace name is required."
            return nil
        }
        guard !trimmedSlug.isEmpty else {
            errorMessage = "Workspace slug is required."
            return nil
        }

        return await mutate {
            let workspace = try await api.createWorkspace(
                name: trimmedName,
                slug: trimmedSlug,
                description: trimmedOptional(description),
                context: trimmedOptional(context)
            )
            upsert(workspace)
            authSession.setWorkspace(workspace)
            return workspace
        }
    }

    public func leaveWorkspace(id: String) async {
        await mutateVoid {
            try await api.leaveWorkspace(id: id)
            authSession.removeWorkspace(id: id)
        }
    }

    public func deleteWorkspace(id: String) async {
        await mutateVoid {
            try await api.deleteWorkspace(id: id)
            authSession.removeWorkspace(id: id)
        }
    }

    public func acceptInvitation(id: String) async -> WorkspaceMember? {
        await mutate {
            let member = try await api.acceptInvitation(id: id)
            invitations.removeAll { $0.id == id }
            let workspaces = try await api.listWorkspaces()
            authSession.replaceWorkspaces(workspaces, preferredId: member.workspaceId)
            return member
        }
    }

    public func declineInvitation(id: String) async {
        await mutateVoid {
            try await api.declineInvitation(id: id)
            invitations.removeAll { $0.id == id }
        }
    }

    private func mutate<T>(_ operation: () async throws -> T) async -> T? {
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            return try await operation()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func mutateVoid(_ operation: () async throws -> Void) async {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsert(_ workspace: Workspace) {
        if let index = authSession.workspaces.firstIndex(where: { $0.id == workspace.id }) {
            authSession.workspaces[index] = workspace
        } else {
            authSession.workspaces.append(workspace)
        }
    }

    private func trimmedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func invitationSort(_ lhs: Invitation, _ rhs: Invitation) -> Bool {
        (lhs.workspaceName ?? lhs.email).localizedCaseInsensitiveCompare(rhs.workspaceName ?? rhs.email) == .orderedAscending
    }
}
