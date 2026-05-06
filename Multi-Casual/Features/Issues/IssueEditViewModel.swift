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
    public var selectedLabelIds: Set<String>
    public var includesDueDate: Bool
    public var dueDate: Date
    public var assigneeOptions: [IssueAssigneeOption] = []
    public var projects: [Project] = []
    public var labels: [IssueLabel] = []
    public var isLoadingOptions = false
    public var isSubmitting = false
    public var errorMessage: String?

    private let workspaceId: String?
    private let api: APIClient
    private let dateFormatter: ISO8601DateFormatter
    private let originalLabelIds: Set<String>

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
        selectedLabelIds = Set(issue.labels.map(\.id))
        labels = issue.labels
        originalLabelIds = Set(issue.labels.map(\.id))

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

        async let membersResult = optionResult { try await api.listMembers(workspaceId: workspaceId) }
        async let agentsResult = optionResult { try await api.listAgents(workspaceId: workspaceId) }
        async let projectsResult = optionResult { try await loadAllProjects(workspaceId: workspaceId) }
        async let labelsResult = optionResult {
            let response = try await api.listLabels()
            return response.labels
        }

        let members = await membersResult
        let agents = await agentsResult
        let loadedProjects = await projectsResult
        let loadedLabels = await labelsResult

        var didFail = false
        switch members {
        case .success(let loadedMembers):
            assigneeOptions = loadedMembers.map {
                IssueAssigneeOption(
                    id: "member:\($0.userId)",
                    type: "member",
                    assigneeId: $0.userId,
                    displayName: $0.name,
                    subtitle: $0.email
                )
            }
        case .failure:
            didFail = true
            assigneeOptions = []
        }

        switch agents {
        case .success(let loadedAgents):
            assigneeOptions += loadedAgents.map {
                IssueAssigneeOption(
                    id: "agent:\($0.id)",
                    type: "agent",
                    assigneeId: $0.id,
                    displayName: $0.name,
                    subtitle: "Agent"
                )
            }
        case .failure:
            didFail = true
        }

        switch loadedProjects {
        case .success(let loadedProjects):
            projects = loadedProjects
        case .failure:
            didFail = true
            projects = []
        }

        switch loadedLabels {
        case .success(let loadedLabels):
            labels = mergeLabels(issueLabels: labels, workspaceLabels: loadedLabels)
        case .failure:
            didFail = true
        }

        if case .success = members, case .success = agents,
           selectedAssigneeOptionId != Self.noAssigneeId && selectedAssignee == nil {
            selectedAssigneeOptionId = Self.noAssigneeId
        }
        if case .success = loadedProjects,
           selectedProjectId != Self.noProjectId && selectedProject == nil {
            selectedProjectId = Self.noProjectId
        }

        if didFail {
            errorMessage = "Some workspace options could not be loaded."
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
            let updated = try await api.updateIssueDetails(
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
            let syncedLabels = try await syncLabels()
            return updated.replacingLabels(syncedLabels ?? updated.labels)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func toggleLabel(_ label: IssueLabel, isSelected: Bool) {
        if isSelected {
            selectedLabelIds.insert(label.id)
        } else {
            selectedLabelIds.remove(label.id)
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

    private func optionResult<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func syncLabels() async throws -> [IssueLabel]? {
        let toAttach = selectedLabelIds.subtracting(originalLabelIds).sorted()
        let toDetach = originalLabelIds.subtracting(selectedLabelIds).sorted()
        guard !toAttach.isEmpty || !toDetach.isEmpty else {
            return nil
        }

        var latestLabels: [IssueLabel]?
        for labelId in toAttach {
            latestLabels = try await api.attachLabel(issueId: issueId, labelId: labelId).labels
        }
        for labelId in toDetach {
            latestLabels = try await api.detachLabel(issueId: issueId, labelId: labelId).labels
        }
        return latestLabels
    }

    private func mergeLabels(issueLabels: [IssueLabel], workspaceLabels: [IssueLabel]) -> [IssueLabel] {
        var seen = Set<String>()
        return (issueLabels + workspaceLabels)
            .filter { label in
                if seen.contains(label.id) { return false }
                seen.insert(label.id)
                return true
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
