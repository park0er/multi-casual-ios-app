#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct AgentTranscriptView: View {
    public let taskId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: AgentTimelineViewModel?

    public init(taskId: String) { self.taskId = taskId }

    public var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "Transcript Unavailable",
                                systemImage: "exclamationmark.triangle",
                                description: Text(MarkdownRenderer.attributedString(from: error))
                            )
                            Button {
                                Task { await viewModel.loadHistory() }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if viewModel.timeline.isEmpty {
                        ContentUnavailableView("No Messages", systemImage: "text.bubble", description: Text("This agent run has no transcript messages yet."))
                    } else {
                        List(viewModel.timeline) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: iconForType(item.type)).foregroundStyle(.secondary)
                                Text(labelForType(item.type)).font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                                Text("#\(item.id)").font(.caption2).foregroundStyle(.tertiary)
                            }
                            MarkdownText(item.summary).font(.system(.caption, design: .monospaced))
                        }.padding(.vertical, 2)
                        }.listStyle(.plain)
                    }
                } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .navigationTitle("Agent Transcript").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task {
                if viewModel == nil {
                    let vm = AgentTimelineViewModel(
                        taskId: taskId,
                        workspaceId: authSession.currentWorkspace?.id,
                        api: api
                    )
                    viewModel = vm
                    await vm.loadHistory()
                }
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
