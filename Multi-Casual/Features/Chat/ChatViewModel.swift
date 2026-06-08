import Foundation
import Observation

@Observable
@MainActor
public final class ChatViewModel {
    public var sessions: [ChatSession] = []
    public var agents: [Agent] = []
    public var messages: [ChatMessage] = []
    public var selectedSession: ChatSession?
    public var pendingTasks = PendingChatTasksResponse(tasks: [])
    public var pendingTask: ChatPendingTask?
    public var taskTimelines: [String: [TimelineItem]] = [:]
    public var errorMessage: String?
    public var timelineError: String?
    public var isLoading = false
    public var isSending = false
    public var isCreating = false
    public var isCancellingTask = false
    public var isLoadingTimeline = false

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func load() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before opening Chat."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedSessions = api.listChatSessions(workspaceId: workspaceId)
            async let loadedAgents = api.listAgents(workspaceId: workspaceId)
            async let loadedPending = api.listPendingChatTasks(workspaceId: workspaceId)
            sessions = try await loadedSessions.sorted { $0.updatedAt > $1.updatedAt }
            agents = try await loadedAgents.filter { $0.archivedAt == nil }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            pendingTasks = try await loadedPending
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func selectSession(_ session: ChatSession) async {
        selectedSession = session
        await loadMessages()
    }

    public func loadMessages() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before opening Chat."
            return
        }
        guard let session = selectedSession else { return }
        errorMessage = nil

        do {
            async let loadedMessages = api.listChatMessages(sessionId: session.id, workspaceId: workspaceId)
            async let loadedPending = api.getPendingChatTask(sessionId: session.id, workspaceId: workspaceId)
            messages = try await loadedMessages.sorted { $0.createdAt < $1.createdAt }
            pendingTask = try await loadedPending
            try await api.markChatSessionRead(sessionId: session.id, workspaceId: workspaceId)
            markSessionRead(session.id)
            await loadVisibleTaskTimelines(workspaceId: workspaceId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createSession(agentId: String, title: String?) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before opening Chat."
            return
        }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let session = try await api.createChatSession(
                agentId: agentId,
                title: trimmedTitle?.isEmpty == true ? nil : trimmedTitle,
                workspaceId: workspaceId
            )
            upsert(session)
            selectedSession = session
            await loadMessages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func archiveSelectedSession() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before opening Chat."
            return
        }
        guard let session = selectedSession else { return }
        errorMessage = nil

        do {
            try await api.archiveChatSession(id: session.id, workspaceId: workspaceId)
            sessions.removeAll { $0.id == session.id }
            selectedSession = nil
            messages = []
            pendingTask = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func sendMessage(_ content: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before opening Chat."
            return
        }
        guard let session = selectedSession else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let response = try await api.sendChatMessage(sessionId: session.id, content: trimmed, workspaceId: workspaceId)
            let optimistic = ChatMessage(
                id: response.messageId,
                chatSessionId: session.id,
                role: .user,
                content: trimmed,
                taskId: response.taskId,
                createdAt: response.createdAt
            )
            messages.append(optimistic)
            pendingTask = try await api.getPendingChatTask(sessionId: session.id, workspaceId: workspaceId)
            await loadVisibleTaskTimelines(workspaceId: workspaceId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func cancelPendingTask() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before opening Chat."
            return
        }
        guard let taskId = pendingTask?.taskId, !taskId.isEmpty else { return }
        guard !isCancellingTask else { return }

        isCancellingTask = true
        errorMessage = nil
        defer { isCancellingTask = false }

        do {
            try await api.cancelTaskById(taskId: taskId, workspaceId: workspaceId)
            pendingTask = nil
            pendingTasks = try await api.listPendingChatTasks(workspaceId: workspaceId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func agentName(for agentId: String) -> String {
        agents.first { $0.id == agentId }?.name ?? String(agentId.prefix(8))
    }

    public func pendingTaskCount(for session: ChatSession) -> Int {
        pendingTasks.tasks.filter { $0.chatSessionId == session.id }.count
    }

    public var visiblePendingTaskId: String? {
        guard let taskId = pendingTask?.taskId, !taskId.isEmpty else { return nil }
        let assistantMessageAlreadyPersisted = messages.contains {
            $0.role == .assistant && $0.taskId == taskId
        }
        return assistantMessageAlreadyPersisted ? nil : taskId
    }

    public var visibleTimelineItems: [TimelineItem] {
        guard let taskId = visiblePendingTaskId else { return [] }
        return taskTimelines[taskId] ?? []
    }

    public var shouldShowLiveTimeline: Bool {
        isSending || visiblePendingTaskId != nil
    }

    public func timelineItems(for message: ChatMessage) -> [TimelineItem] {
        guard let taskId = message.taskId, !taskId.isEmpty else { return [] }
        return taskTimelines[taskId] ?? []
    }

    public func loadTimeline(taskId: String, workspaceId: String? = nil) async {
        guard !taskId.isEmpty else { return }
        let resolvedWorkspaceId = workspaceId ?? authSession.currentWorkspace?.id
        guard let resolvedWorkspaceId, !resolvedWorkspaceId.isEmpty else {
            timelineError = "Pick a workspace before viewing agent progress."
            return
        }

        isLoadingTimeline = true
        timelineError = nil
        defer { isLoadingTimeline = false }

        do {
            taskTimelines[taskId] = try await api.listRunMessages(taskId: taskId, workspaceId: resolvedWorkspaceId)
                .map(TimelineItem.init(from:))
                .sorted { $0.id < $1.id }
        } catch {
            timelineError = error.localizedDescription
        }
    }

    public func applyRealtimeTaskMessage(taskId: String?, payload: Data) {
        guard let taskId, !taskId.isEmpty else { return }
        do {
            let message = try JSONDecoder().decode(TaskMessage.self, from: payload)
            timelineError = nil
            upsertTimelineItem(TimelineItem(from: message), taskId: taskId)
        } catch {
            timelineError = "Could not decode live chat update: \(error.localizedDescription)"
        }
    }

    private func upsert(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        sessions.sort { $0.updatedAt > $1.updatedAt }
    }

    private func markSessionRead(_ sessionId: String) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        let read = ChatSession(
            id: session.id,
            workspaceId: session.workspaceId,
            agentId: session.agentId,
            creatorId: session.creatorId,
            title: session.title,
            status: session.status,
            hasUnread: false,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt
        )
        upsert(read)
    }

    private func loadVisibleTaskTimelines(workspaceId: String) async {
        let taskIds = Set(
            messages.compactMap(\.taskId) +
            [pendingTask?.taskId].compactMap { $0 }
        ).filter { !$0.isEmpty }

        for taskId in taskIds {
            await loadTimeline(taskId: taskId, workspaceId: workspaceId)
        }
    }

    private func upsertTimelineItem(_ item: TimelineItem, taskId: String) {
        var timeline = taskTimelines[taskId] ?? []
        if let index = timeline.firstIndex(where: { $0.id == item.id }) {
            timeline[index] = item
        } else {
            timeline.append(item)
        }
        timeline.sort { $0.id < $1.id }
        taskTimelines[taskId] = timeline
    }
}
