import Foundation
import Observation

@Observable
@MainActor
public final class IssueListViewModel {
    public enum ViewMode { case list, board }
    public enum SortOption: String, CaseIterable {
        case position
        case priority
        case updated
        case created
        case title

        public var displayName: String {
            switch self {
            case .position: return "Default"
            case .priority: return "Priority"
            case .updated: return "Updated"
            case .created: return "Created"
            case .title: return "Title"
            }
        }
    }

    public static let pageSize = 50
    public let loader = PaginatedLoader<Issue>()
    public var viewMode: ViewMode = .list
    public var showCreateSheet = false
    public var lastError: Error?
    public var priorityFilter: IssuePriority?
    public var isSelectionMode = false
    public var isLoadingBatchAssignees = false
    public private(set) var batchAssigneeOptions: [IssueAssigneeOption] = []
    public private(set) var selectedIssueIds: Set<String> = []
    public private(set) var sortOption: SortOption = .position
    public private(set) var issuesByStatus: [IssueStatus: [Issue]] = [:]
    public private(set) var childProgressByParentIssueId: [String: ChildIssueProgressEntry] = [:]

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
                    priority: priorityFilter,
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

    public func setSortOption(_ option: SortOption) {
        sortOption = option
        syncFlatIssues()
    }

    public func setPriorityFilter(_ priority: IssuePriority?) async {
        priorityFilter = priority
        await refresh()
    }

    public func toggleSelection(issueId: String) {
        if selectedIssueIds.contains(issueId) {
            selectedIssueIds.remove(issueId)
        } else {
            selectedIssueIds.insert(issueId)
        }
        if selectedIssueIds.isEmpty {
            isSelectionMode = false
        }
    }

    public func clearSelection() {
        selectedIssueIds.removeAll()
        isSelectionMode = false
    }

