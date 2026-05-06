import Foundation
import Observation

@Observable
@MainActor
public final class IssueEditViewModel {
    public static let noAssigneeId = "none"
    public static let noProjectId = "none"

    public let issueId: String
    public var title: String
    public var description: String
    public var status: IssueStatus
    public var priority: IssuePriority
    public var selectedAssigneeOptionId: String
    public var selectedProjectId: String
    public var includesDueDate: Bool
    public var dueDate: Date
    public var assigneeOptions: [IssueAssigneeOption] = []
    public var projects: [Project] = []
    public var isLoadingOptions = false
    public var isSubmitting = false
    public var errorMessage: String?

    private let workspaceId: String?
    private let api: APIClient
    private let dateFormatter: ISO8601DateFormatter

    public init(issue: Issue, api: APIClient, authSession: AuthSession) {
        issueId = issue.id
        workspaceId = authSession.currentWorkspace?.id ?? issue.workspaceId
        title = issue.title
        description = issue.description ?? ""
        status = issue.status
        priority = issue.priority
        selectedAssigneeOptionId = issue.assigneeType.flatMap { type in
            issue.assigneeId.map { "\(type):\($0)" }
        } ?? Self.noAssigneeId
        selectedProjectId = issue.projectId ?? Self.noProjectId

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        dateFormatter = formatter
        if let dueDateRaw = issue.dueDate, let parsedDueDate = formatter.date(from: dueDateRaw) {
            includesDueDate = true
            dueDate = parsedDueDate
        } else {
            includesDueDate = false
            dueDate = Date()
        }
        self.api = api
    }

    public var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    public var statusOptions: [IssueStatus] {
        IssueStatus.allCases.filter { $0 != .unknown }
    }

    public var priorityOptions: [IssuePriority] {
        IssuePriority.allCases.filter { $0 != .unknown }
    }

    public var selectedAssignee: IssueAssigneeOption? {
        assigneeOptions.first { $0.id == selectedAssigneeOptionId }
    }

    public var selectedProject: Project? {
        projects.first { $0.id == selectedProjectId }
    }

    public func loadOptions() async {
        guard let workspaceId else {
            errorMessage = "Pick a workspace before editing an issue."
            return
        }

        isLoadingOptions = true
        errorMessage = nil
        defer { isLoadingOptions = false }

        do {
            async let members = api.listMembers(workspaceId: workspaceId)
            async let agents = api.listAgents(workspaceId: workspaceId)

            let loadedMembers = try await members
            let loadedAgents = try await agents
            let loadedProjects = try await loadAllProjects(workspaceId: workspaceId)

            assigneeOptions = loadedMembers.map {
                IssueAssigneeOption(
                    id: "member:\($0.userId)",
                    type: "member",
                    assigneeId: $0.userId,
                    displayName: $0.name,
                    subtitle: $0.email
                )
            } + loadedAgents.map {
                IssueAssigneeOption(
                    id: "agent:\($0.id)",
                    type: "agent",
                    assigneeId: $0.id,
                    displayName: $0.name,
                    subtitle: "Agent"
                )
            }
            projects = loadedProjects

            if selectedAssigneeOptionId != Self.noAssigneeId && selectedAssignee == nil {
                selectedAssigneeOptionId = Self.noAssigneeId
            }
            if selectedProjectId != Self.noProjectId && selectedProject == nil {
                selectedProjectId = Self.noProjectId
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func submit() async -> Issue? {
        guard let workspaceId else {
            errorMessage = "Pick a workspace before editing an issue."
            return nil
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let assignee = selectedAssignee

        do {
            return try await api.updateIssueDetails(
                id: issueId,
                workspaceId: workspaceId,
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                status: status,
                priority: priority,
                assigneeType: assignee?.type,
                assigneeId: assignee?.assigneeId,
                projectId: selectedProject?.id,
                dueDate: includesDueDate ? dateFormatter.string(from: dueDate) : nil
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func loadAllProjects(workspaceId: String) async throws -> [Project] {
        let limit = 50
        var offset = 0
        var allProjects: [Project] = []

        while true {
            let page = try await api.listProjects(workspaceId: workspaceId, limit: limit, offset: offset)
            allProjects.append(contentsOf: page.items)
            offset += page.items.count

            let shouldContinue: Bool
            if let total = page.total {
                shouldContinue = offset < total
            } else {
                shouldContinue = page.hasMore
            }
            guard shouldContinue, !page.items.isEmpty else { break }
        }

        return allProjects
    }
}
