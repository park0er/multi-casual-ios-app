import Foundation
import Observation

@Observable
@MainActor
public final class AutopilotsViewModel {
    public var autopilots: [Autopilot] = []
    public var agents: [Agent] = []
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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedAutopilots = api.listAutopilots()
            if let workspaceId = authSession.currentWorkspace?.id {
                async let loadedAgents = api.listAgents(workspaceId: workspaceId)
                let (autopilotResponse, agentList) = try await (loadedAutopilots, loadedAgents)
                autopilots = autopilotResponse.autopilots.sorted(by: autopilotSort)
                agents = agentList.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            } else {
                let autopilotResponse = try await loadedAutopilots
                autopilots = autopilotResponse.autopilots.sorted(by: autopilotSort)
                agents = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createAutopilot(
        title: String,
        description: String?,
        assigneeId: String,
        executionMode: String,
        issueTitleTemplate: String?
    ) async -> Autopilot? {
        await mutate {
            try await api.createAutopilot(
                title: title,
                description: description,
                assigneeId: assigneeId,
                executionMode: executionMode,
                issueTitleTemplate: issueTitleTemplate
            )
        }
    }

    public func updateAutopilot(
        id: String,
        title: String,
        description: String?,
        assigneeId: String,
        status: String,
        executionMode: String,
        issueTitleTemplate: String?
    ) async -> Autopilot? {
        await mutate {
            try await api.updateAutopilot(
                id: id,
                title: title,
                description: description,
                assigneeId: assigneeId,
                status: status,
                executionMode: executionMode,
                issueTitleTemplate: issueTitleTemplate
            )
        }
    }

    public func triggerAutopilot(id: String) async -> AutopilotRun? {
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let run = try await api.triggerAutopilot(id: id)
            lastActionMessage = "Triggered \(run.status.replacingOccurrences(of: "_", with: " "))."
            return run
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func deleteAutopilot(id: String) async {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            try await api.deleteAutopilot(id: id)
            autopilots.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func agentName(for assigneeId: String) -> String {
        agents.first(where: { $0.id == assigneeId })?.name ?? assigneeId
    }

    private func mutate(_ operation: () async throws -> Autopilot) async -> Autopilot? {
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let autopilot = try await operation()
            upsert(autopilot)
            return autopilot
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func upsert(_ autopilot: Autopilot) {
        if let index = autopilots.firstIndex(where: { $0.id == autopilot.id }) {
            autopilots[index] = autopilot
        } else {
            autopilots.append(autopilot)
        }
        autopilots.sort(by: autopilotSort)
    }

    private func autopilotSort(_ lhs: Autopilot, _ rhs: Autopilot) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}
