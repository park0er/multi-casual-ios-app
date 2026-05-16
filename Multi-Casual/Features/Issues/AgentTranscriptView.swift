#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct AgentTranscriptView: View {
    public let taskId: String
    public let workspaceId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var appLanguage
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: AgentTimelineViewModel?

    public init(taskId: String, workspaceId: String? = nil) {
        self.taskId = taskId
        self.workspaceId = workspaceId
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                AppStrings.localized("Transcript Unavailable", language: appLanguage),
                                systemImage: "exclamationmark.triangle",
                                description: Text(MarkdownRenderer.attributedString(from: error))
                            )
                            Button {
                                Task { await viewModel.loadHistory() }
                            } label: {
                                Label(AppStrings.localized("Retry", language: appLanguage), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if viewModel.timeline.isEmpty {
                        ContentUnavailableView(
                            AppStrings.localized("No Messages", language: appLanguage),
                            systemImage: "text.bubble",
                            description: Text(AppStrings.localized("This agent run has no transcript messages yet.", language: appLanguage))
                        )
                    } else {
                        List(viewModel.timeline) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: iconForType(item.type)).foregroundStyle(.secondary)
                                MarkdownText(labelForType(item.type)).font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                                MarkdownText("#\(item.id)").font(.caption2).foregroundStyle(.tertiary)
                            }
                            MarkdownText(item.summary).font(.system(.caption, design: .monospaced))
                        }.padding(.vertical, 2)
                        }.listStyle(.plain)
                    }
                } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .navigationTitle(AppStrings.localized("Agent Transcript", language: appLanguage)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(AppStrings.localized("Done", language: appLanguage)) { dismiss() } } }
            .task {
                if viewModel == nil {
                    let vm = AgentTimelineViewModel(
                        taskId: taskId,
                        workspaceId: workspaceId ?? authSession.currentWorkspace?.id,
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
