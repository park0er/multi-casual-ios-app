import Foundation
import Observation

@Observable
@MainActor
public final class WorkspaceSettingsViewModel {
    public var name = ""
    public var description = ""
    public var context = ""
    public var repoText = ""
    public var isLoading = false
    public var isSaving = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
        if let workspace = authSession.currentWorkspace {
            apply(workspace)
        }
    }

    public func load() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before editing workspace settings."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let workspace = try await api.getWorkspace(id: workspaceId, workspaceId: workspaceId)
            replaceWorkspace(workspace)
            apply(workspace)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save() async -> Workspace? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before editing workspace settings."
            return nil
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Workspace name is required."
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let workspace = try await api.updateWorkspace(
                id: workspaceId,
                workspaceId: workspaceId,
                name: trimmedName,
                description: trimmedOptional(description),
                context: trimmedOptional(context),
                repos: parsedRepos()
            )
            replaceWorkspace(workspace)
            apply(workspace)
            return workspace
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func apply(_ workspace: Workspace) {
        name = workspace.name
        description = workspace.description ?? ""
        context = workspace.context ?? ""
        repoText = workspace.repos.map(\.url).joined(separator: "\n")
    }

    private func replaceWorkspace(_ workspace: Workspace) {
        if let index = authSession.workspaces.firstIndex(where: { $0.id == workspace.id }) {
            authSession.workspaces[index] = workspace
        } else {
            authSession.workspaces.append(workspace)
        }
        if authSession.currentWorkspace?.id == workspace.id {
            authSession.setWorkspace(workspace)
        }
    }

    private func parsedRepos() -> [WorkspaceRepo] {
        repoText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { WorkspaceRepo(url: $0) }
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
