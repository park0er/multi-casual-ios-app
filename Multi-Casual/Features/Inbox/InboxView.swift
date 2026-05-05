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
                            InboxRow(item: item)
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
                        ErrorRetryView(message: error.localizedDescription) {
                            Task { await vm.refresh() }
                        }
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

private struct InboxRow: View {
    let item: InboxItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let identifier = displayIdentifier {
                    Text(identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(displayType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(item.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(item.read ? Color.clear : Color.accentColor)
                    .frame(width: 8, height: 8)
                    .overlay {
                        if item.read {
                            Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        }
                    }
                Text(item.issueTitle)
                    .fontWeight(item.read ? .regular : .semibold)
                    .lineLimit(2)
            }

            if let body = item.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(item.read ? "Read" : "Unread")
                if item.issueStatus != .unknown {
                    Text(item.issueStatus.displayName)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var displayType: String {
        item.type
            .split(separator: "_")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private var displayIdentifier: String? {
        guard !item.issueIdentifier.isEmpty, item.issueIdentifier != item.issueId else { return nil }
        return item.issueIdentifier
    }
}
#endif
