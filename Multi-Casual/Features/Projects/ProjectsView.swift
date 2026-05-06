#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct ProjectsView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: ProjectsViewModel?
    @State private var showCreateProject = false
    @State private var editingProject: Project?
    @State private var pendingDeleteProject: Project?
    @State private var showDeleteProjectConfirmation = false

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.loader.items.isEmpty && !vm.loader.hasMore && !vm.loader.isLoading && vm.lastError == nil {
                        ContentUnavailableView("No Projects", systemImage: "folder", description: Text("There are no projects in this workspace."))
                    }
                    ForEach(vm.loader.items) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            VStack(alignment: .leading, spacing: 4) {
                                MarkdownText(project.name).font(.body)
                                if let desc = project.description {
                                    MarkdownText(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                HStack(spacing: 8) {
                                    Label(project.status.displayName, systemImage: project.status.icon)
                                    Label(project.priority.displayName, systemImage: "flag")
                                    MarkdownText("\(project.doneCount)/\(project.issueCount) done")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteProject = project
                                showDeleteProjectConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingProject = project
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    if vm.loader.hasMore { ProgressView().onAppear { Task { await vm.loadNext() } } }
                    if let error = vm.lastError {
                        ErrorRetryView(message: error.localizedDescription) {
                            Task { await vm.refresh() }
                        }
                    }
                }
                .listStyle(.plain).refreshable { await vm.refresh() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateProject = true
                        } label: {
                            Label("New Project", systemImage: "plus")
                        }
                        .accessibilityIdentifier("ProjectsNewButton")
                    }
                }
                .sheet(isPresented: $showCreateProject) {
                    ProjectFormSheet(project: nil, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $editingProject) { project in
                    ProjectFormSheet(project: project, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .destructiveConfirmation(
                    deleteProjectConfirmation,
                    isPresented: $showDeleteProjectConfirmation,
                    onConfirm: {
                        guard let id = pendingDeleteProject?.id else { return }
                        Task {
                            await vm.deleteProject(id: id)
                            pendingDeleteProject = nil
                        }
                    },
                    onCancel: {
                        pendingDeleteProject = nil
                    }
                )
            } else { ProgressView() }
        }
        .navigationTitle("Projects")
        .onAppear {
            if viewModel == nil {
                viewModel = ProjectsViewModel(api: api, authSession: authSession)
                Task { await viewModel?.loadNext() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.refresh() }
        }
    }

    private var deleteProjectConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.deleteProject(name: pendingDeleteProject?.name ?? "")
    }
}

private struct ProjectFormSheet: View {
    let project: Project?
    let viewModel: ProjectsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var status: ProjectStatus
    @State private var priority: IssuePriority

    private let statusOptions = ProjectStatus.allCases.filter { $0 != .unknown }
    private let priorityOptions = IssuePriority.allCases.filter { $0 != .unknown }

    init(project: Project?, viewModel: ProjectsViewModel) {
        self.project = project
        self.viewModel = viewModel
        _title = State(initialValue: project?.name ?? "")
        _description = State(initialValue: project?.description ?? "")
        _status = State(initialValue: project?.status == .unknown ? .planned : (project?.status ?? .planned))
        _priority = State(initialValue: project?.priority == .unknown ? .noPriority : (project?.priority ?? .noPriority))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project title", text: $title)
                        .accessibilityIdentifier("ProjectTitleField")
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("ProjectDescriptionEditor")
                }

                Section("Details") {
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { status in
                            Label(status.displayName, systemImage: status.icon).tag(status)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(priorityOptions, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }

                if let error = viewModel.lastError {
                    Section {
                        MarkdownText(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
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
                    .accessibilityIdentifier("ProjectSaveButton")
                }
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isMutating
    }

    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionValue = trimmedDescription.isEmpty ? nil : trimmedDescription
        let saved: Project?
        if let project {
            saved = await viewModel.updateProject(
                id: project.id,
                title: trimmedTitle,
                description: descriptionValue,
                status: status,
                priority: priority
            )
        } else {
            saved = await viewModel.createProject(
                title: trimmedTitle,
                description: descriptionValue,
                status: status,
                priority: priority
            )
        }
        if saved != nil {
            dismiss()
        }
    }
}
#endif
