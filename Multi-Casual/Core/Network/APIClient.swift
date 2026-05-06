import Foundation
import Observation

@Observable
public final class APIClient: @unchecked Sendable {
    public struct CountResponse: Codable, Sendable {
        public let count: Int
    }

    public struct BatchUpdateIssuesResponse: Codable, Sendable {
        public let updated: Int
    }

    public struct BatchDeleteIssuesResponse: Codable, Sendable {
        public let deleted: Int
    }

    public enum APIError: Error, @unchecked Sendable {
        case unauthorized
        case notFound
        case serverError(Int, body: String)
        case decodingError(underlying: Error, body: String)
        case networkError(Error)
        case timeout
    }

    private let session: URLSession
    private let baseURL: URL
    private let requestTimeoutNanoseconds: UInt64
    private var tokenProvider: @Sendable () -> String?
    private var workspaceSlugProvider: @Sendable () async -> String?

    /// Shared decoder — ISO8601 dates, single allocation across all requests.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Shared encoder — single allocation across all requests.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // Production init: token provider runs off the main actor because
    // AuthSession.token() is nonisolated (Keychain access is thread-safe).
    public convenience init(authSession: AuthSession) {
        self.init(
            session: .shared,
            tokenProvider: { authSession.token() }
        )
    }

    // Test/flexible init
    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.multica.ai")!,
        requestTimeout: TimeInterval = 15,
        token: String? = nil,
        tokenProvider: (@Sendable () -> String?)? = nil,
        workspaceSlugProvider: (@Sendable () async -> String?)? = nil
    ) {
        self.session = session
        self.baseURL = baseURL
        self.requestTimeoutNanoseconds = UInt64(requestTimeout * 1_000_000_000)
        if let token {
            self.tokenProvider = { token }
        } else {
            self.tokenProvider = tokenProvider ?? { nil }
        }
        self.workspaceSlugProvider = workspaceSlugProvider ?? { nil }
    }

    /// Reconfigure the token provider after initial construction.
    /// Used by the app root to wire the environment-injected APIClient to AuthSession.
    public func configure(authSession: AuthSession) {
        self.tokenProvider = { authSession.token() }
        self.workspaceSlugProvider = { await MainActor.run { authSession.currentWorkspace?.slug } }
    }

    // MARK: - Core request

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.serverError(-1, body: "Invalid base URL: \(baseURL) + \(path)")
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else {
            throw APIError.serverError(-1, body: "Invalid URL components for path \(path)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        req.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        req.setValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "debug",
                     forHTTPHeaderField: "X-Client-Version")
        req.setValue(ProcessInfo.processInfo.operatingSystemVersionString, forHTTPHeaderField: "X-Client-OS")
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let workspaceSlug = await workspaceSlugProvider(), !workspaceSlug.isEmpty {
            req.setValue(workspaceSlug, forHTTPHeaderField: "X-Workspace-Slug")
        }
        for (field, value) in headers where !value.isEmpty {
            req.setValue(value, forHTTPHeaderField: field)
        }
        if let body {
            req.httpBody = try APIClient.encoder.encode(body)
        }

        #if DEBUG
        let debugNetworkLog = ProcessInfo.processInfo.environment["MULTICA_DEBUG_NETWORK_LOG"] == "1"
        if debugNetworkLog {
            NSLog("MulticaAPI request \(method) \(url.path) query=\(url.query ?? "") headers=\(headers.keys.sorted().joined(separator: ","))")
        }
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await responseData(for: req)
        } catch {
            if let apiError = error as? APIError {
                throw apiError
            }
            #if DEBUG
            if debugNetworkLog {
                NSLog("MulticaAPI network error \(method) \(url.path): \(error.localizedDescription)")
            }
            #endif
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(-1, body: "Non-HTTP response: \(response)")
        }
        #if DEBUG
        if debugNetworkLog {
            NSLog("MulticaAPI response \(method) \(url.path) status=\(http.statusCode) bytes=\(data.count)")
        }
        #endif
        switch http.statusCode {
        case 200...299: break
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode, body: body)
        }

        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try APIClient.decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
            throw APIError.decodingError(underlying: error, body: body)
        }
    }

    private func responseData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask { [session] in
                try await session.data(for: request)
            }
            group.addTask { [requestTimeoutNanoseconds] in
                try await Task.sleep(nanoseconds: requestTimeoutNanoseconds)
                throw APIError.timeout
            }

            guard let result = try await group.next() else {
                group.cancelAll()
                throw APIError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Auth endpoints

    private struct SendCodeRequest: Encodable { let email: String }
    private struct VerifyCodeRequest: Encodable { let email: String; let code: String }
    private struct TokenResponse: Decodable { let token: String }
    private struct EmptyResponse: Decodable {}
    private struct RegisterPushTokenRequest: Encodable {
        let token: String
        let platform: String = "apns"
    }
    private struct SkillMutationRequest: Encodable {
        let name: String
        let description: String
        let content: String
    }
    private struct SkillImportRequest: Encodable {
        let url: String
    }
    private struct CreateAutopilotRequest: Encodable {
        let title: String
        let description: String?
        let assigneeId: String
        let executionMode: String
        let issueTitleTemplate: String?

        enum CodingKeys: String, CodingKey {
            case title, description
            case assigneeId = "assignee_id"
            case executionMode = "execution_mode"
            case issueTitleTemplate = "issue_title_template"
        }
    }
    private struct UpdateAutopilotRequest: Encodable {
        let title: String
        let description: String?
        let assigneeId: String
        let status: String
        let executionMode: String
        let issueTitleTemplate: String?

        enum CodingKeys: String, CodingKey {
            case title, description, status
            case assigneeId = "assignee_id"
            case executionMode = "execution_mode"
            case issueTitleTemplate = "issue_title_template"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try encodeNullable(description, to: &container, forKey: .description)
            try container.encode(assigneeId, forKey: .assigneeId)
            try container.encode(status, forKey: .status)
            try container.encode(executionMode, forKey: .executionMode)
            try encodeNullable(issueTitleTemplate, to: &container, forKey: .issueTitleTemplate)
        }

        private func encodeNullable<Value: Encodable>(
            _ value: Value?,
            to container: inout KeyedEncodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) throws {
            if let value {
                try container.encode(value, forKey: key)
            } else {
                try container.encodeNil(forKey: key)
            }
        }
    }
    private struct CreateProjectRequest: Encodable {
        let title: String
        let description: String?
        let status: ProjectStatus
        let priority: IssuePriority
        let icon: String?
        let leadType: String?
        let leadId: String?
        let resources: [CreateProjectResourceRequest]?

        enum CodingKeys: String, CodingKey {
            case title, description, status, priority, icon, resources
            case leadType = "lead_type"
            case leadId = "lead_id"
        }
    }

    private struct CreateProjectResourceRequest: Encodable {
        let resourceType: String
        let resourceRef: [String: JSONValue]

        enum CodingKeys: String, CodingKey {
            case resourceType = "resource_type"
            case resourceRef = "resource_ref"
        }
    }

    private struct UpdateProjectRequest: Encodable {
        let title: String
        let description: String?
        let status: ProjectStatus
        let priority: IssuePriority
        let icon: String?
        let leadType: String?
        let leadId: String?

        enum CodingKeys: String, CodingKey {
            case title, description, status, priority, icon
            case leadType = "lead_type"
            case leadId = "lead_id"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            if let description {
                try container.encode(description, forKey: .description)
            } else {
                try container.encodeNil(forKey: .description)
            }
            try container.encode(status, forKey: .status)
            try container.encode(priority, forKey: .priority)
            if let icon {
                try container.encode(icon, forKey: .icon)
            } else {
                try container.encodeNil(forKey: .icon)
            }
            if let leadType {
                try container.encode(leadType, forKey: .leadType)
            } else {
                try container.encodeNil(forKey: .leadType)
            }
            if let leadId {
                try container.encode(leadId, forKey: .leadId)
            } else {
                try container.encodeNil(forKey: .leadId)
            }
        }
    }
    private struct CreatePinRequest: Encodable {
        let itemType: PinnedItemType
        let itemId: String

        enum CodingKeys: String, CodingKey {
            case itemType = "item_type"
            case itemId = "item_id"
        }
    }
    private struct CreateAutopilotTriggerRequest: Encodable {
        let kind: String
        let cronExpression: String?
        let timezone: String?
        let label: String?

        enum CodingKeys: String, CodingKey {
            case kind, timezone, label
            case cronExpression = "cron_expression"
        }
    }
    private struct UpdateAutopilotTriggerRequest: Encodable {
        let enabled: Bool?
        let cronExpression: String?
        let timezone: String?
        let label: String?

        enum CodingKeys: String, CodingKey {
            case enabled, timezone, label
            case cronExpression = "cron_expression"
        }
    }

    public struct AgentCancelResponse: Codable, Sendable {
        public let count: Int

        enum CodingKeys: String, CodingKey {
            case count = "cancelled"
        }
    }

    private struct ActiveTasksResponse: Codable, Sendable {
        let tasks: [AgentTask]
    }

    public func sendCode(email: String) async throws {
        let _: EmptyResponse = try await request("POST", path: "auth/send-code",
                                                  body: SendCodeRequest(email: email))
    }

    public func verifyCode(email: String, code: String) async throws -> String {
        let resp: TokenResponse = try await request("POST", path: "auth/verify-code",
                                                     body: VerifyCodeRequest(email: email, code: code))
        return resp.token
    }

    public func getMe() async throws -> User {
        try await request("GET", path: "api/me")
    }

    // GET /api/workspaces returns a bare JSON array, not an object wrapper.
    // Confirmed via desktop client consumer and real response body (PAR-72).
    public func listWorkspaces() async throws -> [Workspace] {
        try await request("GET", path: "api/workspaces")
    }

    public func registerPushToken(_ token: String) async throws {
        let _: EmptyResponse = try await request("PUT", path: "api/devices/push-token",
                                                  body: RegisterPushTokenRequest(token: token))
    }

    // MARK: - Issues

    private struct CreateIssueRequest: Encodable {
        let title: String
        let description: String?
        let workspaceId: String
        let status: IssueStatus?
        let priority: IssuePriority?
        let assigneeType: String?
        let assigneeId: String?
        let projectId: String?
        let parentIssueId: String?
        let dueDate: String?
        enum CodingKeys: String, CodingKey {
            case title, description, status, priority
            case workspaceId = "workspace_id"
            case assigneeType = "assignee_type"
            case assigneeId = "assignee_id"
            case projectId = "project_id"
            case parentIssueId = "parent_issue_id"
            case dueDate = "due_date"
        }
    }

    private struct UpdateIssueRequest: Encodable {
        let status: IssueStatus?
        let priority: IssuePriority?
    }

    private struct BatchIssueUpdates: Encodable {
        let status: IssueStatus?
        let priority: IssuePriority?
        let assigneeType: String?
        let assigneeId: String?

        enum CodingKeys: String, CodingKey {
            case status, priority
            case assigneeType = "assignee_type"
            case assigneeId = "assignee_id"
        }
    }

    private struct BatchUpdateIssuesRequest: Encodable {
        let issueIds: [String]
        let updates: BatchIssueUpdates

        enum CodingKeys: String, CodingKey {
            case issueIds = "issue_ids"
            case updates
        }
    }

    private struct BatchDeleteIssuesRequest: Encodable {
        let issueIds: [String]

        enum CodingKeys: String, CodingKey {
            case issueIds = "issue_ids"
        }
    }

    private struct UpdateIssueDetailsRequest: Encodable {
        let title: String
        let description: String?
        let status: IssueStatus
        let priority: IssuePriority
        let assigneeType: String?
        let assigneeId: String?
        let projectId: String?
        let dueDate: String?

        enum CodingKeys: String, CodingKey {
            case title, description, status, priority
            case assigneeType = "assignee_type"
            case assigneeId = "assignee_id"
            case projectId = "project_id"
            case dueDate = "due_date"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try encodeNullable(description, to: &container, forKey: .description)
            try container.encode(status, forKey: .status)
            try container.encode(priority, forKey: .priority)
            try encodeNullable(assigneeType, to: &container, forKey: .assigneeType)
            try encodeNullable(assigneeId, to: &container, forKey: .assigneeId)
            try encodeNullable(projectId, to: &container, forKey: .projectId)
            try encodeNullable(dueDate, to: &container, forKey: .dueDate)
        }

        private func encodeNullable<Value: Encodable>(
            _ value: Value?,
            to container: inout KeyedEncodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) throws {
            if let value {
                try container.encode(value, forKey: key)
            } else {
                try container.encodeNil(forKey: key)
            }
        }
    }

    public func listIssues(
        workspaceId: String,
        status: IssueStatus? = nil,
        priority: IssuePriority? = nil,
        projectId: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> PageResponse<Issue> {
        var queryItems: [URLQueryItem] = [
            .init(name: "workspace_id", value: workspaceId),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ]
        if let status {
            queryItems.append(.init(name: "status", value: status.rawValue))
        }
        if let priority {
            queryItems.append(.init(name: "priority", value: priority.rawValue))
        }
        if let projectId {
            queryItems.append(.init(name: "project_id", value: projectId))
        }
        return try await request("GET", path: "api/issues", queryItems: queryItems)
    }

    public func getIssue(id: String, workspaceId: String? = nil) async throws -> Issue {
        try await request("GET", path: "api/issues/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func createIssue(
        title: String,
        description: String?,
        workspaceId: String,
        status: IssueStatus? = nil,
        priority: IssuePriority? = nil,
        assigneeType: String? = nil,
        assigneeId: String? = nil,
        projectId: String? = nil,
        parentIssueId: String? = nil,
        dueDate: String? = nil
    ) async throws -> Issue {
        try await request("POST", path: "api/issues",
                          queryItems: workspaceQuery(workspaceId),
                          body: CreateIssueRequest(
                            title: title,
                            description: description,
                            workspaceId: workspaceId,
                            status: status,
                            priority: priority,
                            assigneeType: assigneeType,
                            assigneeId: assigneeId,
                            projectId: projectId,
                            parentIssueId: parentIssueId,
                            dueDate: dueDate
                          ))
    }

    public func listComments(issueId: String, workspaceId: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> PageResponse<Comment> {
        let page: PageResponse<Comment> = try await request("GET", path: "api/issues/\(issueId)/comments", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ] + workspaceQuery(workspaceId))
        return page.inferringHasMore(fromOffset: offset)
    }

    private struct AddCommentRequest: Encodable {
        let content: String
        let type: String
        let parentId: String?
        enum CodingKeys: String, CodingKey { case content, type; case parentId = "parent_id" }
    }

    private struct UpdateCommentRequest: Encodable {
        let content: String
    }

    private struct LabelMutationRequest: Encodable {
        let name: String
        let color: String
    }

    private struct AttachLabelRequest: Encodable {
        let labelId: String
        enum CodingKeys: String, CodingKey { case labelId = "label_id" }
    }

    private struct IssueSubscriberMutationRequest: Encodable {
        let userId: String?
        let userType: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case userType = "user_type"
        }
    }

    private struct ReactionRequest: Encodable {
        let emoji: String
    }

    public func addComment(issueId: String, content: String, parentId: String? = nil, workspaceId: String? = nil) async throws -> Comment {
        try await request("POST", path: "api/issues/\(issueId)/comments",
                          queryItems: workspaceQuery(workspaceId),
                          body: AddCommentRequest(content: content, type: "comment", parentId: parentId))
    }

    public func listTimeline(issueId: String, workspaceId: String? = nil) async throws -> [TimelineEntry] {
        try await request("GET", path: "api/issues/\(issueId)/timeline", queryItems: workspaceQuery(workspaceId))
    }

    public func getIssueUsage(issueId: String, workspaceId: String? = nil) async throws -> IssueUsageSummary {
        try await request("GET", path: "api/issues/\(issueId)/usage", queryItems: workspaceQuery(workspaceId))
    }

    public func updateComment(commentId: String, content: String, workspaceId: String? = nil) async throws -> Comment {
        try await request(
            "PUT",
            path: "api/comments/\(commentId)",
            queryItems: workspaceQuery(workspaceId),
            body: UpdateCommentRequest(content: content)
        )
    }

    public func deleteComment(commentId: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/comments/\(commentId)", queryItems: workspaceQuery(workspaceId))
    }

    public func updateIssue(
        id: String,
        workspaceId: String? = nil,
        status: IssueStatus? = nil,
        priority: IssuePriority? = nil
    ) async throws -> Issue {
        try await request(
            "PUT",
            path: "api/issues/\(id)",
            queryItems: workspaceQuery(workspaceId),
            body: UpdateIssueRequest(status: status, priority: priority)
        )
    }

    public func updateIssueDetails(
        id: String,
        workspaceId: String? = nil,
        title: String,
        description: String?,
        status: IssueStatus,
        priority: IssuePriority,
        assigneeType: String?,
        assigneeId: String?,
        projectId: String?,
        dueDate: String?
    ) async throws -> Issue {
        try await request(
            "PUT",
            path: "api/issues/\(id)",
            queryItems: workspaceQuery(workspaceId),
            body: UpdateIssueDetailsRequest(
                title: title,
                description: description,
                status: status,
                priority: priority,
                assigneeType: assigneeType,
                assigneeId: assigneeId,
                projectId: projectId,
                dueDate: dueDate
            )
        )
    }

    public func deleteIssue(id: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/issues/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func batchUpdateIssues(
        ids: [String],
        workspaceId: String? = nil,
        status: IssueStatus? = nil,
        priority: IssuePriority? = nil,
        assigneeType: String? = nil,
        assigneeId: String? = nil
    ) async throws -> BatchUpdateIssuesResponse {
        try await request(
            "POST",
            path: "api/issues/batch-update",
            queryItems: workspaceQuery(workspaceId),
            body: BatchUpdateIssuesRequest(
                issueIds: ids,
                updates: BatchIssueUpdates(
                    status: status,
                    priority: priority,
                    assigneeType: assigneeType,
                    assigneeId: assigneeId
                )
            )
        )
    }

    public func batchDeleteIssues(ids: [String], workspaceId: String? = nil) async throws -> BatchDeleteIssuesResponse {
        try await request(
            "POST",
            path: "api/issues/batch-delete",
            queryItems: workspaceQuery(workspaceId),
            body: BatchDeleteIssuesRequest(issueIds: ids)
        )
    }

    public func listLabels(workspaceId: String? = nil) async throws -> ListLabelsResponse {
        try await request("GET", path: "api/labels", queryItems: workspaceQuery(workspaceId))
    }

    public func getLabel(id: String, workspaceId: String? = nil) async throws -> IssueLabel {
        try await request("GET", path: "api/labels/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func createLabel(name: String, color: String, workspaceId: String? = nil) async throws -> IssueLabel {
        try await request(
            "POST",
            path: "api/labels",
            queryItems: workspaceQuery(workspaceId),
            body: LabelMutationRequest(name: name, color: color)
        )
    }

    public func updateLabel(id: String, name: String, color: String, workspaceId: String? = nil) async throws -> IssueLabel {
        try await request(
            "PUT",
            path: "api/labels/\(id)",
            queryItems: workspaceQuery(workspaceId),
            body: LabelMutationRequest(name: name, color: color)
        )
    }

    public func deleteLabel(id: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/labels/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func listLabelsForIssue(issueId: String, workspaceId: String? = nil) async throws -> IssueLabelsResponse {
        try await request("GET", path: "api/issues/\(issueId)/labels", queryItems: workspaceQuery(workspaceId))
    }

    public func attachLabel(issueId: String, labelId: String, workspaceId: String? = nil) async throws -> IssueLabelsResponse {
        try await request(
            "POST",
            path: "api/issues/\(issueId)/labels",
            queryItems: workspaceQuery(workspaceId),
            body: AttachLabelRequest(labelId: labelId)
        )
    }

    public func detachLabel(issueId: String, labelId: String, workspaceId: String? = nil) async throws -> IssueLabelsResponse {
        try await request("DELETE", path: "api/issues/\(issueId)/labels/\(labelId)", queryItems: workspaceQuery(workspaceId))
    }

    public func listPins(workspaceSlug: String? = nil) async throws -> [PinnedItem] {
        try await request("GET", path: "api/pins", headers: workspaceHeaders(workspaceSlug))
    }

    public func createPin(
        itemType: PinnedItemType,
        itemId: String,
        workspaceSlug: String? = nil
    ) async throws -> PinnedItem {
        try await request(
            "POST",
            path: "api/pins",
            headers: workspaceHeaders(workspaceSlug),
            body: CreatePinRequest(itemType: itemType, itemId: itemId)
        )
    }

    public func deletePin(
        itemType: PinnedItemType,
        itemId: String,
        workspaceSlug: String? = nil
    ) async throws {
        let _: EmptyResponse = try await request(
            "DELETE",
            path: "api/pins/\(itemType.rawValue)/\(itemId)",
            headers: workspaceHeaders(workspaceSlug)
        )
    }

    public func listIssueSubscribers(issueId: String, workspaceId: String? = nil) async throws -> [IssueSubscriber] {
        try await request("GET", path: "api/issues/\(issueId)/subscribers", queryItems: workspaceQuery(workspaceId))
    }

    public func subscribeToIssue(
        issueId: String,
        userId: String? = nil,
        userType: String? = nil,
        workspaceId: String? = nil
    ) async throws {
        let _: EmptyResponse = try await request(
            "POST",
            path: "api/issues/\(issueId)/subscribe",
            queryItems: workspaceQuery(workspaceId),
            body: IssueSubscriberMutationRequest(userId: userId, userType: userType)
        )
    }

    public func unsubscribeFromIssue(
        issueId: String,
        userId: String? = nil,
        userType: String? = nil,
        workspaceId: String? = nil
    ) async throws {
        let _: EmptyResponse = try await request(
            "POST",
            path: "api/issues/\(issueId)/unsubscribe",
            queryItems: workspaceQuery(workspaceId),
            body: IssueSubscriberMutationRequest(userId: userId, userType: userType)
        )
    }

    public func addReaction(commentId: String, emoji: String, workspaceId: String? = nil) async throws -> Reaction {
        try await request(
            "POST",
            path: "api/comments/\(commentId)/reactions",
            queryItems: workspaceQuery(workspaceId),
            body: ReactionRequest(emoji: emoji)
        )
    }

    public func removeReaction(commentId: String, emoji: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request(
            "DELETE",
            path: "api/comments/\(commentId)/reactions",
            queryItems: workspaceQuery(workspaceId),
            body: ReactionRequest(emoji: emoji)
        )
    }

    public func addIssueReaction(issueId: String, emoji: String, workspaceId: String? = nil) async throws -> IssueReaction {
        try await request(
            "POST",
            path: "api/issues/\(issueId)/reactions",
            queryItems: workspaceQuery(workspaceId),
            body: ReactionRequest(emoji: emoji)
        )
    }

    public func removeIssueReaction(issueId: String, emoji: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request(
            "DELETE",
            path: "api/issues/\(issueId)/reactions",
            queryItems: workspaceQuery(workspaceId),
            body: ReactionRequest(emoji: emoji)
        )
    }

    public func listChildIssues(issueId: String, workspaceId: String? = nil) async throws -> [Issue] {
        let response: ChildIssuesResponse = try await request(
            "GET",
            path: "api/issues/\(issueId)/children",
            queryItems: workspaceQuery(workspaceId)
        )
        return response.issues
    }

    public func getChildIssueProgress(workspaceId: String? = nil) async throws -> ChildIssueProgressResponse {
        try await request("GET", path: "api/issues/child-progress", queryItems: workspaceQuery(workspaceId))
    }

    public func listAgentRuns(issueId: String, workspaceId: String? = nil) async throws -> [AgentTask] {
        try await request("GET", path: "api/issues/\(issueId)/task-runs", queryItems: workspaceQuery(workspaceId))
    }

    public func getActiveTasksForIssue(issueId: String, workspaceId: String? = nil) async throws -> [AgentTask] {
        let response: ActiveTasksResponse = try await request(
            "GET",
            path: "api/issues/\(issueId)/active-task",
            queryItems: workspaceQuery(workspaceId)
        )
        return response.tasks
    }

    public func cancelTask(issueId: String, taskId: String, workspaceId: String? = nil) async throws -> AgentTask {
        try await request(
            "POST",
            path: "api/issues/\(issueId)/tasks/\(taskId)/cancel",
            queryItems: workspaceQuery(workspaceId)
        )
    }

    public func listRunMessages(taskId: String, workspaceId: String? = nil) async throws -> [TaskMessage] {
        try await request("GET", path: "api/tasks/\(taskId)/messages", queryItems: workspaceQuery(workspaceId))
    }

    // MARK: - Workspace people and agents

    public func listMembers(workspaceId: String) async throws -> [WorkspaceMember] {
        try await request("GET", path: "api/workspaces/\(workspaceId)/members")
    }

    private struct AgentMutationRequest: Encodable {
        let name: String
        let description: String
        let instructions: String
        let runtimeId: String?
        let visibility: String
        let maxConcurrentTasks: Int
        let model: String

        enum CodingKeys: String, CodingKey {
            case name, description, instructions, visibility, model
            case runtimeId = "runtime_id"
            case maxConcurrentTasks = "max_concurrent_tasks"
        }
    }

    public func listAgents(workspaceId: String, includeArchived: Bool = false) async throws -> [Agent] {
        var queryItems = workspaceQuery(workspaceId)
        if includeArchived {
            queryItems.append(.init(name: "include_archived", value: "true"))
        }
        return try await request("GET", path: "api/agents", queryItems: queryItems)
    }

    public func createAgent(
        name: String,
        description: String,
        instructions: String,
        runtimeId: String,
        visibility: String,
        maxConcurrentTasks: Int,
        model: String,
        workspaceId: String? = nil
    ) async throws -> Agent {
        try await request(
            "POST",
            path: "api/agents",
            queryItems: workspaceQuery(workspaceId),
            body: AgentMutationRequest(
                name: name,
                description: description,
                instructions: instructions,
                runtimeId: runtimeId,
                visibility: visibility,
                maxConcurrentTasks: maxConcurrentTasks,
                model: model
            )
        )
    }

    public func updateAgent(
        id: String,
        name: String,
        description: String,
        instructions: String,
        visibility: String,
        maxConcurrentTasks: Int,
        model: String,
        workspaceId: String? = nil
    ) async throws -> Agent {
        try await request(
            "PUT",
            path: "api/agents/\(id)",
            queryItems: workspaceQuery(workspaceId),
            body: AgentMutationRequest(
                name: name,
                description: description,
                instructions: instructions,
                runtimeId: nil,
                visibility: visibility,
                maxConcurrentTasks: maxConcurrentTasks,
                model: model
            )
        )
    }

    public func archiveAgent(id: String, workspaceId: String? = nil) async throws -> Agent {
        try await request("POST", path: "api/agents/\(id)/archive", queryItems: workspaceQuery(workspaceId))
    }

    public func restoreAgent(id: String, workspaceId: String? = nil) async throws -> Agent {
        try await request("POST", path: "api/agents/\(id)/restore", queryItems: workspaceQuery(workspaceId))
    }

    public func cancelAgentTasks(id: String, workspaceId: String? = nil) async throws -> AgentCancelResponse {
        try await request("POST", path: "api/agents/\(id)/cancel-tasks", queryItems: workspaceQuery(workspaceId))
    }

    public func listRuntimes(workspaceId: String) async throws -> [AgentRuntime] {
        try await request("GET", path: "api/runtimes", queryItems: workspaceQuery(workspaceId))
    }

    public func deleteRuntime(id: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/runtimes/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    // MARK: - Skills

    public func listSkills(workspaceId: String? = nil) async throws -> [Skill] {
        try await request("GET", path: "api/skills", queryItems: workspaceQuery(workspaceId))
    }

    public func getSkill(id: String, workspaceId: String? = nil) async throws -> Skill {
        try await request("GET", path: "api/skills/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func createSkill(name: String, description: String, content: String, workspaceId: String? = nil) async throws -> Skill {
        try await request(
            "POST",
            path: "api/skills",
            queryItems: workspaceQuery(workspaceId),
            body: SkillMutationRequest(name: name, description: description, content: content)
        )
    }

    public func updateSkill(id: String, name: String, description: String, content: String, workspaceId: String? = nil) async throws -> Skill {
        try await request(
            "PUT",
            path: "api/skills/\(id)",
            queryItems: workspaceQuery(workspaceId),
            body: SkillMutationRequest(name: name, description: description, content: content)
        )
    }

    public func importSkill(url: String, workspaceId: String? = nil) async throws -> Skill {
        try await request(
            "POST",
            path: "api/skills/import",
            queryItems: workspaceQuery(workspaceId),
            body: SkillImportRequest(url: url)
        )
    }

    public func deleteSkill(id: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/skills/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    // MARK: - Autopilots

    public func listAutopilots(status: String? = nil, workspaceId: String? = nil) async throws -> ListAutopilotsResponse {
        var queryItems = workspaceQuery(workspaceId)
        if let status, !status.isEmpty {
            queryItems.append(.init(name: "status", value: status))
        }
        return try await request("GET", path: "api/autopilots", queryItems: queryItems)
    }

    public func getAutopilot(id: String, workspaceId: String? = nil) async throws -> GetAutopilotResponse {
        try await request("GET", path: "api/autopilots/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func createAutopilot(
        title: String,
        description: String?,
        assigneeId: String,
        executionMode: String,
        issueTitleTemplate: String?,
        workspaceId: String? = nil
    ) async throws -> Autopilot {
        try await request(
            "POST",
            path: "api/autopilots",
            queryItems: workspaceQuery(workspaceId),
            body: CreateAutopilotRequest(
                title: title,
                description: description,
                assigneeId: assigneeId,
                executionMode: executionMode,
                issueTitleTemplate: issueTitleTemplate
            )
        )
    }

    public func updateAutopilot(
        id: String,
        title: String,
        description: String?,
        assigneeId: String,
        status: String,
        executionMode: String,
        issueTitleTemplate: String?,
        workspaceId: String? = nil
    ) async throws -> Autopilot {
        try await request(
            "PATCH",
            path: "api/autopilots/\(id)",
            queryItems: workspaceQuery(workspaceId),
            body: UpdateAutopilotRequest(
                title: title,
                description: description,
                assigneeId: assigneeId,
                status: status,
                executionMode: executionMode,
                issueTitleTemplate: issueTitleTemplate
            )
        )
    }

    public func deleteAutopilot(id: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "api/autopilots/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func triggerAutopilot(id: String, workspaceId: String? = nil) async throws -> AutopilotRun {
        try await request("POST", path: "api/autopilots/\(id)/trigger", queryItems: workspaceQuery(workspaceId))
    }

    public func listAutopilotRuns(id: String, workspaceId: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> ListAutopilotRunsResponse {
        try await request("GET", path: "api/autopilots/\(id)/runs", queryItems: workspaceQuery(workspaceId) + [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
    }

    public func createAutopilotTrigger(
        autopilotId: String,
        kind: String,
        cronExpression: String?,
        timezone: String?,
        label: String?,
        workspaceId: String? = nil
    ) async throws -> AutopilotTrigger {
        try await request(
            "POST",
            path: "api/autopilots/\(autopilotId)/triggers",
            queryItems: workspaceQuery(workspaceId),
            body: CreateAutopilotTriggerRequest(
                kind: kind,
                cronExpression: cronExpression,
                timezone: timezone,
                label: label
            )
        )
    }

    public func updateAutopilotTrigger(
        autopilotId: String,
        triggerId: String,
        enabled: Bool?,
        cronExpression: String?,
        timezone: String?,
        label: String?,
        workspaceId: String? = nil
    ) async throws -> AutopilotTrigger {
        try await request(
            "PATCH",
            path: "api/autopilots/\(autopilotId)/triggers/\(triggerId)",
            queryItems: workspaceQuery(workspaceId),
            body: UpdateAutopilotTriggerRequest(
                enabled: enabled,
                cronExpression: cronExpression,
                timezone: timezone,
                label: label
            )
        )
    }

    public func deleteAutopilotTrigger(autopilotId: String, triggerId: String, workspaceId: String? = nil) async throws {
        let _: EmptyResponse = try await request(
            "DELETE",
            path: "api/autopilots/\(autopilotId)/triggers/\(triggerId)",
            queryItems: workspaceQuery(workspaceId)
        )
    }

    // MARK: - Inbox

    public func listInbox(workspaceSlug: String? = nil) async throws -> PageResponse<InboxItem> {
        try await request("GET", path: "api/inbox", headers: workspaceHeaders(workspaceSlug))
    }

    public func markInboxRead(id: String, workspaceSlug: String? = nil) async throws -> InboxItem {
        try await request("POST", path: "api/inbox/\(id)/read", headers: workspaceHeaders(workspaceSlug))
    }

    public func archiveInbox(id: String, workspaceSlug: String? = nil) async throws -> InboxItem {
        try await request("POST", path: "api/inbox/\(id)/archive", headers: workspaceHeaders(workspaceSlug))
    }

    public func markAllInboxRead(workspaceSlug: String? = nil) async throws -> CountResponse {
        try await request("POST", path: "api/inbox/mark-all-read", headers: workspaceHeaders(workspaceSlug))
    }

    public func archiveAllInbox(workspaceSlug: String? = nil) async throws -> CountResponse {
        try await request("POST", path: "api/inbox/archive-all", headers: workspaceHeaders(workspaceSlug))
    }

    public func archiveAllReadInbox(workspaceSlug: String? = nil) async throws -> CountResponse {
        try await request("POST", path: "api/inbox/archive-all-read", headers: workspaceHeaders(workspaceSlug))
    }

    public func archiveCompletedInbox(workspaceSlug: String? = nil) async throws -> CountResponse {
        try await request("POST", path: "api/inbox/archive-completed", headers: workspaceHeaders(workspaceSlug))
    }

    // MARK: - Projects

    public func listProjects(workspaceId: String, limit: Int = 50, offset: Int = 0) async throws -> PageResponse<Project> {
        let page: PageResponse<Project> = try await request("GET", path: "api/projects", queryItems: [
            .init(name: "workspace_id", value: workspaceId),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
        return page.inferringHasMore(fromOffset: offset)
    }

    public func getProject(id: String, workspaceId: String? = nil) async throws -> Project {
        try await request("GET", path: "api/projects/\(id)", queryItems: workspaceQuery(workspaceId))
    }

    public func createProject(
        title: String,
        description: String?,
        workspaceId: String,
        status: ProjectStatus,
        priority: IssuePriority,
        icon: String? = nil,
        leadType: String? = nil,
        leadId: String? = nil,
        resourceURLs: [String] = []
    ) async throws -> Project {
        try await request(
            "POST",
            path: "api/projects",
            queryItems: workspaceQuery(workspaceId),
            body: CreateProjectRequest(
                title: title,
                description: description,
                status: status,
                priority: priority,
                icon: icon,
                leadType: leadType,
                leadId: leadId,
                resources: projectResourceRequests(from: resourceURLs)
            )
        )
    }

    public func updateProject(
        id: String,
        workspaceId: String,
        title: String,
        description: String?,
        status: ProjectStatus,
        priority: IssuePriority,
        icon: String? = nil,
        leadType: String? = nil,
        leadId: String? = nil
    ) async throws -> Project {
        try await request(
            "PUT",
            path: "api/projects/\(id)",
            queryItems: workspaceQuery(workspaceId),
            body: UpdateProjectRequest(
                title: title,
                description: description,
                status: status,
                priority: priority,
                icon: icon,
                leadType: leadType,
                leadId: leadId
            )
        )
    }

    public func deleteProject(id: String, workspaceId: String) async throws {
        let _: EmptyResponse = try await request(
            "DELETE",
            path: "api/projects/\(id)",
            queryItems: workspaceQuery(workspaceId)
        )
    }

    public func listProjectResources(projectId: String, workspaceId: String? = nil) async throws -> PageResponse<ProjectResource> {
        try await request("GET", path: "api/projects/\(projectId)/resources", queryItems: workspaceQuery(workspaceId))
    }

    private func projectResourceRequests(from urls: [String]) -> [CreateProjectResourceRequest]? {
        let resources = urls
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map {
                CreateProjectResourceRequest(
                    resourceType: "github_repo",
                    resourceRef: ["url": .string($0)]
                )
            }
        return resources.isEmpty ? nil : resources
    }

    private func workspaceQuery(_ workspaceId: String?) -> [URLQueryItem] {
        guard let workspaceId, !workspaceId.isEmpty else { return [] }
        return [.init(name: "workspace_id", value: workspaceId)]
    }

    private func workspaceHeaders(_ workspaceSlug: String?) -> [String: String] {
        guard let workspaceSlug, !workspaceSlug.isEmpty else { return [:] }
        return ["X-Workspace-Slug": workspaceSlug]
    }
}

// MARK: - Localized error messages

extension APIClient.APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "You're signed out. Please sign in again."
        case .notFound:
            return "The requested resource was not found."
        case .serverError(let status, let body):
            if let decoded = Self.decodeBackendMessage(body) {
                return decoded
            }
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Server error (\(status)). Please try again."
            }
            let preview = trimmed.count > 200 ? String(trimmed.prefix(200)) + "…" : trimmed
            return "Server error (\(status)): \(preview)"
        case .decodingError(let underlying, let body):
            let preview = body.count > 300 ? String(body.prefix(300)) + "…" : body
            let detail = Self.decodingErrorPath(underlying)
            return "Couldn't parse server response\(detail). Raw: \(preview)"
        case .networkError(let error):
            return "Network problem: \(error.localizedDescription)"
        case .timeout:
            return "The server took too long to respond. Please try again."
        }
    }

    private static func decodeBackendMessage(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let s = obj["error"] as? String, !s.isEmpty { return s }
        if let s = obj["message"] as? String, !s.isEmpty { return s }
        return nil
    }

    /// Pull the failing JSON key path out of a Swift `DecodingError` so the
    /// error message points at the exact field that didn't match, e.g.
    /// " (missing key 'name' at user)" or " (type mismatch at workspaces[0].slug)".
    private static func decodingErrorPath(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return "" }
        func path(_ ctx: DecodingError.Context) -> String {
            ctx.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch decodingError {
        case .keyNotFound(let key, let ctx):
            let loc = path(ctx); return " (missing key '\(key.stringValue)'\(loc.isEmpty ? "" : " at \(loc)"))"
        case .typeMismatch(_, let ctx):
            return " (type mismatch at \(path(ctx)))"
        case .valueNotFound(_, let ctx):
            return " (null value at \(path(ctx)))"
        case .dataCorrupted(let ctx):
            let loc = path(ctx); return loc.isEmpty ? " (corrupted body)" : " (corrupted at \(loc))"
        @unknown default:
            return ""
        }
    }
}
