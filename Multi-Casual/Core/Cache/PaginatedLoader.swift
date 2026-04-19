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

    public func loadNext(fetch: (Int) async throws -> PageResponse<T>) async {
        guard hasMore && !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let page = try? await fetch(offset)
        let newItems = page?.items ?? []
        items.append(contentsOf: newItems)
        offset += newItems.count
        hasMore = page?.hasMore ?? false
    }

    public func reset() {
        items = []
        offset = 0
        hasMore = true
        isLoading = false
    }
}