    public func batchUpdateSelected(
        status: IssueStatus? = nil,
        priority: IssuePriority? = nil,
        assigneeType: String? = nil,
        assigneeId: String? = nil
    ) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before updating Issues.")
            return
        }
        let ids = selectedIssueIds.sorted()
        guard !ids.isEmpty else { return }
        do {
            _ = try await api.batchUpdateIssues(
                ids: ids,
                workspaceId: workspaceId,
                status: status,
                priority: priority,
                assigneeType: assigneeType,
                assigneeId: assigneeId
            )
            applyBatchUpdate(ids: Set(ids), status: status, priority: priority, assigneeType: assigneeType, assigneeId: assigneeId)
            clearSelection()
            lastError = nil
            for id in ids {
                await DataStore.shared.invalidateIssue(id)
            }
        } catch {
            lastError = error
        }
    }

    public func loadBatchAssigneeOptions() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before updating Issues.")
            return
        }
        guard !isLoadingBatchAssignees else { return }

        isLoadingBatchAssignees = true
        defer { isLoadingBatchAssignees = false }

        do {
            async let members = api.listMembers(workspaceId: workspaceId)
            async let agents = api.listAgents(workspaceId: workspaceId)

            let loadedMembers = try await members
            let loadedAgents = try await agents
            batchAssigneeOptions = loadedMembers.map {
                IssueAssigneeOption(
                    id: "member:\($0.userId)",
                    type: "member",
                    assigneeId: $0.userId,
                    displayName: $0.name,
                    subtitle: $0.email
                )
            } + loadedAgents.map {
                IssueAssigneeOption(
                    id: "agent:\($0.id)",
                    type: "agent",
                    assigneeId: $0.id,
                    displayName: $0.name,
                    subtitle: "Agent"
                )
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func batchAssignSelected(optionId: String) async {
        if batchAssigneeOptions.isEmpty {
            await loadBatchAssigneeOptions()
        }
        guard let option = batchAssigneeOptions.first(where: { $0.id == optionId }) else { return }
        await batchUpdateSelected(assigneeType: option.type, assigneeId: option.assigneeId)
    }

    public func batchDeleteSelected() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before updating Issues.")
            return
        }
        let ids = selectedIssueIds.sorted()
        guard !ids.isEmpty else { return }
        do {
            _ = try await api.batchDeleteIssues(ids: ids, workspaceId: workspaceId)
            removeIssues(withIds: Set(ids))
            clearSelection()
            lastError = nil
            for id in ids {
                await DataStore.shared.invalidateIssue(id)
            }
        } catch {
            lastError = error
        }
    }

    public func updateStatus(issueId: String, to status: IssueStatus) async {
        guard let wsId = authSession.currentWorkspace?.id else {
            lastError = UserVisibleError("Pick a workspace before updating Issues.")
            return
        }
        do {
            let updated = try await api.updateIssue(id: issueId, workspaceId: wsId, status: status)
            replaceIssue(updated)
            lastError = nil
            await DataStore.shared.invalidateIssue(issueId)
        } catch {
            lastError = error
        }
    }

    public func issues(for status: IssueStatus) -> [Issue] {
        sorted(issuesByStatus[status] ?? [])
    }

    public func childProgressText(for issue: Issue) -> String? {
        guard let progress = childProgressByParentIssueId[issue.id], progress.total > 0 else {
            return nil
        }
        return "\(progress.done)/\(progress.total)"
    }

    private func loadFirstPages(workspaceId: String) async throws {
        resetBuckets()
        for status in IssueStatus.boardCases {
            let page = try await api.listIssues(
                workspaceId: workspaceId,
                status: status,
                priority: priorityFilter,
                limit: Self.pageSize,
                offset: 0
            )
            append(page, for: status)
        }
        try await loadChildProgress(workspaceId: workspaceId)
        hasLoadedFirstPages = true
        syncFlatIssues()
    }

    private func loadChildProgress(workspaceId: String) async throws {
        let response = try await api.getChildIssueProgress(workspaceId: workspaceId)
        childProgressByParentIssueId = Dictionary(
            uniqueKeysWithValues: response.progress.map { ($0.parentIssueId, $0) }
        )
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
        let issues = IssueStatus.boardCases.flatMap { issuesByStatus[$0] ?? [] }
        loader.items = sorted(issues)
        loader.hasMore = IssueStatus.boardCases.contains { statusHasMore($0) }
    }

    private func replaceIssue(_ issue: Issue) {
        let previousStatus = IssueStatus.boardCases.first { status in
            issuesByStatus[status]?.contains { $0.id == issue.id } == true
        }

        for status in IssueStatus.boardCases {
            issuesByStatus[status]?.removeAll { $0.id == issue.id }
        }
        if IssueStatus.boardCases.contains(issue.status) {
            issuesByStatus[issue.status, default: []].append(issue)
        }
        reconcilePaginationAfterReplacingIssue(from: previousStatus, to: issue.status)
        syncFlatIssues()
    }

    private func applyBatchUpdate(
        ids: Set<String>,
        status: IssueStatus?,
        priority: IssuePriority?,
        assigneeType: String?,
        assigneeId: String?
    ) {
        var patched: [Issue] = []
        for bucketStatus in IssueStatus.boardCases {
            let existing = issuesByStatus[bucketStatus] ?? []
            issuesByStatus[bucketStatus] = existing.compactMap { issue in
                guard ids.contains(issue.id) else { return issue }
                patched.append(
                    issue.replacing(
                        status: status ?? issue.status,
                        priority: priority ?? issue.priority,
                        assigneeType: assigneeType ?? issue.assigneeType,
                        assigneeId: assigneeId ?? issue.assigneeId
                    )
                )
                return nil
            }
        }
        for issue in patched where IssueStatus.boardCases.contains(issue.status) {
            issuesByStatus[issue.status, default: []].append(issue)
        }
        resetPaginationCountsFromBuckets()
        syncFlatIssues()
    }

    private func removeIssues(withIds ids: Set<String>) {
        for status in IssueStatus.boardCases {
            issuesByStatus[status]?.removeAll { ids.contains($0.id) }
        }
        resetPaginationCountsFromBuckets()
        syncFlatIssues()
    }

    private func resetPaginationCountsFromBuckets() {
        for status in IssueStatus.boardCases {
            let count = issuesByStatus[status, default: []].count
            offsetsByStatus[status] = count
            totalsByStatus[status] = count
            pageHasMoreByStatus[status] = false
        }
    }

    private func reconcilePaginationAfterReplacingIssue(from previousStatus: IssueStatus?, to newStatus: IssueStatus) {
        var affectedStatuses = Set<IssueStatus>()
        if let previousStatus {
            affectedStatuses.insert(previousStatus)
        }
        if IssueStatus.boardCases.contains(newStatus) {
            affectedStatuses.insert(newStatus)
        }

        for status in affectedStatuses {
            offsetsByStatus[status] = issuesByStatus[status, default: []].count
        }

        guard let previousStatus, previousStatus != newStatus else { return }
        if let total = totalsByStatus[previousStatus] {
            totalsByStatus[previousStatus] = max(0, total - 1)
        }
        if IssueStatus.boardCases.contains(newStatus), let total = totalsByStatus[newStatus] {
            totalsByStatus[newStatus] = total + 1
        }
    }

    private func sorted(_ issues: [Issue]) -> [Issue] {
        switch sortOption {
        case .position:
            return issues
        case .priority:
            return issues.sorted { lhs, rhs in
                if lhs.priority.sortRank == rhs.priority.sortRank {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
        case .updated:
            return issues.sorted { $0.updatedAt > $1.updatedAt }
        case .created:
            return issues.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return issues.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
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
        childProgressByParentIssueId = [:]
        offsetsByStatus = [:]
        totalsByStatus = [:]
        pageHasMoreByStatus = [:]
    }
}

private extension IssuePriority {
    var sortRank: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .noPriority: return 4
        case .unknown: return 5
        }
    }
}

private extension Issue {
    func replacing(
        status: IssueStatus,
        priority: IssuePriority,
        assigneeType: String?,
        assigneeId: String?
    ) -> Issue {
        Issue(
            id: id,
            identifier: identifier,
            number: number,
            title: title,
            description: description,
            status: status,
            priority: priority,
            assigneeId: assigneeId,
            assigneeType: assigneeType,
            parentIssueId: parentIssueId,
            projectId: projectId,
            workspaceId: workspaceId,
            dueDate: dueDate,
            attachments: attachments,
            labels: labels,
            reactions: reactions,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
