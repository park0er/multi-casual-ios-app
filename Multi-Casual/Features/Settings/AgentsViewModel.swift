import Foundation
import Observation

@Observable
@MainActor
public final class AgentsViewModel {
    public var agents: [Agent] = []
    public var runtimes: [AgentRuntime] = []
    public var members: [WorkspaceMember] = []
    public var skills: [Skill] = []
    public var assignedSkillIdsByAgentId: [String: Set<String>] = [:]
    public var presenceByAgentId: [String: AgentPresenceSummary] = [:]
    public var runCountsByAgentId: [String: Int] = [:]
    public var isLoading = false
    public var isMutating = false
    public var errorMessage: String?
    public var lastActionMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public var activeAgents: [Agent] {
        agents.filter { $0.archivedAt == nil }
    }

    public var archivedAgents: [Agent] {
        agents.filter { $0.archivedAt != nil }
    }

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
            async let loadedMembers = api.listMembers(workspaceId: workspaceId)
            async let loadedSnapshot = api.getAgentTaskSnapshot(workspaceId: workspaceId)
            async let loadedRunCounts = api.getWorkspaceAgentRunCounts(workspaceId: workspaceId)
            agents = try await loadedAgents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            runtimes = try await loadedRuntimes
            do {
                members = try await loadedMembers
            } catch {
                members = []
            }
            do {
                let snapshot = try await loadedSnapshot
                presenceByAgentId = AgentPresenceSummary.buildMap(
                    agents: agents,
                    runtimes: runtimes,
                    tasks: snapshot
                )
            } catch {
                presenceByAgentId = [:]
            }
            do {
                let runCounts = try await loadedRunCounts
                runCountsByAgentId = Dictionary(uniqueKeysWithValues: runCounts.map { ($0.agentId, $0.runCount) })
            } catch {
                runCountsByAgentId = [:]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func canManageAgent(_ agent: Agent) -> Bool {
        guard let currentUserId = authSession.currentUser?.id else { return false }
        if agent.ownerId == currentUserId { return true }
        guard let membership = members.first(where: { $0.userId == currentUserId }) else { return false }
        return ["owner", "admin"].contains(membership.role.lowercased())
    }

    public func createAgent(
        name: String,
        description: String,
        instructions: String,
        runtimeId: String,
        visibility: String,
        maxConcurrentTasks: Int,
        model: String,
        avatarUrl: String? = nil,
        customEnv: [String: String]? = nil,
        customArgs: [String]? = nil,
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
                avatarUrl: avatarUrl,
                customEnv: customEnv,
                customArgs: customArgs,
                workspaceId: workspaceId
            )
        }
    }

    public func updateAgent(
        id: String,
        name: String,
        description: String,
        instructions: String,
        runtimeId: String? = nil,
        visibility: String,
        maxConcurrentTasks: Int,
        model: String,
        avatarUrl: String? = nil,
        customEnv: [String: String]? = nil,
        customArgs: [String]? = nil,
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
                runtimeId: runtimeId,
                visibility: visibility,
                maxConcurrentTasks: maxConcurrentTasks,
                model: model,
                avatarUrl: avatarUrl,
                customEnv: customEnv,
                customArgs: customArgs,
                workspaceId: workspaceId
            )
        }
    }

    public func uploadAvatarFile(filename: String, data: Data, contentType: String) async -> String? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before uploading an agent avatar."
            return nil
        }
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let attachment = try await api.uploadFile(
                filename: filename,
                data: data,
                contentType: contentType,
                workspaceId: workspaceId
            )
            return attachment.url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func uploadAvatar(
        for agent: Agent,
        filename: String,
        data: Data,
        contentType: String
    ) async -> Agent? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before uploading an agent avatar."
            return nil
        }
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let attachment = try await api.uploadFile(
                filename: filename,
                data: data,
                contentType: contentType,
                workspaceId: workspaceId
            )
            let updated = try await api.updateAgentAvatar(
                id: agent.id,
                avatarUrl: attachment.url,
                workspaceId: workspaceId
            )
            upsert(updated)
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
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

enum AgentFormDraft {
    enum ValidationError: LocalizedError, Equatable {
        case duplicateEnvironmentKey(String)
        case invalidEnvironmentLine(String)

        var errorDescription: String? {
            switch self {
            case .duplicateEnvironmentKey(let key):
                return "Duplicate environment key: \(key)"
            case .invalidEnvironmentLine(let line):
                return "Environment line must use KEY=value: \(line)"
            }
        }
    }

    static func environmentText(from environment: [String: JSONValue]) -> String {
        environment.keys.sorted().compactMap { key in
            guard case .string(let value) = environment[key] else { return nil }
            return "\(key)=\(value)"
        }
        .joined(separator: "\n")
    }

    static func argsText(from args: [String]) -> String {
        args.joined(separator: "\n")
    }

    static func parseCustomEnvironment(_ text: String) throws -> [String: String] {
        var environment: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard let separator = line.firstIndex(of: "=") else {
                throw ValidationError.invalidEnvironmentLine(line)
            }

            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            guard environment[key] == nil else {
                throw ValidationError.duplicateEnvironmentKey(String(key))
            }

            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            environment[String(key)] = String(value)
        }

        return environment
    }

    static func parseCustomArgs(_ text: String) -> [String] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
}
