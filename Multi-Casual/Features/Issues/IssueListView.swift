#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct IssueListView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: IssueListViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                Group {
                    switch vm.viewMode {
                    case .list: listView(vm: vm)
                    case .board: boardView(vm: vm)
                    }
                }
                .toolbar {
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
                                    Label(option.displayName, systemImage: vm.sortOption == option ? "checkmark" : "arrow.up.arrow.down")
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
            } else { ProgressView() }
        }
        .navigationTitle("Issues")
        .onAppear {
            if viewModel == nil {
                viewModel = IssueListViewModel(api: api, authSession: authSession)
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
                ContentUnavailableView("No Issues", systemImage: "checklist", description: Text("There are no issues in this workspace."))
            }
            ForEach(vm.loader.items) { issue in
                NavigationLink(destination: IssueDetailView(issueId: issue.id)) {
                    IssueRowView(issue: issue)
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
                                BoardCardView(issue: issue)
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

public struct IssueRowView: View {
    public let issue: Issue
    public init(issue: Issue) { self.issue = issue }
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: issue.status.icon).foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.identifier).font(.caption).foregroundStyle(.secondary)
                MarkdownText(issue.title).font(.body)
            }
        }.padding(.vertical, 4)
    }
}

struct BoardCardView: View {
    let issue: Issue
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.identifier).font(.caption).foregroundStyle(.secondary)
            MarkdownText(issue.title).font(.subheadline).lineLimit(2)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}
#endif
