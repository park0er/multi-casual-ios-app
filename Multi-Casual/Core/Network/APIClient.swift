import Foundation
import Observation

@Observable
public final class APIClient: @unchecked Sendable {
    public enum APIError: Error, @unchecked Sendable {
        case unauthorized
        case notFound
        case serverError(Int, body: String)
        case decodingError(Error)
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
            throw APIError.decodingError(error)
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

    private struct WorkspacesResponse: Decodable { let workspaces: [Workspace] }
    public func listWorkspaces() async throws -> [Workspace] {
        let resp: WorkspacesResponse = try await request("GET", path: "api/workspaces")
        return resp.workspaces
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
        enum CodingKeys: String, CodingKey {
            case title, description
            case workspaceId = "workspace_id"
        }
    }

    public func listIssues(workspaceId: String, limit: Int = 50, offset: Int = 0) async throws -> PageResponse<Issue> {
        try await request("GET", path: "api/issues", queryItems: [
            .init(name: "workspace_id", value: workspaceId),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
    }

    public func getIssue(id: String) async throws -> Issue {
        try await request("GET", path: "api/issues/\(id)")
    }

    public func createIssue(title: String, description: String?, workspaceId: String) async throws -> Issue {
        try await request("POST", path: "api/issues",
                          body: CreateIssueRequest(title: title, description: description, workspaceId: workspaceId))
    }

    public func listComments(issueId: String, limit: Int = 50, offset: Int = 0) async throws -> PageResponse<Comment> {
        try await request("GET", path: "api/issues/\(issueId)/comments", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
    }

    private struct AddCommentRequest: Encodable {
        let content: String
        let parentId: String?
        enum CodingKeys: String, CodingKey { case content; case parentId = "parent_id" }
    }

    public func addComment(issueId: String, content: String, parentId: String? = nil) async throws -> Comment {
        try await request("POST", path: "api/issues/\(issueId)/comments",
                          body: AddCommentRequest(content: content, parentId: parentId))
    }

    private struct RunsResponse: Decodable { let runs: [AgentTask] }
    public func listAgentRuns(issueId: String) async throws -> [AgentTask] {
        let resp: RunsResponse = try await request("GET", path: "api/issues/\(issueId)/task-runs")
        return resp.runs
    }

    private struct MessagesResponse: Decodable { let messages: [TaskMessage] }
    public func listRunMessages(taskId: String) async throws -> [TaskMessage] {
        let resp: MessagesResponse = try await request("GET", path: "api/tasks/\(taskId)/messages")
        return resp.messages
    }

    // MARK: - Inbox

    public func listInbox(limit: Int = 50, offset: Int = 0) async throws -> PageResponse<InboxItem> {
        try await request("GET", path: "api/inbox", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])
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
}
