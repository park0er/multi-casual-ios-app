import Foundation
import Observation

@Observable
@MainActor
public final class ProjectDetailViewModel {
    public let project: Project
    public var issues: [Issue] = []
    public var resources: [ProjectResource] = []
    public var isLoading = false
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

    public func load() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before opening project details."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var messages: [String] = []

        do {
            let page = try await api.listIssues(workspaceId: workspaceId, limit: 200, offset: 0)
            issues = page.items.filter { $0.projectId == project.id }
        } catch {
            messages.append(error.localizedDescription)
        }

        do {
            let page = try await api.listProjectResources(projectId: project.id)
            resources = page.items.sorted { $0.position < $1.position }
        } catch {
            messages.append(error.localizedDescription)
        }

        errorMessage = messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}
