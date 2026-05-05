import XCTest
@testable import MultiCasual

@MainActor
final class IssueDetailViewModelTests: XCTestCase {
    func test_loadMetadata_resolvesAssigneeAndProjectNames() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/issues/i1":
                let json = """
                {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":null,
                 "status":"todo","priority":"none","assignee_id":"a1","assignee_type":"agent",
                 "project_id":"p1","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
                 "updated_at":"2026-01-01T00:00:00Z"}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/workspaces/w1/members":
                return Self.response(for: req, body: Data("[]".utf8))
            case "/api/agents":
                let json = """
                [{"id":"a1","workspace_id":"w1","runtime_id":"r1","name":"Codex",
                  "description":"","instructions":"","avatar_url":null,"runtime_mode":"cloud",
                  "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
                  "visibility":"workspace","status":"active","max_concurrent_tasks":1,
                  "model":"gpt","owner_id":null,"skills":[],"created_at":"2026-01-01T00:00:00Z",
                  "updated_at":"2026-01-01T00:00:00Z","archived_at":null,"archived_by":null}]
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/projects":
                let json = """
                {"projects":[{
                    "id":"p1","workspace_id":"w1","title":"iOS MVP","description":null,
                    "icon":null,"status":"in_progress","priority":"none",
                    "lead_type":null,"lead_id":null,
                    "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z",
                    "issue_count":2,"done_count":1
                }],"total":1}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        await vm.loadIssue()
        await vm.loadMetadata()

        XCTAssertEqual(vm.assigneeDisplayName, "Codex")
        XCTAssertEqual(vm.projectDisplayName, "iOS MVP")
        XCTAssertNil(vm.metadataError)
    }

    func test_loadMetadata_fetchesLinkedProjectByIdWhenNotInFirstProjectsPage() async throws {
        var capturedProjectURL: URL?
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/issues/i1":
                let json = """
                {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":null,
                 "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
                 "project_id":"p51","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
                 "updated_at":"2026-01-01T00:00:00Z"}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/workspaces/w1/members":
                return Self.response(for: req, body: Data("[]".utf8))
            case "/api/agents":
                return Self.response(for: req, body: Data("[]".utf8))
            case "/api/projects":
                return Self.response(for: req, body: #"{"projects":[],"total":51}"#.data(using: .utf8)!)
            case "/api/projects/p51":
                capturedProjectURL = req.url
                let json = """
                {"id":"p51","workspace_id":"w1","title":"Page 2 Project","description":null,
                 "icon":null,"status":"planned","priority":"none",
                 "lead_type":null,"lead_id":null,"created_at":"2026-01-01T00:00:00Z",
                 "updated_at":"2026-01-01T00:00:00Z","issue_count":1,"done_count":0}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        await vm.loadIssue()
        await vm.loadMetadata()

        XCTAssertEqual(vm.projectDisplayName, "Page 2 Project")
        XCTAssertTrue(capturedProjectURL?.absoluteString.contains("workspace_id=w1") ?? false)
        XCTAssertNil(vm.metadataError)
    }

    func test_loadAgentRuns_surfacesEndpointError() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/issues/i1/task-runs")
            return Self.response(for: req, body: Data(#"{"error":"runs unavailable"}"#.utf8), status: 500)
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        await vm.loadAgentRuns()

        XCTAssertTrue(vm.agentRuns.isEmpty)
        XCTAssertEqual(vm.agentRunsError, "runs unavailable")
    }

    func test_loadAgentRuns_marksLoadedForEmptyResponse() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/issues/i1/task-runs")
            return Self.response(for: req, body: Data("[]".utf8))
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        await vm.loadAgentRuns()

        XCTAssertTrue(vm.didLoadAgentRuns)
        XCTAssertTrue(vm.agentRuns.isEmpty)
        XCTAssertNil(vm.agentRunsError)
    }

    func test_loadComments_marksLoadedForEmptyResponse() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/issues/i1/comments")
            return Self.response(for: req, body: Data("[]".utf8))
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        await vm.loadComments()

        XCTAssertTrue(vm.didLoadComments)
        XCTAssertTrue(vm.commentLoader.items.isEmpty)
        XCTAssertNil(vm.commentsError)
    }

    func test_submitComment_appendsCommentAndRefreshesIssueMetadata() async throws {
        var issueFetchCount = 0
        let client = makeClient { req in
            switch (req.httpMethod, req.url?.path) {
            case ("GET", "/api/issues/i1"):
                issueFetchCount += 1
                let updatedAt = issueFetchCount == 1
                    ? "2026-01-01T00:00:00Z"
                    : "2026-01-02T00:00:00Z"
                let json = Self.issueJSON(updatedAt: updatedAt)
                return Self.response(for: req, body: json)
            case ("POST", "/api/issues/i1/comments"):
                let json = """
                {"id":"c1","content":"Ship it","author_id":"u1","author_type":"member",
                 "parent_id":null,"issue_id":"i1","created_at":"2026-01-02T00:00:00Z"}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        await vm.loadIssue()
        vm.commentDraft = "Ship it"
        await vm.submitComment()

        XCTAssertEqual(issueFetchCount, 2)
        XCTAssertEqual(vm.issue?.updatedAt, ISO8601DateFormatter().date(from: "2026-01-02T00:00:00Z"))
        XCTAssertEqual(vm.commentLoader.items.map(\.id), ["c1"])
        XCTAssertEqual(vm.commentDraft, "")
        XCTAssertNil(vm.error)
    }

