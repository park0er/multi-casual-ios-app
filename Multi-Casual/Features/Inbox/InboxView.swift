#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct InboxView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: InboxViewModel?

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
                    }
                    if vm.loader.hasMore {
                        ProgressView().onAppear { Task { await vm.loadNext() } }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.refresh() }
            } else { ProgressView() }
        }
        .navigationTitle("Inbox")
        .onAppear {
            if viewModel == nil {
                viewModel = InboxViewModel(api: APIClient(authSession: authSession))
                Task { await viewModel?.loadNext() }
            }
        }
    }
}
#endif
