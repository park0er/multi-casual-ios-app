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
                        Button { vm.viewMode = vm.viewMode == .list ? .board : .list } label: {
                            Image(systemName: vm.viewMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
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
                }
                .refreshable { await vm.refresh() }
            } else { ProgressView() }
        }
        .navigationTitle("Issues")
        .onAppear {
            if viewModel == nil {
                viewModel = IssueListViewModel(api: api, authSession: authSession)
                Task { await viewModel?.loadNext() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.refresh() }
        }
    }

    private func listView(vm: IssueListViewModel) -> some View {
        List {
            ForEach(vm.loader.items) { issue in
                NavigationLink(destination: IssueDetailView(issueId: issue.id)) {
                    IssueRowView(issue: issue)
                }
            }
            if vm.loader.hasMore { ProgressView().onAppear { Task { await vm.loadNext() } } }
        }
        .listStyle(.plain)
    }

    private func boardView(vm: IssueListViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(IssueStatus.allCases, id: \.self) { status in
                    let issues = vm.issuesByStatus[status] ?? []
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
                Text(issue.title).font(.body)
            }
        }.padding(.vertical, 4)
    }
}

struct BoardCardView: View {
    let issue: Issue
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.identifier).font(.caption).foregroundStyle(.secondary)
            Text(issue.title).font(.subheadline).lineLimit(2)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}
#endif