    func test_submitComment_trimsContentBeforeSending() async throws {
        var submittedContent: String?
        let client = makeClient { req in
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/issues/i1/comments"):
                let body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                submittedContent = body["content"] as? String
                let json = """
                {"id":"c1","content":"Ship it","author_id":"u1","author_type":"member",
                 "parent_id":null,"issue_id":"i1","created_at":"2026-01-02T00:00:00Z"}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case ("GET", "/api/issues/i1"):
                return Self.response(for: req, body: Self.issueJSON(updatedAt: "2026-01-02T00:00:00Z"))
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        vm.commentDraft = " \nShip it\t "
        XCTAssertTrue(vm.canSubmitComment)
        await vm.submitComment()

        XCTAssertEqual(submittedContent, "Ship it")
        XCTAssertEqual(vm.commentDraft, "")
        XCTAssertNil(vm.error)
    }

    func test_submitComment_ignoresWhitespaceOnlyDraft() async throws {
        var requestCount = 0
        let client = makeClient { req in
            requestCount += 1
            XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
            return Self.response(for: req, body: Data("{}".utf8), status: 404)
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        vm.commentDraft = " \n\t "
        XCTAssertFalse(vm.canSubmitComment)
        await vm.submitComment()

        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(vm.commentDraft, " \n\t ")
        XCTAssertFalse(vm.isSubmittingComment)
        XCTAssertNil(vm.error)
    }

    func test_updateStatus_replacesIssueWithServerResponse() async throws {
        let client = makeClient { req in
            switch (req.httpMethod, req.url?.path) {
            case ("GET", "/api/issues/i1"):
                return Self.response(for: req, body: Self.issueJSON(updatedAt: "2026-01-01T00:00:00Z"))
            case ("PUT", "/api/issues/i1"):
                let body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                XCTAssertEqual(body["status"] as? String, "blocked")
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                let json = """
                {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":null,
                 "status":"blocked","priority":"none","assignee_id":null,"assignee_type":null,
                 "project_id":null,"workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
                 "updated_at":"2026-01-02T00:00:00Z"}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = IssueDetailViewModel(issueId: "i1", workspaceId: "w1", api: client)

        await vm.loadIssue()
        await vm.updateStatus(.blocked)

        XCTAssertEqual(vm.issue?.status, .blocked)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isUpdatingIssue)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return APIClient(session: URLSession(configuration: config), token: "test-token")
    }

    private static func response(
        for request: URLRequest,
        body: Data,
        status: Int = 200
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            body
        )
    }

    private static func issueJSON(updatedAt: String) -> Data {
        """
        {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":null,
         "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
         "project_id":null,"workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"\(updatedAt)"}
        """.data(using: .utf8)!
    }
}
