import Foundation
import Observation

@Observable
@MainActor
public final class PaginatedLoader<T: Identifiable & Sendable & Decodable> {
    public var items: [T] = []
    public var isLoading = false
    public var hasMore = true
    private var offset = 0

    public init() {}

    /// Loads the next page. Errors are **not** swallowed — they propagate to the
    /// caller (typically a ViewModel) which can surface them in UI state.
    public func loadNext(fetch: (Int) async throws -> PageResponse<T>) async throws {
        guard hasMore && !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let page = try await fetch(offset)
        items.append(contentsOf: page.items)
        offset += page.items.count
        hasMore = page.hasMore
    }

    public func reset() {
        items = []
        offset = 0
        hasMore = true
        isLoading = false
    }
}
