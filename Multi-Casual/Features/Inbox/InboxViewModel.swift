import Foundation
import Observation

public enum InboxBulkArchiveAction: Equatable, Sendable {
    case all
    case read
    case completed

    public var menuTitle: String {
        switch self {
        case .all: "Archive All"
        case .read: "Archive Read"
        case .completed: "Archive Completed"
        }
    }

    public var confirmationTitle: String {
        switch self {
        case .all: "Archive all notifications?"
        case .read: "Archive read notifications?"
        case .completed: "Archive completed notifications?"
        }
    }

    public var confirmationMessage: String {
        switch self {
        case .all: "All notifications will be removed from Inbox."
        case .read: "All read notifications will be removed from Inbox."
        case .completed: "Notifications for completed issues will be removed from Inbox."
        }
    }
}

@Observable
@MainActor
public final class InboxViewModel {
    public let loader = PaginatedLoader<InboxItem>()
    public var lastError: Error?
    public var unreadCount: Int = 0
    public var pendingArchiveItem: InboxItem?
    public var pendingBulkArchiveAction: InboxBulkArchiveAction?
    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func loadNext() async {
        guard let workspace = authSession.currentWorkspace else {
            lastError = UserVisibleError("Pick a workspace before opening Inbox.")
            return
        }
        do {
            try await loader.loadNext { [api, workspace] offset in
                _ = offset
                return try await api.listInbox(workspaceId: workspace.id, workspaceSlug: workspace.slug)
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
        guard let workspace = authSession.currentWorkspace else {
            lastError = UserVisibleError("Pick a workspace before updating Inbox.")
            return
        }
        do {
            let updated = try await api.markInboxRead(id: id, workspaceId: workspace.id, workspaceSlug: workspace.slug)
            if let index = loader.items.firstIndex(where: { $0.id == id }) {
                loader.items[index] = updated
            }
            updateUnreadCount()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func markAllRead() async {
        guard let workspace = authSession.currentWorkspace else {
            lastError = UserVisibleError("Pick a workspace before updating Inbox.")
            return
        }
        do {
            _ = try await api.markAllInboxRead(workspaceId: workspace.id, workspaceSlug: workspace.slug)
            loader.items = loader.items.map(Self.markedRead)
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

    public func requestBulkArchive(_ action: InboxBulkArchiveAction) {
        pendingBulkArchiveAction = action
    }

    public func cancelPendingBulkArchive() {
        pendingBulkArchiveAction = nil
    }

    public func confirmPendingArchive() async {
        guard let item = pendingArchiveItem else { return }
        await archive(id: item.id)
        pendingArchiveItem = nil
    }

    public func confirmPendingBulkArchive() async {
        guard let action = pendingBulkArchiveAction else { return }
        await archiveBulk(action)
        pendingBulkArchiveAction = nil
    }

    public var pendingArchiveConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.archiveInboxItem(issueTitle: pendingArchiveItem?.issueTitle ?? "")
    }

    public var pendingBulkArchiveConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.archiveInboxBulk(pendingBulkArchiveAction ?? .all)
    }

    private func archive(id: String) async {
        guard let workspace = authSession.currentWorkspace else {
            lastError = UserVisibleError("Pick a workspace before updating Inbox.")
            return
        }
        do {
            _ = try await api.archiveInbox(id: id, workspaceId: workspace.id, workspaceSlug: workspace.slug)
            loader.items.removeAll { $0.id == id }
            updateUnreadCount()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    private func archiveBulk(_ action: InboxBulkArchiveAction) async {
        guard let workspace = authSession.currentWorkspace else {
            lastError = UserVisibleError("Pick a workspace before updating Inbox.")
            return
        }
        do {
            switch action {
            case .all:
                _ = try await api.archiveAllInbox(workspaceId: workspace.id, workspaceSlug: workspace.slug)
                loader.items.removeAll()
            case .read:
                _ = try await api.archiveAllReadInbox(workspaceId: workspace.id, workspaceSlug: workspace.slug)
                loader.items.removeAll { $0.read }
            case .completed:
                _ = try await api.archiveCompletedInbox(workspaceId: workspace.id, workspaceSlug: workspace.slug)
                loader.items.removeAll { $0.issueStatus == .done }
            }
            updateUnreadCount()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    private func updateUnreadCount() {
        unreadCount = loader.items.filter { !$0.read && !$0.archived }.count
    }

    private static func markedRead(_ item: InboxItem) -> InboxItem {
        InboxItem(
            id: item.id,
            issueId: item.issueId,
            issueIdentifier: item.issueIdentifier,
            issueTitle: item.issueTitle,
            type: item.type,
            body: item.body,
            severity: item.severity,
            issueStatus: item.issueStatus,
            read: true,
            archived: item.archived,
            createdAt: item.createdAt
        )
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
