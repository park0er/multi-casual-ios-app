#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct InboxView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: InboxViewModel?
    @State private var observedWorkspaceId: String?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    ForEach(vm.loader.items) { item in
                        NavigationLink(destination: IssueDetailView(issueId: item.issueId)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.issueIdentifier).font(.caption).foregroundStyle(.secondary)
                                Text(item.issueTitle).fontWeight(item.read ? .regular : .semibold)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await vm.archive(id: item.id) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !item.read {
                                Button {
                                    Task { await vm.markRead(id: item.id) }
                                } label: {
                                    Label("Read", systemImage: "envelope.open")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    if vm.loader.hasMore {
                        ProgressView().onAppear { Task { await vm.loadNext() } }
                    }
                    if let error = vm.lastError {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.refresh() }
            } else { ProgressView() }
        }
        .navigationTitle("Inbox")
        .onAppear {
            if viewModel == nil {
                observedWorkspaceId = authSession.currentWorkspace?.id
                viewModel = InboxViewModel(api: api, authSession: authSession)
                Task { await viewModel?.loadNext() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, newValue in
            guard observedWorkspaceId != newValue else { return }
            observedWorkspaceId = newValue
            Task { await viewModel?.refresh() }
        }
    }
}
#endif
