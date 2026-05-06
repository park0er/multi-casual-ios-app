import Foundation
import Observation

@Observable
@MainActor
public final class RuntimeDetailViewModel {
    public let runtime: AgentRuntime
    public var ownerName: String?
    public var servingAgents: [Agent] = []
    public var usageSummary: RuntimeUsageSummary?
    public var activity: [RuntimeHourlyActivity] = []
    public var usageByAgent: [RuntimeUsageByAgent] = []
    public var usageByHour: [RuntimeUsageByHour] = []
    public var modelList: RuntimeModelListRequest?
    public var localSkillList: RuntimeLocalSkillListRequest?
    public var isLoading = false
    public var isRefreshingModels = false
    public var isRefreshingLocalSkills = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(runtime: AgentRuntime, api: APIClient, authSession: AuthSession) {
        self.runtime = runtime
        self.api = api
        self.authSession = authSession
    }

    public var cliVersion: String? {
        stringMetadata("cli_version")
    }

    public var launchedBy: String? {
        stringMetadata("launched_by")
    }

    public func load() async {
        let workspaceId = authSession.currentWorkspace?.id ?? runtime.workspaceId
        guard !workspaceId.isEmpty else {
            errorMessage = "Pick a workspace before viewing runtime details."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let members = api.listMembers(workspaceId: workspaceId)
            async let agents = api.listAgents(workspaceId: workspaceId, includeArchived: true)
            async let usage = api.getRuntimeUsage(id: runtime.id, workspaceId: workspaceId, days: 30)
            async let activity = api.getRuntimeTaskActivity(id: runtime.id, workspaceId: workspaceId)
            async let usageByAgent = api.getRuntimeUsageByAgent(id: runtime.id, workspaceId: workspaceId, days: 30)
            async let usageByHour = api.getRuntimeUsageByHour(id: runtime.id, workspaceId: workspaceId, days: 30)

            let loadedMembers = try await members
            let loadedAgents = try await agents
            let loadedUsage = try await usage
            let loadedActivity = try await activity
            let loadedUsageByAgent = try await usageByAgent
            let loadedUsageByHour = try await usageByHour

            ownerName = runtime.ownerId.flatMap { ownerId in
                loadedMembers.first { $0.userId == ownerId }?.name
            }
            servingAgents = loadedAgents
                .filter { $0.runtimeId == runtime.id }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            usageSummary = RuntimeUsageSummary.summarize(loadedUsage)
            self.activity = loadedActivity.sorted { $0.hour > $1.hour }
            self.usageByAgent = loadedUsageByAgent.sorted { $0.totalTokens > $1.totalTokens }
            self.usageByHour = loadedUsageByHour.sorted { $0.hour > $1.hour }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refreshModels() async {
        guard let workspaceId = resolvedWorkspaceId(action: "refreshing runtime models") else { return }
        isRefreshingModels = true
        errorMessage = nil
        defer { isRefreshingModels = false }

        do {
            modelList = try await api.initiateListRuntimeModels(id: runtime.id, workspaceId: workspaceId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refreshLocalSkills() async {
        guard let workspaceId = resolvedWorkspaceId(action: "refreshing runtime local skills") else { return }
        isRefreshingLocalSkills = true
        errorMessage = nil
        defer { isRefreshingLocalSkills = false }

        do {
            localSkillList = try await api.initiateListRuntimeLocalSkills(id: runtime.id, workspaceId: workspaceId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stringMetadata(_ key: String) -> String? {
        guard let value = runtime.metadata[key]?.displayString,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return value
    }

    private func resolvedWorkspaceId(action: String) -> String? {
        let workspaceId = authSession.currentWorkspace?.id ?? runtime.workspaceId
        guard !workspaceId.isEmpty else {
            errorMessage = "Pick a workspace before \(action)."
            return nil
        }
        return workspaceId
    }
}
