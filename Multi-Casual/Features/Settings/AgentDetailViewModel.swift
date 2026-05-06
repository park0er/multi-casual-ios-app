import Foundation
import Observation

@Observable
@MainActor
public final class AgentDetailViewModel {
    public let agent: Agent
    public var ownerName: String?
    public var runtimeName: String?
    public var tasks: [AgentTask] = []
    public var activitySummary: AgentActivitySummary = .empty
    public var activityErrorMessage: String?
    public var isLoading = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(agent: Agent, api: APIClient, authSession: AuthSession) {
        self.agent = agent
        self.api = api
        self.authSession = authSession
    }

    public var activeTasks: [AgentTask] {
        tasks
            .filter { ["queued", "dispatched", "running"].contains($0.status) }
            .sorted(by: taskRecencySort)
    }

    public var recentTasks: [AgentTask] {
        tasks
            .filter { ["completed", "failed", "cancelled"].contains($0.status) }
            .sorted(by: taskRecencySort)
    }

    public func load() async {
        let workspaceId = authSession.currentWorkspace?.id ?? agent.workspaceId
        guard !workspaceId.isEmpty else {
            errorMessage = "Pick a workspace before viewing agent details."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let members = api.listMembers(workspaceId: workspaceId)
            async let runtimes = api.listRuntimes(workspaceId: workspaceId)
            async let agentTasks = api.listAgentTasks(agentId: agent.id, workspaceId: workspaceId)
            async let activityBuckets = api.getWorkspaceAgentActivity30d(workspaceId: workspaceId)

            let loadedMembers = try await members
            let loadedRuntimes = try await runtimes
            let loadedTasks = try await agentTasks

            ownerName = agent.ownerId.flatMap { ownerId in
                loadedMembers.first { $0.userId == ownerId }?.name
            }
            runtimeName = loadedRuntimes.first { $0.id == agent.runtimeId }?.name
            tasks = loadedTasks
            do {
                let loadedActivityBuckets = try await activityBuckets
                activitySummary = AgentActivitySummary.summarize(
                    loadedActivityBuckets,
                    agentId: agent.id,
                    tasks: loadedTasks
                )
                activityErrorMessage = nil
            } catch {
                activitySummary = .empty
                activityErrorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func taskRecencySort(_ lhs: AgentTask, _ rhs: AgentTask) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.startedAt ?? .distantPast
        let rhsDate = rhs.completedAt ?? rhs.startedAt ?? .distantPast
        return lhsDate > rhsDate
    }
}
