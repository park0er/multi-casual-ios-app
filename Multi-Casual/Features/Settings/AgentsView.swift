#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct AgentsView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: AgentsViewModel?
    @State private var showCreateSheet = false
    @State private var editingAgent: Agent?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.isLoading && vm.agents.isEmpty {
                        ProgressView()
                    } else if vm.agents.isEmpty && vm.errorMessage == nil {
                        ContentUnavailableView("No Agents", systemImage: "bolt", description: Text("This workspace has no agents yet."))
                    } else {
                        ForEach(vm.agents) { agent in
                            Button {
                                editingAgent = agent
                            } label: {
                                AgentRow(agent: agent)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if agent.archivedAt == nil {
                                    Button(role: .destructive) {
                                        Task { await vm.archiveAgent(id: agent.id) }
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                } else {
                                    Button {
                                        Task { await vm.restoreAgent(id: agent.id) }
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    Task { _ = await vm.cancelAgentTasks(id: agent.id) }
                                } label: {
                                    Label("Cancel Tasks", systemImage: "xmark.circle")
                                }
                                .tint(.orange)
                            }
                        }
                    }

                    if let lastActionMessage = vm.lastActionMessage {
                        Section {
                            MarkdownText(lastActionMessage).font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage = vm.errorMessage {
                        Section {
                            ErrorRetryView(message: errorMessage) {
                                Task { await vm.load() }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.load() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("New Agent", systemImage: "plus")
                        }
                        .accessibilityIdentifier("AgentsNewButton")
                    }
                }
                .sheet(isPresented: $showCreateSheet) {
                    AgentFormSheet(agent: nil, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $editingAgent) { agent in
                    AgentFormSheet(agent: agent, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Agents")
        .onAppear {
            if viewModel == nil {
                let vm = AgentsViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.load() }
        }
    }
}

private struct AgentRow: View {
    let agent: Agent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: agent.archivedAt == nil ? "bolt.circle" : "archivebox")
                .foregroundStyle(agent.archivedAt == nil ? Color.accentColor : Color.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    MarkdownText(agent.name).font(.body.weight(.semibold))
                    if agent.archivedAt != nil {
                        Text("Archived")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                if !agent.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MarkdownText(agent.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    MarkdownText(agent.status.capitalized)
                    MarkdownText(agent.visibility.capitalized)
                    if let model = agent.model, !model.isEmpty {
                        MarkdownText(model)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AgentFormSheet: View {
    let agent: Agent?
    let viewModel: AgentsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var instructions: String
    @State private var runtimeId: String
    @State private var visibility: String
    @State private var maxConcurrentTasks: Int
    @State private var model: String

    init(agent: Agent?, viewModel: AgentsViewModel) {
        self.agent = agent
        self.viewModel = viewModel
        _name = State(initialValue: agent?.name ?? "")
        _description = State(initialValue: agent?.description ?? "")
        _instructions = State(initialValue: agent?.instructions ?? "")
        _runtimeId = State(initialValue: agent?.runtimeId ?? viewModel.runtimes.first?.id ?? "")
        _visibility = State(initialValue: agent?.visibility ?? "workspace")
        _maxConcurrentTasks = State(initialValue: agent?.maxConcurrentTasks ?? 1)
        _model = State(initialValue: agent?.model ?? "gpt")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("AgentNameField")
                    TextField("Model", text: $model)
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .accessibilityIdentifier("AgentDescriptionEditor")
                    TextEditor(text: $instructions)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("AgentInstructionsEditor")
                }

                Section("Runtime") {
                    if agent == nil {
                        Picker("Runtime", selection: $runtimeId) {
                            ForEach(viewModel.runtimes) { runtime in
                                MarkdownText("\(runtime.name) (\(runtime.status))").tag(runtime.id)
                            }
                        }
                    } else {
                        MarkdownLabeledContent("Runtime", value: agent?.runtimeId ?? "")
                    }

                    Picker("Visibility", selection: $visibility) {
                        Text("Workspace").tag("workspace")
                        Text("Private").tag("private")
                    }

                    Stepper("Max Tasks: \(maxConcurrentTasks)", value: $maxConcurrentTasks, in: 1...20)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(agent == nil ? "New Agent" : "Edit Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isMutating {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("AgentSaveButton")
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (agent != nil || !runtimeId.isEmpty) &&
        !viewModel.isMutating
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)

        let saved: Agent?
        if let agent {
            saved = await viewModel.updateAgent(
                id: agent.id,
                name: trimmedName,
                description: trimmedDescription,
                instructions: trimmedInstructions,
                visibility: visibility,
                maxConcurrentTasks: maxConcurrentTasks,
                model: trimmedModel
            )
        } else {
            saved = await viewModel.createAgent(
                name: trimmedName,
                description: trimmedDescription,
                instructions: trimmedInstructions,
                runtimeId: runtimeId,
                visibility: visibility,
                maxConcurrentTasks: maxConcurrentTasks,
                model: trimmedModel
            )
        }

        if saved != nil {
            dismiss()
        }
    }
}
#endif
