#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import Observation

@Observable
@MainActor
public final class InboxViewModel {
    public let loader = PaginatedLoader<InboxItem>()
    public var lastError: Error?
    private let api: APIClient

    public init(api: APIClient) { self.api = api }

    public func loadNext() async {
        do {
            try await loader.loadNext { [api] offset in try await api.listInbox(limit: 50, offset: offset) }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func refresh() async { loader.reset(); await loadNext() }

    public var unreadCount: Int { loader.items.filter { !$0.read }.count }
}
#endif
