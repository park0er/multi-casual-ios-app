#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct AutopilotsView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: AutopilotsViewModel?
    @State private var showCreateSheet = false
    @State private var editingAutopilot: Autopilot?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.isLoading && vm.autopilots.isEmpty {
                        ProgressView()
                    } else if vm.autopilots.isEmpty && vm.errorMessage == nil {
                        ContentUnavailableView("No Autopilots", systemImage: "bolt.badge.automatic", description: Text("This workspace has no autopilots yet."))
                    } else {
                        ForEach(vm.autopilots) { autopilot in
                            Button {
                                editingAutopilot = autopilot
                            } label: {
                                AutopilotRow(autopilot: autopilot, assigneeName: vm.agentName(for: autopilot.assigneeId))
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    Task { _ = await vm.triggerAutopilot(id: autopilot.id) }
                                } label: {
                                    Label("Trigger", systemImage: "play.fill")
                                }
                                .tint(.blue)
                                .disabled(vm.isMutating)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteAutopilot(id: autopilot.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(vm.isMutating)
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
                            Label("New Autopilot", systemImage: "plus")
                        }
                        .accessibilityIdentifier("AutopilotsNewButton")
                    }
                }
                .sheet(isPresented: $showCreateSheet) {
                    AutopilotFormSheet(autopilot: nil, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $editingAutopilot) { autopilot in
                    AutopilotFormSheet(autopilot: autopilot, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Autopilots")
        .onAppear {
            if viewModel == nil {
                let vm = AutopilotsViewModel(api: api, authSession: authSession)
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

private struct AutopilotRow: View {
    let autopilot: Autopilot
    let assigneeName: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bolt.badge.automatic")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                MarkdownText(autopilot.title)
                    .font(.body.weight(.semibold))
                if let description = autopilot.description,
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MarkdownText(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    MarkdownText(autopilot.status.capitalized)
                    MarkdownText(autopilot.executionMode.replacingOccurrences(of: "_", with: " ").capitalized)
                    MarkdownText(assigneeName)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AutopilotFormSheet: View {
    let autopilot: Autopilot?
    let viewModel: AutopilotsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var assigneeId: String
    @State private var status: String
    @State private var executionMode: String
    @State private var issueTitleTemplate: String

    init(autopilot: Autopilot?, viewModel: AutopilotsViewModel) {
        self.autopilot = autopilot
        self.viewModel = viewModel
        _title = State(initialValue: autopilot?.title ?? "")
        _description = State(initialValue: autopilot?.description ?? "")
        _assigneeId = State(initialValue: autopilot?.assigneeId ?? viewModel.agents.first?.id ?? "")
        _status = State(initialValue: autopilot?.status ?? "active")
        _executionMode = State(initialValue: autopilot?.executionMode ?? "create_issue")
        _issueTitleTemplate = State(initialValue: autopilot?.issueTitleTemplate ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Autopilot") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("AutopilotTitleField")
                    TextEditor(text: $description)
                        .frame(minHeight: 90)
                        .accessibilityIdentifier("AutopilotDescriptionEditor")
                }

                Section("Execution") {
                    Picker("Agent", selection: $assigneeId) {
                        ForEach(viewModel.agents) { agent in
                            MarkdownText(agent.name).tag(agent.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("AutopilotAssigneePicker")

                    Picker("Mode", selection: $executionMode) {
                        Text("Create Issue").tag("create_issue")
                        Text("Run Only").tag("run_only")
                    }

                    if autopilot != nil {
                        Picker("Status", selection: $status) {
                            Text("Active").tag("active")
                            Text("Paused").tag("paused")
                            Text("Archived").tag("archived")
                        }
                    }

                    TextField("Issue title template", text: $issueTitleTemplate)
                        .accessibilityIdentifier("AutopilotIssueTitleTemplateField")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(autopilot == nil ? "New Autopilot" : "Edit Autopilot")
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
                    .accessibilityIdentifier("AutopilotSaveButton")
                }
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !assigneeId.isEmpty &&
        !viewModel.isMutating
    }

    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = issueTitleTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionValue = trimmedDescription.isEmpty ? nil : trimmedDescription
        let templateValue = trimmedTemplate.isEmpty ? nil : trimmedTemplate

        let saved: Autopilot?
        if let autopilot {
            saved = await viewModel.updateAutopilot(
                id: autopilot.id,
                title: trimmedTitle,
                description: descriptionValue,
                assigneeId: assigneeId,
                status: status,
                executionMode: executionMode,
                issueTitleTemplate: templateValue
            )
        } else {
            saved = await viewModel.createAutopilot(
                title: trimmedTitle,
                description: descriptionValue,
                assigneeId: assigneeId,
                executionMode: executionMode,
                issueTitleTemplate: templateValue
            )
        }

        if saved != nil {
            dismiss()
        }
    }
}
#endif
