import Foundation
import Observation

@Observable
@MainActor
public final class InboxViewModel {
    public let loader = PaginatedLoader<InboxItem>()
    public var lastError: Error?
    public var unreadCount: Int = 0
    private let api: APIClient

    public init(api: APIClient) { self.api = api }

    public func loadNext() async {
        do {
            try await loader.loadNext { [api] offset in try await api.listInbox(limit: 50, offset: offset) }
            lastError = nil
            updateUnreadCount()
        } catch {
            lastError = error
        }
    }

    public func refresh() async { loader.reset(); await loadNext() }

    public func markRead(id: String) async {
        do {
            let updated = try await api.markInboxRead(id: id)
            if let index = loader.items.firstIndex(where: { $0.id == id }) {
                loader.items[index] = updated
            }
            updateUnreadCount()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func archive(id: String) async {
        do {
            _ = try await api.archiveInbox(id: id)
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
}
