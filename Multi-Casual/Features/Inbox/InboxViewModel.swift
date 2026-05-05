import Foundation
import Observation

@Observable
@MainActor
public final class InboxViewModel {
    public let loader = PaginatedLoader<InboxItem>()
    public var lastError: Error?
    public var unreadCount: Int = 0
    public var pendingArchiveItem: InboxItem?
    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func loadNext() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before opening Inbox.")
            return
        }
        do {
            try await loader.loadNext { [api, workspaceId] offset in
                try await api.listInbox(workspaceId: workspaceId, limit: 50, offset: offset)
            }
            loader.items = Self.deduplicateInboxItems(loader.items)
            lastError = nil
            updateUnreadCount()
        } catch {
            lastError = error
        }
    }

    public func refresh() async { loader.reset(); await loadNext() }

    public func markRead(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before updating Inbox.")
            return
        }
        do {
            let updated = try await api.markInboxRead(id: id, workspaceId: workspaceId)
            if let index = loader.items.firstIndex(where: { $0.id == id }) {
                loader.items[index] = updated
            }
            updateUnreadCount()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func requestArchive(id: String) {
        pendingArchiveItem = loader.items.first { $0.id == id }
    }

    public func cancelPendingArchive() {
        pendingArchiveItem = nil
    }

    public func confirmPendingArchive() async {
        guard let item = pendingArchiveItem else { return }
        await archive(id: item.id)
        pendingArchiveItem = nil
    }

    public var pendingArchiveConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.archiveInboxItem(issueTitle: pendingArchiveItem?.issueTitle ?? "")
    }

    private func archive(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before updating Inbox.")
            return
        }
        do {
            _ = try await api.archiveInbox(id: id, workspaceId: workspaceId)
            loader.items.removeAll { $0.id == id }
            updateUnreadCount()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    private func updateUnreadCount() {
        unreadCount = loader.items.filter { !$0.read && !$0.archived }.count
    }

    private static func deduplicateInboxItems(_ items: [InboxItem]) -> [InboxItem] {
        let active = items.filter { !$0.archived }
        let groups = Dictionary(grouping: active) { item in
            item.issueId.isEmpty ? item.id : item.issueId
        }

        return groups.values.compactMap { group in
            group.max { $0.createdAt < $1.createdAt }
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}
