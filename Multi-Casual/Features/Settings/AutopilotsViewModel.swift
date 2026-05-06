import Foundation
import Observation

@Observable
@MainActor
public final class AutopilotsViewModel {
    public var autopilots: [Autopilot] = []
    public var agents: [Agent] = []
    public var detailAutopilot: Autopilot?
    public var detailTriggers: [AutopilotTrigger] = []
    public var detailRuns: [AutopilotRun] = []
    public var isLoading = false
    public var isLoadingDetail = false
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
            errorMessage = "Pick a workspace before managing autopilots."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedAutopilots = api.listAutopilots(workspaceId: workspaceId)
            async let loadedAgents = api.listAgents(workspaceId: workspaceId)
            let (autopilotResponse, agentList) = try await (loadedAutopilots, loadedAgents)
            autopilots = autopilotResponse.autopilots.sorted(by: autopilotSort)
            agents = agentList.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadDetail(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing autopilots."
            return
        }
        isLoadingDetail = true
        errorMessage = nil
        if detailAutopilot?.id != id {
            detailAutopilot = nil
            detailTriggers = []
            detailRuns = []
        }
        defer { isLoadingDetail = false }

        do {
            async let loadedDetail = api.getAutopilot(id: id, workspaceId: workspaceId)
            async let loadedRuns = api.listAutopilotRuns(id: id, workspaceId: workspaceId, limit: 50, offset: 0)
            let (detail, runsResponse) = try await (loadedDetail, loadedRuns)
            detailAutopilot = detail.autopilot
            upsert(detail.autopilot)
            detailTriggers = detail.triggers.sorted(by: triggerSort)
            detailRuns = runsResponse.runs.sorted(by: runSort)
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
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing autopilots."
            return nil
        }
        return await mutate {
            try await api.createAutopilot(
                title: title,
                description: description,
                assigneeId: assigneeId,
                executionMode: executionMode,
                issueTitleTemplate: issueTitleTemplate,
                workspaceId: workspaceId
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
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing autopilots."
            return nil
        }
        return await mutate {
            try await api.updateAutopilot(
                id: id,
                title: title,
                description: description,
                assigneeId: assigneeId,
                status: status,
                executionMode: executionMode,
                issueTitleTemplate: issueTitleTemplate,
                workspaceId: workspaceId
            )
        }
    }

    public func triggerAutopilot(id: String) async -> AutopilotRun? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing autopilots."
            return nil
        }
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let run = try await api.triggerAutopilot(id: id, workspaceId: workspaceId)
            lastActionMessage = "Triggered \(run.status.replacingOccurrences(of: "_", with: " "))."
            upsertRun(run)
            return run
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func deleteAutopilot(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing autopilots."
            return
        }
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            try await api.deleteAutopilot(id: id, workspaceId: workspaceId)
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

    public func createTrigger(
        autopilotId: String,
        cronExpression: String,
        timezone: String?,
        label: String?
    ) async -> AutopilotTrigger? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing autopilots."
            return nil
        }
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            let trigger = try await api.createAutopilotTrigger(
                autopilotId: autopilotId,
                kind: "schedule",
                cronExpression: cronExpression,
                timezone: timezone,
                label: label,
                workspaceId: workspaceId
            )
            upsertTrigger(trigger)
            return trigger
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func deleteTrigger(autopilotId: String, triggerId: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing autopilots."
            return
        }
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        lastActionMessage = nil
        defer { isMutating = false }

        do {
            try await api.deleteAutopilotTrigger(autopilotId: autopilotId, triggerId: triggerId, workspaceId: workspaceId)
            detailTriggers.removeAll { $0.id == triggerId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsert(_ autopilot: Autopilot) {
        if let index = autopilots.firstIndex(where: { $0.id == autopilot.id }) {
            autopilots[index] = autopilot
        } else {
            autopilots.append(autopilot)
        }
        if detailAutopilot?.id == autopilot.id {
            detailAutopilot = autopilot
        }
        autopilots.sort(by: autopilotSort)
    }

    private func upsertTrigger(_ trigger: AutopilotTrigger) {
        if let index = detailTriggers.firstIndex(where: { $0.id == trigger.id }) {
            detailTriggers[index] = trigger
        } else {
            detailTriggers.append(trigger)
        }
        detailTriggers.sort(by: triggerSort)
    }

    private func upsertRun(_ run: AutopilotRun) {
        if let index = detailRuns.firstIndex(where: { $0.id == run.id }) {
            detailRuns[index] = run
        } else {
            detailRuns.insert(run, at: 0)
        }
        detailRuns.sort(by: runSort)
    }

    private func autopilotSort(_ lhs: Autopilot, _ rhs: Autopilot) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func triggerSort(_ lhs: AutopilotTrigger, _ rhs: AutopilotTrigger) -> Bool {
        switch (lhs.nextRunAt, rhs.nextRunAt) {
        case let (left?, right?):
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func runSort(_ lhs: AutopilotRun, _ rhs: AutopilotRun) -> Bool {
        lhs.triggeredAt > rhs.triggeredAt
    }
}
