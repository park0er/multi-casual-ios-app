#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct AgentTranscriptView: View {
    public let taskId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(APIClient.self) private var api
    @State private var timeline: [TimelineItem] = []
    @State private var isLoading = true

    public init(taskId: String) { self.taskId = taskId }

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else {
                    List(timeline) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: iconForType(item.type)).foregroundStyle(.secondary)
                                Text(labelForType(item.type)).font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                                Text("#\(item.id)").font(.caption2).foregroundStyle(.tertiary)
                            }
                            Text(item.summary).font(.system(.caption, design: .monospaced))
                        }.padding(.vertical, 2)
                    }.listStyle(.plain)
                }
            }
            .navigationTitle("Agent Transcript").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task {
                if let messages = try? await api.listRunMessages(taskId: taskId) {
                    timeline = messages.map(TimelineItem.init(from:))
                }
                isLoading = false
            }
        }
    }

    private func iconForType(_ type: TaskMessage.MessageType) -> String {
        switch type {
        case .toolUse: return "wrench"
        case .toolResult: return "checkmark"
        case .thinking: return "brain"
        case .text: return "text.bubble"
        case .error: return "exclamationmark.triangle"
        }
    }

    private func labelForType(_ type: TaskMessage.MessageType) -> String {
        switch type {
        case .toolUse: return "Tool Use"
        case .toolResult: return "Result"
        case .thinking: return "Thinking"
        case .text: return "Output"
        case .error: return "Error"
        }
    }
}
#endif
