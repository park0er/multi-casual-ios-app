import Foundation
import Observation

@Observable
public final class APIClient: @unchecked Sendable {
    public enum APIError: Error, @unchecked Sendable {
        case unauthorized
        case notFound
        case serverError(Int, body: String)
        case decodingError(underlying: Error, body: String)
        case networkError(Error)
    }

    private let session: URLSession
    private let baseURL: URL
    private var tokenProvider: @Sendable () -> String?

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
        token: String? = nil,
        tokenProvider: (@Sendable () -> String?)? = nil
    ) {
        self.session = session
        self.baseURL = baseURL
        if let token {
            self.tokenProvider = { token }
        } else {
            self.tokenProvider = tokenProvider ?? { nil }
        }
    }

    /// Reconfigure the token provider after initial construction.
    /// Used by the app root to wire the environment-injected APIClient to AuthSession.
    public func configure(authSession: AuthSession) {
        self.tokenProvider = { authSession.token() }
    }

    // MARK: - Core request

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
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
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try APIClient.encoder.encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(-1, body: "Non-HTTP response: \(response)")
        }
        switch http.statusCode {
        case 200...299: break
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode, body: body)
        }

        do {
            return try APIClient.decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
            throw APIError.decodingError(underlying: error, body: body)
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
        let dueDate: String?
        enum CodingKeys: String, CodingKey {
            case title, description, status, priority
            case workspaceId = "workspace_id"
            case assigneeType = "assignee_type"
            case assigneeId = "assignee_id"
            case projectId = "project_id"
            case dueDate = "due_date"
        }
    }

    public func listIssues(workspaceId: String, limit: Int = 50, offset: Int = 0) async throws -> PageResponse<Issue> {
        try await request("GET", path: "api/issues", queryItems: [
            .init(name: "workspace_id", value: workspaceId),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
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
        dueDate: String? = nil
    ) async throws -> Issue {
        try await request("POST", path: "api/issues",
                          body: CreateIssueRequest(
                            title: title,
                            description: description,
                            workspaceId: workspaceId,
                            status: status,
                            priority: priority,
                            assigneeType: assigneeType,
                            assigneeId: assigneeId,
                            projectId: projectId,
                            dueDate: dueDate
                          ))
    }

    public func listComments(issueId: String, workspaceId: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> PageResponse<Comment> {
        try await request("GET", path: "api/issues/\(issueId)/comments", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ] + workspaceQuery(workspaceId))
    }

    private struct AddCommentRequest: Encodable {
        let content: String
        let parentId: String?
        enum CodingKeys: String, CodingKey { case content; case parentId = "parent_id" }
    }

    public func addComment(issueId: String, content: String, parentId: String? = nil, workspaceId: String? = nil) async throws -> Comment {
        try await request("POST", path: "api/issues/\(issueId)/comments",
                          queryItems: workspaceQuery(workspaceId),
                          body: AddCommentRequest(content: content, parentId: parentId))
    }

    public func listAgentRuns(issueId: String, workspaceId: String? = nil) async throws -> [AgentTask] {
        try await request("GET", path: "api/issues/\(issueId)/task-runs", queryItems: workspaceQuery(workspaceId))
    }

    public func listRunMessages(taskId: String) async throws -> [TaskMessage] {
        try await request("GET", path: "api/tasks/\(taskId)/messages")
    }

    // MARK: - Workspace people and agents

    public func listMembers(workspaceId: String) async throws -> [WorkspaceMember] {
        try await request("GET", path: "api/workspaces/\(workspaceId)/members")
    }

    public func listAgents(workspaceId: String) async throws -> [Agent] {
        try await request("GET", path: "api/agents", queryItems: workspaceQuery(workspaceId))
    }

    // MARK: - Inbox

    public func listInbox(limit: Int = 50, offset: Int = 0) async throws -> PageResponse<InboxItem> {
        try await request("GET", path: "api/inbox", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
    }

    public func markInboxRead(id: String) async throws -> InboxItem {
        try await request("POST", path: "api/inbox/\(id)/read")
    }

    public func archiveInbox(id: String) async throws -> InboxItem {
        try await request("POST", path: "api/inbox/\(id)/archive")
    }

    // MARK: - Projects

    public func listProjects(workspaceId: String, limit: Int = 50, offset: Int = 0) async throws -> PageResponse<Project> {
        try await request("GET", path: "api/projects", queryItems: [
            .init(name: "workspace_id", value: workspaceId),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
    }

    public func getProject(id: String) async throws -> Project {
        try await request("GET", path: "api/projects/\(id)")
    }

    public func listProjectResources(projectId: String) async throws -> PageResponse<ProjectResource> {
        try await request("GET", path: "api/projects/\(projectId)/resources")
    }

    private func workspaceQuery(_ workspaceId: String?) -> [URLQueryItem] {
        guard let workspaceId, !workspaceId.isEmpty else { return [] }
        return [.init(name: "workspace_id", value: workspaceId)]
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
