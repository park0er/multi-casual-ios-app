import XCTest
@testable import MultiCasual

// URLProtocol stub for intercepting requests without a real server
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    static func bodyData(for request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            if bytesRead <= 0 { break }
            data.append(buffer, count: bytesRead)
        }
        return data
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

@MainActor
final class APIClientTests: XCTestCase {
    var client: APIClient!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        client = APIClient(session: session, token: "test-token")
    }

    func test_getMe_decodesUser() async throws {
        let json = """
        {"id":"u1","email":"test@example.com","name":"Test User","avatar_url":null}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let user = try await client.getMe()
        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(user.email, "test@example.com")
    }

    func test_unauthorized_throwsAuthError() async {
        MockURLProtocol.handler = { req in
            return (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await client.getMe()
            XCTFail("Expected error")
        } catch APIClient.APIError.unauthorized {
            // pass
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_listIssues_sendsWorkspaceIdParam() async throws {
        let json = """
        {"issues":[],"has_more":false,"total":0}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        _ = try await client.listIssues(workspaceId: "ws1", limit: 50, offset: 0)
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=ws1") ?? false)
        XCTAssertTrue(capturedURL?.absoluteString.contains("limit=50") ?? false)
    }

    func test_listIssues_sendsStatusParamWhenProvided() async throws {
        let json = """
        {"issues":[],"has_more":false,"total":0}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.listIssues(workspaceId: "ws1", status: .inProgress, limit: 50, offset: 0)

        XCTAssertTrue(capturedURL?.absoluteString.contains("status=in_progress") ?? false)
    }

    func test_getIssue_sendsWorkspaceIdParamWhenProvided() async throws {
        let json = """
        {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":null,
         "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
         "project_id":null,"workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.getIssue(id: "i1", workspaceId: "w1")

        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_createIssue_sendsDesktopCreateFields() async throws {
        let json = """
        {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":"D",
         "status":"backlog","priority":"high","assignee_id":"a1","assignee_type":"agent",
         "project_id":"p1","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/issues")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.createIssue(
            title: "T",
            description: "D",
            workspaceId: "w1",
            status: .backlog,
            priority: .high,
            assigneeType: "agent",
            assigneeId: "a1",
            projectId: "p1",
            dueDate: "2026-05-07T00:00:00Z"
        )

        XCTAssertEqual(body["workspace_id"] as? String, "w1")
        XCTAssertEqual(body["status"] as? String, "backlog")
        XCTAssertEqual(body["priority"] as? String, "high")
        XCTAssertEqual(body["assignee_type"] as? String, "agent")
        XCTAssertEqual(body["assignee_id"] as? String, "a1")
        XCTAssertEqual(body["project_id"] as? String, "p1")
        XCTAssertEqual(body["due_date"] as? String, "2026-05-07T00:00:00Z")
    }

    func test_listInbox_decodesBareArrayResponse() async throws {
        let json = """
        [{
            "id":"n1","workspace_id":"w1","recipient_type":"member","recipient_id":"u1",
            "actor_type":null,"actor_id":null,"type":"new_comment","severity":"attention",
            "issue_id":"i1","title":"PAR-73 updated","body":null,"issue_status":"todo",
            "read":false,"archived":false,"created_at":"2026-01-01T00:00:00Z",
            "details":{"identifier":"PAR-73"}
        }]
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/inbox")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listInbox(workspaceId: "w1")

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.issueTitle, "PAR-73 updated")
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_markInboxRead_usesDesktopReadEndpoint() async throws {
        let json = """
        {"id":"n1","workspace_id":"w1","recipient_type":"member","recipient_id":"u1",
         "actor_type":null,"actor_id":null,"type":"new_comment","severity":"attention",
         "issue_id":"i1","title":"PAR-73 updated","body":null,"issue_status":"todo",
         "read":true,"archived":false,"created_at":"2026-01-01T00:00:00Z",
         "details":{"identifier":"PAR-73"}}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/inbox/n1/read")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let item = try await client.markInboxRead(id: "n1", workspaceId: "w1")

        XCTAssertTrue(item.read)
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_archiveInbox_usesDesktopArchiveEndpoint() async throws {
        let json = """
        {"id":"n1","workspace_id":"w1","recipient_type":"member","recipient_id":"u1",
         "actor_type":null,"actor_id":null,"type":"new_comment","severity":"attention",
         "issue_id":"i1","title":"PAR-73 updated","body":null,"issue_status":"todo",
         "read":true,"archived":true,"created_at":"2026-01-01T00:00:00Z",
         "details":{"identifier":"PAR-73"}}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/inbox/n1/archive")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let item = try await client.archiveInbox(id: "n1", workspaceId: "w1")

        XCTAssertTrue(item.archived)
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_listComments_decodesBareArrayResponse() async throws {
        let json = """
        [{"id":"c1","content":"Hi","author_id":"u1","author_type":"member",
          "parent_id":null,"issue_id":"i1","created_at":"2026-01-01T00:00:00Z"}]
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/issues/i1/comments")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listComments(issueId: "i1", workspaceId: "w1")

        XCTAssertEqual(page.items.map(\.id), ["c1"])
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_addComment_sendsDesktopCommentType() async throws {
        let json = """
        {"id":"c1","content":"Hi","author_id":"u1","author_type":"member",
         "parent_id":null,"issue_id":"i1","created_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
        var capturedURL: URL?
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/issues/i1/comments")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.addComment(issueId: "i1", content: "Hi", workspaceId: "w1")

        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
        XCTAssertEqual(body["content"] as? String, "Hi")
        XCTAssertEqual(body["type"] as? String, "comment")
    }

    func test_listAgentRuns_decodesBareArrayResponse() async throws {
        let json = """
        [{
            "id":"t1","agent_id":"a1","runtime_id":"r1","issue_id":"i1",
            "status":"running","priority":0,"dispatched_at":null,
            "started_at":"2026-01-01T00:00:00Z","completed_at":null,
            "result":null,"error":null,"created_at":"2026-01-01T00:00:00Z"
        }]
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/issues/i1/task-runs")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let runs = try await client.listAgentRuns(issueId: "i1", workspaceId: "w1")

        XCTAssertEqual(runs.map(\.id), ["t1"])
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_listRunMessages_decodesBareArrayResponse() async throws {
        let json = """
        [{"task_id":"t1","issue_id":"i1","seq":7,"type":"text","content":"done"}]
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/tasks/t1/messages")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let messages = try await client.listRunMessages(taskId: "t1")

        XCTAssertEqual(messages.first?.id, "t1:7")
        XCTAssertEqual(messages.first?.seq, 7)
        XCTAssertEqual(messages.first?.content, "done")
    }

    func test_listProjects_decodesProjectsWrapper() async throws {
        let json = """
        {"projects":[{
            "id":"p1","workspace_id":"w1","title":"iOS MVP","description":null,
            "icon":null,"status":"in_progress","priority":"none",
            "lead_type":null,"lead_id":null,
            "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z",
            "issue_count":2,"done_count":1
        }],"total":1}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/projects")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listProjects(workspaceId: "w1")

        XCTAssertEqual(page.total, 1)
        XCTAssertEqual(page.items.first?.name, "iOS MVP")
    }

    func test_listProjectResources_decodesResourcesWrapper() async throws {
        let json = """
        {"resources":[{
            "id":"r1","project_id":"p1","workspace_id":"w1","resource_type":"github_repo",
            "resource_ref":{"url":"https://github.com/multica-ai/multica","default_branch_hint":"main"},
            "label":null,"position":0,"created_at":"2026-01-01T00:00:00Z","created_by":null
        }],"total":1}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/projects/p1/resources")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listProjectResources(projectId: "p1")

        XCTAssertEqual(page.total, 1)
        XCTAssertEqual(page.items.first?.displayTitle, "https://github.com/multica-ai/multica")
    }

    func test_listMembers_decodesWorkspaceMembers() async throws {
        let json = """
        [{"id":"m1","workspace_id":"w1","user_id":"u1","role":"owner",
          "created_at":"2026-01-01T00:00:00Z","name":"Parker",
          "email":"p@example.com","avatar_url":null}]
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/workspaces/w1/members")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let members = try await client.listMembers(workspaceId: "w1")

        XCTAssertEqual(members.first?.name, "Parker")
    }

    func test_listAgents_decodesWorkspaceAgents() async throws {
        let json = """
        [{"id":"a1","workspace_id":"w1","runtime_id":"r1","name":"Codex",
          "description":"","instructions":"","avatar_url":null,"runtime_mode":"cloud",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"active","max_concurrent_tasks":1,
          "model":"gpt","owner_id":null,"skills":[],"created_at":"2026-01-01T00:00:00Z",
          "updated_at":"2026-01-01T00:00:00Z","archived_at":null,"archived_by":null}]
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/agents")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let agents = try await client.listAgents(workspaceId: "w1")

        XCTAssertEqual(agents.first?.name, "Codex")
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_sendCode_usesAuthSendCodePath() async throws {
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedPath = req.url?.path
            return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
        }
        try await client.sendCode(email: "x@y.com")
        XCTAssertEqual(capturedPath, "/auth/send-code",
            "sendCode must not use the /api/ prefix — backend auth endpoints are rooted at /auth/*")
    }

    func test_verifyCode_usesAuthVerifyCodePath() async throws {
        let json = """
        {"token":"t"}
        """.data(using: .utf8)!
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedPath = req.url?.path
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        _ = try await client.verifyCode(email: "x@y.com", code: "123456")
        XCTAssertEqual(capturedPath, "/auth/verify-code")
    }

    // MARK: - APIError LocalizedError

    func test_apiError_unauthorized_localizesToSignOutPrompt() {
        XCTAssertEqual(
            APIClient.APIError.unauthorized.errorDescription,
            "You're signed out. Please sign in again."
        )
    }

    func test_apiError_serverError_withJSONErrorField_surfacesBackendMessage() {
        let body = #"{"error":"Invalid verification code"}"#
        XCTAssertEqual(
            APIClient.APIError.serverError(400, body: body).errorDescription,
            "Invalid verification code"
        )
    }

    func test_apiError_serverError_withPlainText_includesStatusAndPreview() {
        XCTAssertEqual(
            APIClient.APIError.serverError(500, body: "something broke").errorDescription,
            "Server error (500): something broke"
        )
    }

    func test_apiError_serverError_withEmptyBody_fallsBackToGenericMessage() {
        XCTAssertEqual(
            APIClient.APIError.serverError(503, body: "").errorDescription,
            "Server error (503). Please try again."
        )
    }
}
