import Foundation
import Observation

@Observable
@MainActor
public final class IssueListViewModel {
    public enum ViewMode { case list, board }
    public static let pageSize = 50
    public let loader = PaginatedLoader<Issue>()
    public var viewMode: ViewMode = .list
    public var showCreateSheet = false
    public var lastError: Error?
    public private(set) var issuesByStatus: [IssueStatus: [Issue]] = [:]

    private let api: APIClient
    private let authSession: AuthSession
    private var offsetsByStatus: [IssueStatus: Int] = [:]
    private var totalsByStatus: [IssueStatus: Int] = [:]
    private var pageHasMoreByStatus: [IssueStatus: Bool] = [:]
    private var isLoading = false
    private var hasLoadedFirstPages = false

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api; self.authSession = authSession
    }

    public func loadNext() async {
        guard let wsId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before opening Issues.")
            return
        }
        guard !isLoading, loader.hasMore else { return }
        do {
            isLoading = true
            defer { isLoading = false }
            if !hasLoadedFirstPages {
                try await loadFirstPages(workspaceId: wsId)
            } else if let status = nextStatusWithMore() {
                let offset = offsetsByStatus[status, default: 0]
                let page = try await api.listIssues(
                    workspaceId: wsId,
                    status: status,
                    limit: Self.pageSize,
                    offset: offset
                )
                append(page, for: status)
            } else {
                loader.hasMore = false
            }
            lastError = nil
        } catch {
            loader.hasMore = false
            lastError = error
        }
    }

    public func refresh() async {
        resetPagination()
        await loadNext()
    }

    private func loadFirstPages(workspaceId: String) async throws {
        resetBuckets()
        for status in IssueStatus.boardCases {
            let page = try await api.listIssues(
                workspaceId: workspaceId,
                status: status,
                limit: Self.pageSize,
                offset: 0
            )
            append(page, for: status)
        }
        hasLoadedFirstPages = true
        syncFlatIssues()
    }

    private func append(_ page: PageResponse<Issue>, for status: IssueStatus) {
        issuesByStatus[status, default: []].append(contentsOf: page.items)
        offsetsByStatus[status] = issuesByStatus[status, default: []].count
        if let total = page.total {
            totalsByStatus[status] = total
        }
        pageHasMoreByStatus[status] = page.hasMore
        syncFlatIssues()
    }

    private func syncFlatIssues() {
        loader.items = IssueStatus.boardCases.flatMap { issuesByStatus[$0] ?? [] }
        loader.hasMore = IssueStatus.boardCases.contains { statusHasMore($0) }
    }

    private func statusHasMore(_ status: IssueStatus) -> Bool {
        let loaded = issuesByStatus[status, default: []].count
        if let total = totalsByStatus[status] {
            return loaded < total
        }
        return pageHasMoreByStatus[status] ?? false
    }

    private func nextStatusWithMore() -> IssueStatus? {
        IssueStatus.boardCases.first { statusHasMore($0) }
    }

    private func resetPagination() {
        loader.reset()
        resetBuckets()
        hasLoadedFirstPages = false
        lastError = nil
    }

    private func resetBuckets() {
        issuesByStatus = [:]
        offsetsByStatus = [:]
        totalsByStatus = [:]
        pageHasMoreByStatus = [:]
    }
}
