import Foundation
import Observation

public struct TimelineItem: Identifiable, Sendable {
    public let id: Int
    public let type: TaskMessage.MessageType
    public let tool: String?
    public let summary: String
}

@Observable
@MainActor
public final class AgentTimelineViewModel {
    public let taskId: String
    public var timeline: [TimelineItem] = []
    public var isLoading = false
    public var errorMessage: String?

    private let api: APIClient

    public init(taskId: String, api: APIClient) {
        self.taskId = taskId
        self.api = api
    }

    public func loadHistory() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            timeline = try await api.listRunMessages(taskId: taskId)
                .map(TimelineItem.init(from:))
                .sorted { $0.id < $1.id }
        } catch {
            timeline = []
            errorMessage = error.localizedDescription
        }
    }

    public func applyRealtimeMessage(_ message: TaskMessage) {
        let item = TimelineItem(from: message)
        if let idx = timeline.firstIndex(where: { $0.id == item.id }) {
            timeline[idx] = item
        } else {
            timeline.append(item)
        }
        timeline.sort { $0.id < $1.id }
    }
}

extension TimelineItem {
    init(from msg: TaskMessage) {
        id = msg.seq
        type = msg.type
        tool = msg.tool
        switch msg.type {
        case .toolUse:
            let toolName = msg.tool ?? "tool"
            let inputSummary = msg.input?.first(where: { ["file_path", "query", "command"].contains($0.key) })
                .map { Self.shortenPath($0.value.displayString) } ?? ""
            summary = "\(toolName) \(inputSummary)".trimmingCharacters(in: .whitespaces)
        case .toolResult:
            summary = String((msg.output ?? "").prefix(80))
        case .thinking, .text:
            summary = String((msg.content ?? "").prefix(120))
        case .error:
            summary = msg.content ?? "Error"
        }
    }

    private static func shortenPath(_ s: String) -> String {
        let parts = s.split(separator: "/")
        guard parts.count > 3 else { return s }
        return ".../" + parts.suffix(2).joined(separator: "/")
    }
}
