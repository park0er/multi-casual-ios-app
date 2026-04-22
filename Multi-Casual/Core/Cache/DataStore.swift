import Foundation

/// Lightweight actor cache for cross-view invalidation.
/// Currently only used by IssueDetailViewModel to signal that an issue
/// should be removed from any PaginatedLoader's items list.
///
/// NOTE(#19): The loaders are the true source of truth; DataStore only
/// provides a cross-cutting invalidation signal. If a loader doesn't
/// observe DataStore changes, its items will be stale until next refresh.
/// This is acceptable for v1 — a full sync is tracked in PAR-86 #19.
public actor DataStore {
    public static let shared = DataStore()

    private var invalidatedIssueIds: Set<String> = []

    public init() {}

    public func invalidateIssue(_ id: String) {
        invalidatedIssueIds.insert(id)
    }

    /// Check whether an issue has been invalidated since the last check.
    public func isIssueInvalidated(_ id: String) -> Bool {
        invalidatedIssueIds.contains(id)
    }

    /// Remove an issue from the invalidation set (e.g. after re-fetching).
    public func clearInvalidation(_ id: String) {
        invalidatedIssueIds.remove(id)
    }
}
