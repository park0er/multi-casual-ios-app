#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct IssueCreateSheet: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let onCreated: () -> Void

    @State private var viewModel: IssueCreateViewModel?

    public init(onCreated: @escaping () -> Void) { self.onCreated = onCreated }

    public var body: some View {
        Group {
            if let viewModel {
                IssueCreateForm(
                    viewModel: viewModel,
                    onCancel: { dismiss() },
                    onCreated: {
                        onCreated()
                        dismiss()
                    }
                )
            } else {
                NavigationStack {
                    ProgressView()
                        .navigationTitle("New Issue")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .task(id: authSession.currentWorkspace?.id) {
            let vm = IssueCreateViewModel(api: api, authSession: authSession)
            viewModel = vm
            await vm.loadOptions()
        }
    }
}

private struct IssueCreateForm: View {
    @Bindable var viewModel: IssueCreateViewModel
    let onCancel: () -> Void
    let onCreated: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Issue title", text: $viewModel.title)
                }

                Section("Description") {
                    TextEditor(text: $viewModel.description)
                        .frame(minHeight: 120)
                }

                Section("Details") {
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(viewModel.statusOptions, id: \.self) { status in
                            Label(status.displayName, systemImage: status.icon)
                                .tag(status)
                        }
                    }

                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(viewModel.priorityOptions, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }

                Section("Assignment") {
                    Picker("Assignee", selection: $viewModel.selectedAssigneeOptionId) {
                        Text("Unassigned").tag(IssueCreateViewModel.noAssigneeId)
                        ForEach(viewModel.assigneeOptions) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    .accessibilityIdentifier("IssueCreateAssigneePicker")
                    .accessibilityValue(
                        viewModel.isLoadingOptions
                            ? "Loading assignees"
                            : "Assignee options loaded: \(viewModel.assigneeOptions.count)"
                    )
                    .pickerStyle(.navigationLink)
                    .disabled(viewModel.isLoadingOptions)

                    if let assignee = viewModel.selectedAssignee {
                        LabeledContent(assignee.subtitle, value: assignee.type.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Project") {
                    Picker("Project", selection: $viewModel.selectedProjectId) {
                        Text("No Project").tag(IssueCreateViewModel.noProjectId)
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $viewModel.includesDueDate)
                    if viewModel.includesDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $viewModel.dueDate,
                            displayedComponents: [.date]
                        )
                    }
                }

                if viewModel.isLoadingOptions {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Loading workspace options")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorRetryView(message: error) {
                            Task { await viewModel.loadOptions() }
                        }
                    }
                }
            }
            .navigationTitle("New Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            guard await viewModel.submit() else { return }
                            onCreated()
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
    }
}
#endif
