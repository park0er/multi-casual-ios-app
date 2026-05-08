#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct ProjectsView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @Environment(\.appLanguage) private var appLanguage
    @State private var viewModel: ProjectsViewModel?
    @State private var showCreateProject = false
    @State private var editingProject: Project?
    @State private var pendingDeleteProject: Project?
    @State private var showDeleteProjectConfirmation = false
    @State private var searchText = ""

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.loader.items.isEmpty && !vm.loader.hasMore && !vm.loader.isLoading && vm.lastError == nil {
                        ContentUnavailableView(
                            AppStrings.localized("No Projects", language: appLanguage),
                            systemImage: "folder",
                            description: Text(AppStrings.localized("There are no projects in this workspace.", language: appLanguage))
                        )
                    }
                    ForEach(vm.loader.items) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            HStack(alignment: .top, spacing: 10) {
                                if let icon = project.icon, !icon.isEmpty {
                                    MarkdownText(icon)
                                        .font(.title3)
                                        .frame(width: 28, alignment: .center)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    MarkdownText(project.name).font(.body)
                                    if let desc = project.description {
                                        MarkdownText(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    HStack(spacing: 8) {
                                        MarkdownIconLabel(AppStrings.localized(project.status.displayName, language: appLanguage), systemImage: project.status.icon)
                                        MarkdownIconLabel(AppStrings.localized(project.priority.displayName, language: appLanguage), systemImage: "flag")
                                        MarkdownText("\(project.doneCount)/\(project.issueCount) \(AppStrings.localized("Done", language: appLanguage))")
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteProject = project
                                showDeleteProjectConfirmation = true
                            } label: {
                                Label(AppStrings.localized("Delete", language: appLanguage), systemImage: "trash")
                            }
                            Button {
                                editingProject = project
                            } label: {
                                Label(AppStrings.localized("Edit", language: appLanguage), systemImage: "pencil")
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
                .listStyle(.plain)
                .refreshable { await vm.refresh() }
                .searchable(text: $searchText, prompt: AppStrings.localized("Search projects", language: appLanguage))
                .onSubmit(of: .search) {
                    Task { await vm.setSearchQuery(searchText) }
                }
                .onChange(of: searchText) { _, newValue in
                    guard newValue.isEmpty, !vm.searchQuery.isEmpty else { return }
                    Task { await vm.setSearchQuery("") }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateProject = true
                        } label: {
                            Label(AppStrings.localized("New Project", language: appLanguage), systemImage: "plus")
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
        .navigationTitle(AppStrings.localized("Projects", language: appLanguage))
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
    @State private var icon: String
    @State private var selectedLeadOptionId: String
    @State private var selectedRepoURLs: Set<String> = []
    @State private var customRepoURLs = ""

    private static let noLeadId = "none"
    private let statusOptions = ProjectStatus.allCases.filter { $0 != .unknown }
    private let priorityOptions = IssuePriority.allCases.filter { $0 != .unknown }

    init(project: Project?, viewModel: ProjectsViewModel) {
        self.project = project
        self.viewModel = viewModel
        _title = State(initialValue: project?.name ?? "")
        _description = State(initialValue: project?.description ?? "")
        _status = State(initialValue: project?.status == .unknown ? .planned : (project?.status ?? .planned))
        _priority = State(initialValue: project?.priority == .unknown ? .noPriority : (project?.priority ?? .noPriority))
        _icon = State(initialValue: project?.icon ?? "")
        _selectedLeadOptionId = State(initialValue: project?.leadType.flatMap { type in
            project?.leadId.map { "\(type):\($0)" }
        } ?? Self.noLeadId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project title", text: $title)
                        .accessibilityIdentifier("ProjectTitleField")
                    TextField("Icon", text: $icon)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("ProjectIconField")
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("ProjectDescriptionEditor")
                }

                Section("Details") {
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { status in
                            MarkdownIconLabel(status.displayName, systemImage: status.icon).tag(status)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(priorityOptions, id: \.self) { priority in
                            MarkdownText(priority.displayName).tag(priority)
                        }
                    }
                    Picker("Lead", selection: $selectedLeadOptionId) {
                        Text("No Lead").tag(Self.noLeadId)
                        ForEach(viewModel.projectLeadOptions) { option in
                            MarkdownText(option.displayName).tag(option.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(viewModel.isLoadingProjectOptions)
                    .accessibilityIdentifier("ProjectLeadPicker")
                    .accessibilityValue(
                        viewModel.isLoadingProjectOptions
                            ? "Loading leads"
                            : "Lead options loaded: \(viewModel.projectLeadOptions.count)"
                    )
                }

                if project == nil {
                    Section("Resources") {
                        if !viewModel.workspaceRepoURLs.isEmpty {
                            ForEach(viewModel.workspaceRepoURLs, id: \.self) { repoURL in
                                Toggle(isOn: Binding(
                                    get: { selectedRepoURLs.contains(repoURL) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedRepoURLs.insert(repoURL)
                                        } else {
                                            selectedRepoURLs.remove(repoURL)
                                        }
                                    }
                                )) {
                                    MarkdownText(repoURL).lineLimit(1)
                                }
                            }
                        }

                        TextEditor(text: $customRepoURLs)
                            .frame(minHeight: 72)
                            .accessibilityIdentifier("ProjectCustomRepoURLsEditor")

                        MarkdownText("Add one GitHub repo URL per line.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.isLoadingProjectOptions {
                    Section {
                        HStack {
                            ProgressView()
                            MarkdownText("Loading workspace options")
                                .foregroundStyle(.secondary)
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
            .task {
                await viewModel.loadProjectOptions()
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isMutating
    }

    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionValue = trimmedDescription.isEmpty ? nil : trimmedDescription
        let lead = selectedLead
        let saved: Project?
        if let project {
            saved = await viewModel.updateProject(
                id: project.id,
                title: trimmedTitle,
                description: descriptionValue,
                status: status,
                priority: priority,
                icon: trimmedIcon,
                leadType: lead?.type,
                leadId: lead?.assigneeId
            )
        } else {
            saved = await viewModel.createProject(
                title: trimmedTitle,
                description: descriptionValue,
                status: status,
                priority: priority,
                icon: trimmedIcon,
                leadType: lead?.type,
                leadId: lead?.assigneeId,
                resourceURLs: resourceURLs
            )
        }
        if saved != nil {
            dismiss()
        }
    }

    private var selectedLead: IssueAssigneeOption? {
        guard selectedLeadOptionId != Self.noLeadId else { return nil }
        return viewModel.projectLeadOptions.first { $0.id == selectedLeadOptionId }
    }

    private var resourceURLs: [String] {
        let custom = customRepoURLs
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(selectedRepoURLs).union(custom)).sorted()
    }
}
#endif
