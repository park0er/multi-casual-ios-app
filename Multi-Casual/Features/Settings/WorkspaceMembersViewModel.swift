import Foundation
import Observation

@Observable
@MainActor
public final class WorkspaceMembersViewModel {
    public static let roles = ["member", "admin", "owner"]

    public var members: [WorkspaceMember] = []
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
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing members."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedMembers = api.listMembers(workspaceId: workspaceId)
            async let loadedInvitations = api.listWorkspaceInvitations(workspaceId: workspaceId)
            members = try await loadedMembers.sorted(by: memberSort)
            invitations = try await loadedInvitations.sorted(by: invitationSort)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func inviteMember(email: String, role: String) async -> Invitation? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing members."
            return nil
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter an email address."
            return nil
        }

        return await mutate {
            let invitation = try await api.createMember(workspaceId: workspaceId, email: trimmedEmail, role: role)
            upsert(invitation)
            return invitation
        }
    }

    public func updateMemberRole(memberId: String, role: String) async -> WorkspaceMember? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing members."
            return nil
        }

        return await mutate {
            let member = try await api.updateMember(workspaceId: workspaceId, memberId: memberId, role: role)
            upsert(member)
            return member
        }
    }

    public func removeMember(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing members."
            return
        }
        await mutateVoid {
            try await api.deleteMember(workspaceId: workspaceId, memberId: id)
            members.removeAll { $0.id == id }
        }
    }

    public func revokeInvitation(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing members."
            return
        }
        await mutateVoid {
            try await api.revokeInvitation(workspaceId: workspaceId, invitationId: id)
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

    private func upsert(_ member: WorkspaceMember) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index] = member
        } else {
            members.append(member)
        }
        members.sort(by: memberSort)
    }

    private func upsert(_ invitation: Invitation) {
        if let index = invitations.firstIndex(where: { $0.id == invitation.id }) {
            invitations[index] = invitation
        } else {
            invitations.append(invitation)
        }
        invitations.sort(by: invitationSort)
    }

    private func memberSort(_ lhs: WorkspaceMember, _ rhs: WorkspaceMember) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func invitationSort(_ lhs: Invitation, _ rhs: Invitation) -> Bool {
        lhs.email.localizedCaseInsensitiveCompare(rhs.email) == .orderedAscending
    }
}
