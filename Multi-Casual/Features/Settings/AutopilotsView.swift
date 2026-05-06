#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct AutopilotsView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: AutopilotsViewModel?
    @State private var showCreateSheet = false

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
                            NavigationLink {
                                AutopilotDetailView(autopilot: autopilot, viewModel: vm)
                            } label: {
                                AutopilotRow(autopilot: autopilot, assigneeName: vm.agentName(for: autopilot.assigneeId))
                            }
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

private struct AutopilotDetailView: View {
    let autopilot: Autopilot
    let viewModel: AutopilotsViewModel

    @State private var isAddingTrigger = false
    @State private var editingAutopilot: Autopilot?

    private var currentAutopilot: Autopilot {
        viewModel.detailAutopilot?.id == autopilot.id ? viewModel.detailAutopilot! : autopilot
    }

    var body: some View {
        let item = currentAutopilot
        List {
            if viewModel.isLoadingDetail && viewModel.detailAutopilot == nil {
                ProgressView()
            }

            Section("Properties") {
                MarkdownLabeledContent("Status", value: item.status.capitalized)
                MarkdownLabeledContent("Agent", value: viewModel.agentName(for: item.assigneeId))
                MarkdownLabeledContent("Output Mode", value: item.executionMode.replacingOccurrences(of: "_", with: " ").capitalized)
                if let description = item.description,
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt").font(.caption).foregroundStyle(.secondary)
                        MarkdownText(description)
                    }
                }
            }

            Section("Triggers") {
                if viewModel.detailTriggers.isEmpty {
                    Text("No triggers configured").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.detailTriggers) { trigger in
                        AutopilotTriggerRow(trigger: trigger)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteTrigger(autopilotId: item.id, triggerId: trigger.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(viewModel.isMutating)
                            }
                    }
                }

                Button {
                    isAddingTrigger = true
                } label: {
                    Label("Add Trigger", systemImage: "plus")
                }
                .disabled(viewModel.isMutating)
            }

            Section("Run History") {
                if viewModel.detailRuns.isEmpty {
                    Text("No runs yet").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.detailRuns) { run in
                        AutopilotRunRow(run: run, workspaceId: item.workspaceId)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    ErrorRetryView(message: errorMessage) {
                        Task { await viewModel.loadDetail(id: item.id) }
                    }
                }
            }
        }
        .markdownNavigationTitle(item.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    editingAutopilot = item
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    Task { _ = await viewModel.triggerAutopilot(id: item.id) }
                } label: {
                    Label("Run Now", systemImage: "play.fill")
                }
                .disabled(item.status != "active" || viewModel.isMutating)
            }
        }
        .refreshable { await viewModel.loadDetail(id: item.id) }
        .task { await viewModel.loadDetail(id: item.id) }
        .sheet(isPresented: $isAddingTrigger) {
            AutopilotTriggerSheet(autopilotId: item.id, viewModel: viewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingAutopilot) { autopilot in
            AutopilotFormSheet(autopilot: autopilot, viewModel: viewModel)
                .presentationDragIndicator(.visible)
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

private struct AutopilotTriggerRow: View {
    let trigger: AutopilotTrigger

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock")
                .foregroundStyle(trigger.enabled ? Color.accentColor : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    MarkdownText(trigger.kind.capitalized)
                        .font(.body.weight(.semibold))
                    if !trigger.enabled {
                        Text("Disabled")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let label = trigger.label, !label.isEmpty {
                    MarkdownText(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let cron = trigger.cronExpression {
                    MarkdownText([cron, trigger.timezone].compactMap { $0 }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let nextRunAt = trigger.nextRunAt {
                    MarkdownText("Next \(nextRunAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AutopilotRunRow: View {
    let run: AutopilotRun
    let workspaceId: String?
    @State private var showTranscript = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(statusColor)
                    .frame(width: 22)
                MarkdownText(run.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.body.weight(.semibold))
                Spacer()
                MarkdownText(run.triggeredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                MarkdownText(run.source.capitalized)
                if let failureReason = run.failureReason, !failureReason.isEmpty {
                    MarkdownText(failureReason).foregroundStyle(.red)
                } else if run.issueId != nil {
                    MarkdownText("Issue linked")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                if let issueId = run.issueId {
                    NavigationLink {
                        IssueDetailView(issueId: issueId)
                    } label: {
                        Label("Open Issue", systemImage: "number")
                    }
                }
                if run.issueId == nil, let taskId = run.taskId {
                    Button {
                        showTranscript = true
                    } label: {
                        Label("Transcript", systemImage: "text.bubble")
                    }
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showTranscript) {
            if let taskId = run.taskId {
                AgentTranscriptView(taskId: taskId, workspaceId: workspaceId)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var icon: String {
        switch run.status {
        case "running": return "arrow.triangle.2.circlepath"
        case "completed": return "checkmark.circle"
        case "failed": return "xmark.circle"
        default: return "clock"
        }
    }

    private var statusColor: Color {
        switch run.status {
        case "running": return .blue
        case "completed": return .green
        case "failed": return .red
        default: return .secondary
        }
    }
}

private struct AutopilotTriggerSheet: View {
    let autopilotId: String
    let viewModel: AutopilotsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var cronExpression = "0 9 * * *"
    @State private var timezone = TimeZone.current.identifier
    @State private var label = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    TextField("Cron expression", text: $cronExpression)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Timezone", text: $timezone)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Label", text: $label)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Trigger")
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
                            Text("Add")
                        }
                    }
                    .disabled(cronExpression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isMutating)
                }
            }
        }
    }

    private func submit() async {
        let trimmedCron = cronExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTimezone = timezone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trigger = await viewModel.createTrigger(
            autopilotId: autopilotId,
            cronExpression: trimmedCron,
            timezone: trimmedTimezone.isEmpty ? nil : trimmedTimezone,
            label: trimmedLabel.isEmpty ? nil : trimmedLabel
        )
        if trigger != nil {
            dismiss()
        }
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
