import Foundation
import Observation

public struct IssueAssigneeOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let type: String
    public let assigneeId: String
    public let displayName: String
    public let subtitle: String

    public init(id: String, type: String, assigneeId: String, displayName: String, subtitle: String) {
        self.id = id
        self.type = type
        self.assigneeId = assigneeId
        self.displayName = displayName
        self.subtitle = subtitle
    }
}

@Observable
@MainActor
public final class IssueCreateViewModel {
    public static let noAssigneeId = "none"
    public static let noProjectId = "none"

    public var title = ""
    public var description = ""
    public var status: IssueStatus = .todo
    public var priority: IssuePriority = .noPriority
    public var selectedAssigneeOptionId = IssueCreateViewModel.noAssigneeId
    public var selectedProjectId = IssueCreateViewModel.noProjectId
    public var includesDueDate = false
    public var dueDate: Date
    public var assigneeOptions: [IssueAssigneeOption] = []
    public var projects: [Project] = []
    public var isLoadingOptions = false
    public var isSubmitting = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession
    private let dateFormatter: ISO8601DateFormatter

    public init(api: APIClient, authSession: AuthSession, now: Date = Date()) {
        self.api = api
        self.authSession = authSession
        self.dueDate = now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        self.dateFormatter = formatter
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
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before creating an issue."
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
            applyDebugCreateDefaults()
        } catch {
            errorMessage = error.localizedDescription
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

    public func submit() async -> Bool {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before creating an issue."
            return false
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let assignee = selectedAssignee
        let projectId = selectedProject?.id

        do {
            _ = try await api.createIssue(
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                workspaceId: workspaceId,
                status: status,
                priority: priority,
                assigneeType: assignee?.type,
                assigneeId: assignee?.assigneeId,
                projectId: projectId,
                dueDate: includesDueDate ? dateFormatter.string(from: dueDate) : nil
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func applyDebugCreateDefaults() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment

        if title.isEmpty, let debugTitle = env["MULTICA_DEBUG_CREATE_TITLE"], !debugTitle.isEmpty {
            title = debugTitle
        }
        if let rawStatus = env["MULTICA_DEBUG_CREATE_STATUS"],
           let debugStatus = IssueStatus(rawValue: rawStatus),
           debugStatus != .unknown {
            status = debugStatus
        }
        if let rawPriority = env["MULTICA_DEBUG_CREATE_PRIORITY"],
           let debugPriority = IssuePriority(rawValue: rawPriority),
           debugPriority != .unknown {
            priority = debugPriority
        }
        if let assigneeOptionId = env["MULTICA_DEBUG_CREATE_ASSIGNEE_OPTION_ID"],
           assigneeOptions.contains(where: { $0.id == assigneeOptionId }) {
            selectedAssigneeOptionId = assigneeOptionId
        }
        if let projectId = env["MULTICA_DEBUG_CREATE_PROJECT_ID"],
           projects.contains(where: { $0.id == projectId }) {
            selectedProjectId = projectId
        }
        if let dueDateRaw = env["MULTICA_DEBUG_CREATE_DUE_DATE"],
           let debugDueDate = dateFormatter.date(from: dueDateRaw) {
            includesDueDate = true
            dueDate = debugDueDate
        }
        #endif
    }
}
