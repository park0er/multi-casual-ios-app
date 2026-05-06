import Foundation
import Observation

@Observable
@MainActor
public final class ProjectDetailViewModel {
    public let project: Project
    public var issues: [Issue] = []
    public var resources: [ProjectResource] = []
    public var isLoading = false
    public var isMutatingResource = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(project: Project, api: APIClient, authSession: AuthSession) {
        self.project = project
        self.api = api
        self.authSession = authSession
    }

    public var progressText: String {
        "\(project.doneCount)/\(project.issueCount) done"
    }

    private static let pageSize = 50

    public func load() async {
        guard let workspaceId = currentProjectWorkspaceId(
            action: "view it",
            missingMessage: "Pick a workspace before opening project details."
        ) else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var messages: [String] = []

        do {
            issues = try await loadProjectIssues(workspaceId: workspaceId)
        } catch {
            messages.append(error.localizedDescription)
        }

        do {
            let page = try await api.listProjectResources(projectId: project.id, workspaceId: workspaceId)
            resources = page.items.sorted { $0.position < $1.position }
        } catch {
            messages.append(error.localizedDescription)
        }

        errorMessage = messages.isEmpty ? nil : messages.joined(separator: "\n")
    }

    private func loadProjectIssues(workspaceId: String) async throws -> [Issue] {
        var loaded: [Issue] = []
        for status in IssueStatus.boardCases {
            var statusItems: [Issue] = []
            var rawLoaded = 0
            var hasMore = true
            while hasMore {
                let page = try await api.listIssues(
                    workspaceId: workspaceId,
                    status: status,
                    projectId: project.id,
                    limit: Self.pageSize,
                    offset: rawLoaded
                )
                rawLoaded += page.items.count
                statusItems.append(contentsOf: page.items.filter { $0.projectId == project.id && $0.status == status })
                if let total = page.total {
                    hasMore = rawLoaded < total
                } else {
                    hasMore = page.hasMore
                }
                if page.items.isEmpty {
                    hasMore = false
                }
            }
            loaded.append(contentsOf: statusItems)
        }
        return loaded
    }

    public func attachGitHubResource(url: String) async {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let workspaceId = currentProjectWorkspaceId(
            action: "edit its resources",
            missingMessage: "Pick a workspace before editing project resources."
        ) else { return }

        isMutatingResource = true
        errorMessage = nil
        defer { isMutatingResource = false }

        do {
            let resource = try await api.createProjectResource(
                projectId: project.id,
                workspaceId: workspaceId,
                resourceType: "github_repo",
                resourceRef: ["url": .string(trimmed)]
            )
            upsertResource(resource)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func removeResource(id: String) async {
        guard let workspaceId = currentProjectWorkspaceId(
            action: "edit its resources",
            missingMessage: "Pick a workspace before editing project resources."
        ) else { return }

        isMutatingResource = true
        errorMessage = nil
        defer { isMutatingResource = false }

        do {
            try await api.deleteProjectResource(projectId: project.id, resourceId: id, workspaceId: workspaceId)
            resources.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsertResource(_ resource: ProjectResource) {
        if let index = resources.firstIndex(where: { $0.id == resource.id }) {
            resources[index] = resource
        } else {
            resources.append(resource)
        }
        resources.sort { $0.position < $1.position }
    }

    private func currentProjectWorkspaceId(action: String, missingMessage: String) -> String? {
        guard let currentWorkspace = authSession.currentWorkspace else {
            errorMessage = missingMessage
            return nil
        }
        guard currentWorkspace.id == project.workspaceId else {
            errorMessage = "This project belongs to another workspace. Switch back to \(projectWorkspaceName) to \(action)."
            return nil
        }
        return currentWorkspace.id
    }

    private var projectWorkspaceName: String {
        authSession.workspaces.first { $0.id == project.workspaceId }?.name ?? "its workspace"
    }
}
