#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct InboxView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: InboxViewModel?
    @State private var observedWorkspaceId: String?
    @State private var showingArchiveConfirmation = false
    @State private var showingBulkArchiveConfirmation = false

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.loader.items.isEmpty && !vm.loader.hasMore && !vm.loader.isLoading && vm.lastError == nil {
                        ContentUnavailableView("No Inbox Items", systemImage: "tray", description: Text("There are no active notifications in this workspace."))
                    }
                    ForEach(vm.loader.items) { item in
                        NavigationLink(destination: IssueDetailView(issueId: item.issueId)) {
                            InboxRow(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                vm.requestArchive(id: item.id)
                                showingArchiveConfirmation = vm.pendingArchiveItem != nil
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
                .destructiveConfirmation(
                    vm.pendingArchiveConfirmation,
                    isPresented: $showingArchiveConfirmation
                ) {
                    Task { await vm.confirmPendingArchive() }
                } onCancel: {
                    vm.cancelPendingArchive()
                }
                .destructiveConfirmation(
                    vm.pendingBulkArchiveConfirmation,
                    isPresented: $showingBulkArchiveConfirmation
                ) {
                    Task { await vm.confirmPendingBulkArchive() }
                } onCancel: {
                    vm.cancelPendingBulkArchive()
                }
            } else { ProgressView() }
        }
        .navigationTitle("Inbox")
        .toolbar {
            if let vm = viewModel {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await vm.markAllRead() }
                        } label: {
                            Label("Mark All Read", systemImage: "envelope.open")
                        }
                        .disabled(vm.unreadCount == 0 || vm.loader.isLoading)
                        .accessibilityIdentifier("InboxMarkAllReadButton")

                        Button(role: .destructive) {
                            vm.requestBulkArchive(.read)
                            showingBulkArchiveConfirmation = true
                        } label: {
                            MarkdownIconLabel(InboxBulkArchiveAction.read.menuTitle, systemImage: "archivebox")
                        }
                        .disabled(!vm.loader.items.contains { $0.read } || vm.loader.isLoading)

                        Button(role: .destructive) {
                            vm.requestBulkArchive(.completed)
                            showingBulkArchiveConfirmation = true
                        } label: {
                            MarkdownIconLabel(InboxBulkArchiveAction.completed.menuTitle, systemImage: "checkmark.circle")
                        }
                        .disabled(!vm.loader.items.contains { $0.issueStatus == .done } || vm.loader.isLoading)

                        Button(role: .destructive) {
                            vm.requestBulkArchive(.all)
                            showingBulkArchiveConfirmation = true
                        } label: {
                            MarkdownIconLabel(InboxBulkArchiveAction.all.menuTitle, systemImage: "archivebox.fill")
                        }
                        .disabled(vm.loader.items.isEmpty || vm.loader.isLoading)
                    } label: {
                        Label("Inbox Actions", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("InboxActionsMenu")
                }
            }
        }
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
                    MarkdownText(identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                MarkdownText(displayType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                MarkdownText(item.createdAt.formatted(.relative(presentation: .named)))
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
                MarkdownText(item.issueTitle)
                    .fontWeight(item.read ? .regular : .semibold)
                    .lineLimit(2)
            }

            if let body = item.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                MarkdownText(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                MarkdownText(item.read ? "Read" : "Unread")
                if item.issueStatus != .unknown {
                    MarkdownText(item.issueStatus.displayName)
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
