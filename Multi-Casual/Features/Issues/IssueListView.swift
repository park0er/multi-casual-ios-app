#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct IssueListView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: IssueListViewModel?
    @State private var showingBatchDeleteConfirmation = false
    @State private var searchText = ""
    private let initialScope: IssueListViewModel.Scope

    public init(scope: IssueListViewModel.Scope = .all) {
        self.initialScope = scope
    }

    public var body: some View {
        Group {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    if initialScope.isPersonal {
                        Picker("My Issues Scope", selection: Binding(
                            get: { vm.scope },
                            set: { nextScope in Task { await vm.setScope(nextScope) } }
                        )) {
                            Text(IssueListViewModel.Scope.assignedToMe.displayName).tag(IssueListViewModel.Scope.assignedToMe)
                            Text(IssueListViewModel.Scope.createdByMe.displayName).tag(IssueListViewModel.Scope.createdByMe)
                            Text(IssueListViewModel.Scope.myAgents.displayName).tag(IssueListViewModel.Scope.myAgents)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("MyIssuesScopePicker")
                        Divider()
                    }
                    Group {
                        switch vm.viewMode {
                        case .list: listView(vm: vm)
                        case .board: boardView(vm: vm)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            if vm.isSelectionMode {
                                vm.clearSelection()
                            } else {
                                vm.isSelectionMode = true
                                vm.viewMode = .list
                            }
                        } label: {
                            Image(systemName: vm.isSelectionMode ? "xmark.circle" : "checkmark.circle")
                        }
                        .accessibilityIdentifier("IssueSelectionToggle")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                Task { await vm.setPriorityFilter(nil) }
                            } label: {
                                Label("All Priorities", systemImage: vm.priorityFilter == nil ? "checkmark" : "line.3.horizontal.decrease.circle")
                            }
                            ForEach(IssuePriority.allCases.filter { $0 != .unknown }, id: \.self) { priority in
                                Button {
                                    Task { await vm.setPriorityFilter(priority) }
                                } label: {
                                    Label(priority.displayName, systemImage: vm.priorityFilter == priority ? "checkmark" : "flag")
                                }
                            }
                        } label: {
                            Image(systemName: vm.priorityFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                        .accessibilityIdentifier("IssuePriorityFilterMenu")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(IssueListViewModel.SortOption.allCases, id: \.self) { option in
                                Button {
                                    vm.setSortOption(option)
                                } label: {
                                    MarkdownIconLabel(option.displayName, systemImage: vm.sortOption == option ? "checkmark" : "arrow.up.arrow.down")
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityIdentifier("IssueSortMenu")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { vm.viewMode = vm.viewMode == .list ? .board : .list } label: {
                            Image(systemName: vm.viewMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
                        .accessibilityIdentifier("IssueViewModeToggle")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { vm.showCreateSheet = true } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { vm.showCreateSheet },
                    set: { vm.showCreateSheet = $0 }
                )) {
                    IssueCreateSheet { vm.showCreateSheet = false; Task { await vm.refresh() } }
                        .presentationDragIndicator(.visible)
                }
                .refreshable { await vm.refresh() }
                .issueSearchable(
                    enabled: initialScope == .all,
                    text: $searchText,
                    submit: { Task { await vm.setSearchQuery(searchText) } },
                    clear: { newValue in
                        guard newValue.isEmpty, !vm.searchQuery.isEmpty else { return }
                        Task { await vm.setSearchQuery("") }
                    }
                )
                .safeAreaInset(edge: .bottom) {
                    if vm.isSelectionMode && !vm.selectedIssueIds.isEmpty {
                        IssueBatchActionBar(
                            selectedCount: vm.selectedIssueIds.count,
                            assigneeOptions: vm.batchAssigneeOptions,
                            isLoadingAssignees: vm.isLoadingBatchAssignees,
                            onClear: { vm.clearSelection() },
                            onLoadAssignees: { Task { await vm.loadBatchAssigneeOptions() } },
                            onStatus: { status in Task { await vm.batchUpdateSelected(status: status) } },
                            onPriority: { priority in Task { await vm.batchUpdateSelected(priority: priority) } },
                            onAssignee: { option in Task { await vm.batchAssignSelected(optionId: option.id) } },
                            onDelete: { showingBatchDeleteConfirmation = true }
                        )
                    }
                }
                .destructiveConfirmation(
                    DestructiveConfirmation.deleteIssues(count: vm.selectedIssueIds.count),
                    isPresented: $showingBatchDeleteConfirmation
                ) {
                    Task { await vm.batchDeleteSelected() }
                }
            } else { ProgressView() }
        }
        .navigationTitle(initialScope.isPersonal ? "My Issues" : "Issues")
        .onAppear {
            if viewModel == nil {
                viewModel = IssueListViewModel(api: api, authSession: authSession, scope: initialScope)
                Task { await viewModel?.loadNext() }
                #if DEBUG
                if ProcessInfo.processInfo.environment["MULTICA_DEBUG_OPEN_CREATE_SHEET"] == "1" {
                    viewModel?.showCreateSheet = true
                }
                #endif
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.refresh() }
        }
    }

    private func listView(vm: IssueListViewModel) -> some View {
        List {
            if vm.loader.items.isEmpty && !vm.loader.hasMore && !vm.loader.isLoading && vm.lastError == nil {
                ContentUnavailableView(
                    vm.scope.emptyTitle,
                    systemImage: initialScope.isPersonal ? "person.crop.circle.badge.checkmark" : "checklist",
                    description: Text(vm.scope.emptyDescription)
                )
            }
            ForEach(vm.loader.items) { issue in
                if vm.isSelectionMode {
                    Button {
                        vm.toggleSelection(issueId: issue.id)
                    } label: {
                        IssueSelectableRowView(
                            issue: issue,
                            childProgressText: vm.childProgressText(for: issue),
                            isSelected: vm.selectedIssueIds.contains(issue.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("IssueSelectionRow-\(issue.identifier)")
                } else {
                    NavigationLink(destination: IssueDetailView(issueId: issue.id)) {
                        IssueRowView(issue: issue, childProgressText: vm.childProgressText(for: issue))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if issue.status != .done {
                            Button {
                                Task { await vm.updateStatus(issueId: issue.id, to: .done) }
                            } label: {
                                Label("Done", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                    }
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
    }

    private func boardView(vm: IssueListViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(IssueStatus.boardCases, id: \.self) { status in
                    let issues = vm.issues(for: status)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: status.icon)
                            Text(status.displayName).font(.caption.bold())
                            Text("(\(issues.count))").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        ForEach(issues) { issue in
                            NavigationLink(destination: IssueDetailView(issueId: issue.id)) {
                                BoardCardView(issue: issue, childProgressText: vm.childProgressText(for: issue))
                            }.buttonStyle(.plain)
                        }
                    }
                    .frame(width: 260).padding(8)
                    .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }.padding()
        }
        .overlay(alignment: .topLeading) {
            if let error = vm.lastError {
                ErrorRetryView(message: error.localizedDescription) {
                    Task { await vm.refresh() }
                }
                    .padding()
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func issueSearchable(
        enabled: Bool,
        text: Binding<String>,
        submit: @escaping () -> Void,
        clear: @escaping (String) -> Void
    ) -> some View {
        if enabled {
            self
                .searchable(text: text, prompt: "Search issues")
                .onSubmit(of: .search, submit)
                .onChange(of: text.wrappedValue) { _, newValue in clear(newValue) }
        } else {
            self
        }
    }
}

private struct IssueBatchActionBar: View {
    let selectedCount: Int
    let assigneeOptions: [IssueAssigneeOption]
    let isLoadingAssignees: Bool
    let onClear: () -> Void
    let onLoadAssignees: () -> Void
    let onStatus: (IssueStatus) -> Void
    let onPriority: (IssuePriority) -> Void
    let onAssignee: (IssueAssigneeOption) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onClear) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Clear Selection")

            MarkdownText("\(selectedCount) selected")
                .font(.caption.weight(.semibold))
                .frame(minWidth: 76, alignment: .leading)

            Menu {
                ForEach(IssueStatus.displayCases, id: \.self) { status in
                    Button(status.displayName) { onStatus(status) }
                }
            } label: {
                Label("Status", systemImage: "circle.dashed")
            }
            .accessibilityIdentifier("IssueBatchStatusMenu")

            Menu {
                ForEach(IssuePriority.allCases.filter { $0 != .unknown }, id: \.self) { priority in
                    Button(priority.displayName) { onPriority(priority) }
                }
            } label: {
                Label("Priority", systemImage: "flag")
            }
            .accessibilityIdentifier("IssueBatchPriorityMenu")

            Menu {
                if isLoadingAssignees {
                    Label("Loading", systemImage: "hourglass")
                }
                ForEach(assigneeOptions) { option in
                    Button {
                        onAssignee(option)
                    } label: {
                        MarkdownIconLabel(option.displayName, systemImage: option.type == "agent" ? "bolt.circle" : "person.circle")
                    }
                }
            } label: {
                Label("Assignee", systemImage: "person.crop.circle")
            }
            .accessibilityIdentifier("IssueBatchAssigneeMenu")
            .accessibilityValue(isLoadingAssignees ? "Loading assignees" : "Assignee options loaded: \(assigneeOptions.count)")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete Selected Issues")
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .task {
            if assigneeOptions.isEmpty {
                onLoadAssignees()
            }
        }
    }
}

public struct IssueRowView: View {
    public let issue: Issue
    public let childProgressText: String?
    public init(issue: Issue, childProgressText: String? = nil) {
        self.issue = issue
        self.childProgressText = childProgressText
    }
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: issue.status.icon).foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.identifier).font(.caption).foregroundStyle(.secondary)
                MarkdownText(issue.title).font(.body)
            }
            Spacer(minLength: 8)
            if let childProgressText {
                Label(childProgressText, systemImage: "checklist")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.1), in: Capsule())
                    .accessibilityLabel("Sub-issues \(childProgressText)")
            }
        }.padding(.vertical, 4)
    }
}

private struct IssueSelectableRowView: View {
    let issue: Issue
    let childProgressText: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 20)
            IssueRowView(issue: issue, childProgressText: childProgressText)
        }
    }
}

struct BoardCardView: View {
    let issue: Issue
    let childProgressText: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(issue.identifier).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                if let childProgressText {
                    Label(childProgressText, systemImage: "checklist")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel("Sub-issues \(childProgressText)")
                }
            }
            MarkdownText(issue.title).font(.subheadline).lineLimit(2)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}
#endif
