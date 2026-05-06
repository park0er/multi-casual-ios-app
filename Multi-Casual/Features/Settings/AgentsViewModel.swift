import Foundation
import Observation

@Observable
@MainActor
public final class AgentsViewModel {
    public var agents: [Agent] = []
    public var runtimes: [AgentRuntime] = []
    public var skills: [Skill] = []
    public var assignedSkillIdsByAgentId: [String: Set<String>] = [:]
    public var isLoading = false
    public var isMutating = false
    public var errorMessage: String?
    public var lastActionMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func load() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing agents."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedAgents = api.listAgents(workspaceId: workspaceId, includeArchived: true)
            async let loadedRuntimes = api.listRuntimes(workspaceId: workspaceId)
            agents = try await loadedAgents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            runtimes = try await loadedRuntimes
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createAgent(
        name: String,
        description: String,
        instructions: String,
        runtimeId: String,
        visibility: String,
        maxConcurrentTasks: Int,
        model: String,
        skillIds: Set<String>? = nil
    ) async -> Agent? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing agents."
            return nil
        }
        return await mutate(skillIds: skillIds, workspaceId: workspaceId) {
            try await api.createAgent(
                name: name,
                description: description,
                instructions: instructions,
                runtimeId: runtimeId,
                visibility: visibility,
                maxConcurrentTasks: maxConcurrentTasks,
                model: model,
                workspaceId: workspaceId
            )
        }
    }

    public func updateAgent(
        id: String,
        name: String,
        description: String,
        instructions: String,
        visibility: String,
        maxConcurrentTasks: Int,
        model: String,
        skillIds: Set<String>? = nil
    ) async -> Agent? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing agents."
            return nil
        }
        return await mutate(skillIds: skillIds, workspaceId: workspaceId) {
            try await api.updateAgent(
                id: id,
                name: name,
                description: description,
                instructions: instructions,
                visibility: visibility,
                maxConcurrentTasks: maxConcurrentTasks,
                model: model,
                workspaceId: workspaceId
            )
        }
    }

    public func archiveAgent(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing agents."
            return
        }
        _ = await mutate {
            try await api.archiveAgent(id: id, workspaceId: workspaceId)
        }
    }

    public func restoreAgent(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing agents."
            return
        }
        _ = await mutate {
            try await api.restoreAgent(id: id, workspaceId: workspaceId)
        }
    }

    public func cancelAgentTasks(id: String) async -> Int? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing agents."
            return nil
        }
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let response = try await api.cancelAgentTasks(id: id, workspaceId: workspaceId)
            lastActionMessage = "Cancelled \(response.count) tasks."
            return response.count
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func loadSkillOptions(for agentId: String?) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing agents."
            return
        }

        errorMessage = nil
        do {
            async let loadedSkills = api.listSkills(workspaceId: workspaceId)
            if let agentId {
                async let loadedAssignedSkills = api.listAgentSkills(agentId: agentId, workspaceId: workspaceId)
                skills = try await loadedSkills.sorted(by: skillSort)
                let assigned = try await loadedAssignedSkills
                assignedSkillIdsByAgentId[agentId] = Set(assigned.map(\.id))
            } else {
                skills = try await loadedSkills.sorted(by: skillSort)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mutate(skillIds: Set<String>? = nil, workspaceId: String? = nil, _ operation: () async throws -> Agent) async -> Agent? {
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let agent = try await operation()
            if let skillIds, let workspaceId {
                let sortedSkillIds = skillIds.sorted()
                try await api.setAgentSkills(agentId: agent.id, skillIds: sortedSkillIds, workspaceId: workspaceId)
                assignedSkillIdsByAgentId[agent.id] = Set(sortedSkillIds)
            }
            upsert(agent)
            return agent
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func upsert(_ agent: Agent) {
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = agent
        } else {
            agents.append(agent)
        }
        agents.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func skillSort(_ lhs: Skill, _ rhs: Skill) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
