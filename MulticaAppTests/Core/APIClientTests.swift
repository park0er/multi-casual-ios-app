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

    func test_getMe_sendsDesktopStyleClientHeaders() async throws {
        let json = """
        {"id":"u1","email":"test@example.com","name":"Test User","avatar_url":null}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNotNil(req.value(forHTTPHeaderField: "X-Request-ID"))
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
            XCTAssertNotNil(req.value(forHTTPHeaderField: "X-Client-Version"))
            XCTAssertNotNil(req.value(forHTTPHeaderField: "X-Client-OS"))
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.getMe()
    }

    func test_requestTimeout_surfacesLocalizedAPIError() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        client = APIClient(session: session, requestTimeout: 0.01, token: "test-token")
        MockURLProtocol.handler = { req in
            Thread.sleep(forTimeInterval: 0.2)
            let json = """
            {"id":"u1","email":"test@example.com","name":"Test User","avatar_url":null}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        do {
            _ = try await client.getMe()
            XCTFail("Expected timeout")
        } catch APIClient.APIError.timeout {
            XCTAssertEqual(APIClient.APIError.timeout.localizedDescription, "The server took too long to respond. Please try again.")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
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

    func test_listIssues_sendsProjectIdParamWhenProvided() async throws {
        let json = """
        {"issues":[],"has_more":false,"total":0}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.listIssues(workspaceId: "ws1", projectId: "p1", limit: 50, offset: 0)

        XCTAssertTrue(capturedURL?.absoluteString.contains("project_id=p1") ?? false)
    }

    func test_listIssues_sendsPriorityParamWhenProvided() async throws {
        let json = """
        {"issues":[],"has_more":false,"total":0}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.listIssues(workspaceId: "ws1", priority: .urgent, limit: 50, offset: 0)

        XCTAssertTrue(capturedURL?.absoluteString.contains("priority=urgent") ?? false)
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
         "parent_issue_id":"p0","project_id":"p1","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
        var capturedURL: URL?
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            capturedURL = req.url
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
            parentIssueId: "p0",
            dueDate: "2026-05-07T00:00:00Z"
        )

        XCTAssertEqual(body["workspace_id"] as? String, "w1")
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
        XCTAssertEqual(body["status"] as? String, "backlog")
        XCTAssertEqual(body["priority"] as? String, "high")
        XCTAssertEqual(body["assignee_type"] as? String, "agent")
        XCTAssertEqual(body["assignee_id"] as? String, "a1")
        XCTAssertEqual(body["project_id"] as? String, "p1")
        XCTAssertEqual(body["parent_issue_id"] as? String, "p0")
        XCTAssertEqual(body["due_date"] as? String, "2026-05-07T00:00:00Z")
    }

    func test_childIssueEndpoints_matchDesktopPaths() async throws {
        var requests: [String] = []
        MockURLProtocol.handler = { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch req.url?.path {
            case "/api/issues/i1/children":
                let json = """
                {"issues":[{"id":"c1","identifier":"PAR-2","number":2,"title":"Child","description":null,
                 "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
                 "parent_issue_id":"i1","project_id":null,"workspace_id":"w1",
                 "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]}
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
            case "/api/issues/child-progress":
                let json = #"{"progress":[{"parent_issue_id":"i1","total":3,"done":1}]}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let children = try await client.listChildIssues(issueId: "i1")
        let progress = try await client.getChildIssueProgress()

        XCTAssertEqual(children.map(\.id), ["c1"])
        XCTAssertEqual(children.first?.parentIssueId, "i1")
        XCTAssertEqual(progress.progress.map(\.parentIssueId), ["i1"])
        XCTAssertEqual(progress.progress.first?.done, 1)
        XCTAssertEqual(requests, [
            "GET /api/issues/i1/children",
            "GET /api/issues/child-progress",
        ])
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
            XCTAssertNil(req.url?.query)
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Workspace-Slug"), "park0er")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listInbox(workspaceSlug: "park0er")

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.issueTitle, "PAR-73 updated")
        XCTAssertNil(capturedURL?.query)
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
            XCTAssertNil(req.url?.query)
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Workspace-Slug"), "park0er")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let item = try await client.markInboxRead(id: "n1", workspaceSlug: "park0er")

        XCTAssertTrue(item.read)
        XCTAssertNil(capturedURL?.query)
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
            XCTAssertNil(req.url?.query)
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Workspace-Slug"), "park0er")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let item = try await client.archiveInbox(id: "n1", workspaceSlug: "park0er")

        XCTAssertTrue(item.archived)
        XCTAssertNil(capturedURL?.query)
    }

    func test_markAllInboxRead_usesDesktopBulkEndpoint() async throws {
        let json = #"{"count":3}"#.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/inbox/mark-all-read")
            XCTAssertNil(req.url?.query)
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Workspace-Slug"), "park0er")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let response = try await client.markAllInboxRead(workspaceSlug: "park0er")

        XCTAssertEqual(response.count, 3)
        XCTAssertNil(capturedURL?.query)
    }

    func test_archiveAllInbox_usesDesktopBulkEndpoint() async throws {
        let json = #"{"count":3}"#.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/inbox/archive-all")
            XCTAssertNil(req.url?.query)
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Workspace-Slug"), "park0er")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let response = try await client.archiveAllInbox(workspaceSlug: "park0er")

        XCTAssertEqual(response.count, 3)
        XCTAssertNil(capturedURL?.query)
    }

    func test_archiveAllReadInbox_usesDesktopBulkEndpoint() async throws {
        let json = #"{"count":2}"#.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/inbox/archive-all-read")
            XCTAssertNil(req.url?.query)
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Workspace-Slug"), "park0er")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let response = try await client.archiveAllReadInbox(workspaceSlug: "park0er")

        XCTAssertEqual(response.count, 2)
        XCTAssertNil(capturedURL?.query)
    }

    func test_archiveCompletedInbox_usesDesktopBulkEndpoint() async throws {
        let json = #"{"count":1}"#.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/inbox/archive-completed")
            XCTAssertNil(req.url?.query)
            XCTAssertEqual(req.value(forHTTPHeaderField: "X-Workspace-Slug"), "park0er")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let response = try await client.archiveCompletedInbox(workspaceSlug: "park0er")

        XCTAssertEqual(response.count, 1)
        XCTAssertNil(capturedURL?.query)
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

    func test_listComments_infersHasMoreFromTotalWhenWrapperOmitsFlag() async throws {
        let json = """
        {"comments":[{"id":"c1","content":"Hi","author_id":"u1","author_type":"member",
          "parent_id":null,"issue_id":"i1","created_at":"2026-01-01T00:00:00Z"}],
         "total":2}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/issues/i1/comments")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listComments(issueId: "i1", workspaceId: "w1", limit: 1, offset: 0)

        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.total, 2)
        XCTAssertEqual(page.items.map(\.id), ["c1"])
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

    func test_listTimeline_decodesDesktopActivityEntries() async throws {
        let json = """
        [{"type":"activity","id":"a1","actor_type":"member","actor_id":"u1",
          "created_at":"2026-01-01T00:00:00Z","action":"status_changed",
          "details":{"from":"todo","to":"done"}},
         {"type":"comment","id":"c1","actor_type":"agent","actor_id":"agent1",
          "created_at":"2026-01-02T00:00:00Z","content":"**Done**","parent_id":null,
          "comment_type":"comment"}]
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/issues/i1/timeline")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let entries = try await client.listTimeline(issueId: "i1")

        XCTAssertEqual(capturedURL?.query, nil)
        XCTAssertEqual(entries.map(\.id), ["a1", "c1"])
        XCTAssertEqual(entries.first?.action, "status_changed")
        XCTAssertEqual(entries.first?.detailString("to"), "done")
        XCTAssertEqual(entries.last?.content, "**Done**")
    }

    func test_getIssueUsage_decodesDesktopSummary() async throws {
        let json = """
        {"total_input_tokens":1200,"total_output_tokens":340,
         "total_cache_read_tokens":50,"total_cache_write_tokens":10,
         "task_count":3}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/issues/i1/usage")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let usage = try await client.getIssueUsage(issueId: "i1")

        XCTAssertEqual(usage.taskCount, 3)
        XCTAssertEqual(usage.totalInputTokens, 1_200)
        XCTAssertEqual(usage.totalOutputTokens, 340)
        XCTAssertEqual(usage.totalCacheReadTokens, 50)
        XCTAssertEqual(usage.totalCacheWriteTokens, 10)
    }

    func test_updateIssue_sendsWorkspaceIdAndMutableFields() async throws {
        let json = """
        {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":null,
         "status":"in_review","priority":"urgent","assignee_id":null,"assignee_type":null,
         "project_id":null,"workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-02T00:00:00Z"}
        """.data(using: .utf8)!
        var capturedURL: URL?
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "PUT")
            XCTAssertEqual(req.url?.path, "/api/issues/i1")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let issue = try await client.updateIssue(id: "i1", workspaceId: "w1", status: .inReview, priority: .urgent)

        XCTAssertEqual(issue.status, .inReview)
        XCTAssertEqual(issue.priority, .urgent)
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
        XCTAssertEqual(body["status"] as? String, "in_review")
        XCTAssertEqual(body["priority"] as? String, "urgent")
    }

    func test_deleteIssue_usesDesktopEndpoint() async throws {
        var capturedMethod: String?
        MockURLProtocol.handler = { req in
            capturedMethod = req.httpMethod
            XCTAssertEqual(req.url?.path, "/api/issues/i1")
            return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        try await client.deleteIssue(id: "i1")

        XCTAssertEqual(capturedMethod, "DELETE")
    }

    func test_batchUpdateIssues_usesDesktopEndpointAndBody() async throws {
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/issues/batch-update")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return (
                HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"updated":2}"#.utf8)
            )
        }

        let response = try await client.batchUpdateIssues(
            ids: ["i1", "i2"],
            status: .done,
            priority: .urgent
        )

        XCTAssertEqual(response.updated, 2)
        XCTAssertEqual(body["issue_ids"] as? [String], ["i1", "i2"])
        let updates = body["updates"] as? [String: Any]
        XCTAssertEqual(updates?["status"] as? String, "done")
        XCTAssertEqual(updates?["priority"] as? String, "urgent")
    }

    func test_batchDeleteIssues_usesDesktopEndpointAndBody() async throws {
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/issues/batch-delete")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return (
                HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"deleted":2}"#.utf8)
            )
        }

        let response = try await client.batchDeleteIssues(ids: ["i1", "i2"])

        XCTAssertEqual(response.deleted, 2)
        XCTAssertEqual(body["issue_ids"] as? [String], ["i1", "i2"])
    }

    func test_updateIssueDetails_sendsEditableFieldsAndNulls() async throws {
        let json = """
        {"id":"i1","identifier":"PAR-1","number":1,"title":"Updated","description":null,
         "status":"blocked","priority":"high","assignee_id":null,"assignee_type":null,
         "project_id":null,"due_date":null,"workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-02T00:00:00Z"}
        """.data(using: .utf8)!
        var capturedURL: URL?
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "PUT")
            XCTAssertEqual(req.url?.path, "/api/issues/i1")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let issue = try await client.updateIssueDetails(
            id: "i1",
            workspaceId: "w1",
            title: "Updated",
            description: nil,
            status: .blocked,
            priority: .high,
            assigneeType: nil,
            assigneeId: nil,
            projectId: nil,
            dueDate: nil
        )

        XCTAssertEqual(issue.title, "Updated")
        XCTAssertNil(issue.description)
        XCTAssertNil(issue.assigneeId)
        XCTAssertNil(issue.projectId)
        XCTAssertNil(issue.dueDate)
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
        XCTAssertEqual(body["title"] as? String, "Updated")
        XCTAssertTrue(body.keys.contains("description"))
        XCTAssertTrue(body["description"] is NSNull)
        XCTAssertEqual(body["status"] as? String, "blocked")
        XCTAssertEqual(body["priority"] as? String, "high")
        XCTAssertTrue(body.keys.contains("assignee_type"))
        XCTAssertTrue(body["assignee_type"] is NSNull)
        XCTAssertTrue(body.keys.contains("assignee_id"))
        XCTAssertTrue(body["assignee_id"] is NSNull)
        XCTAssertTrue(body.keys.contains("project_id"))
        XCTAssertTrue(body["project_id"] is NSNull)
        XCTAssertTrue(body.keys.contains("due_date"))
        XCTAssertTrue(body["due_date"] is NSNull)
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

    func test_getActiveTasksForIssue_usesDesktopEndpoint() async throws {
        let json = """
        {"tasks":[{
            "id":"t1","agent_id":"a1","runtime_id":"r1","issue_id":"i1",
            "status":"running","priority":0,"dispatched_at":null,
            "started_at":"2026-01-01T00:00:00Z","completed_at":null,
            "result":null,"error":null,"created_at":"2026-01-01T00:00:00Z"
        }]}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/issues/i1/active-task")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let tasks = try await client.getActiveTasksForIssue(issueId: "i1", workspaceId: "w1")

        XCTAssertEqual(tasks.map(\.id), ["t1"])
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_cancelIssueTask_usesDesktopEndpoint() async throws {
        let json = """
        {"id":"t1","agent_id":"a1","runtime_id":"r1","issue_id":"i1",
         "status":"cancelled","priority":0,"dispatched_at":null,
         "started_at":"2026-01-01T00:00:00Z","completed_at":"2026-01-01T00:01:00Z",
         "result":null,"error":null,"created_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
        var capturedURL: URL?
        var capturedMethod: String?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            capturedMethod = req.httpMethod
            XCTAssertEqual(req.url?.path, "/api/issues/i1/tasks/t1/cancel")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let task = try await client.cancelTask(issueId: "i1", taskId: "t1", workspaceId: "w1")

        XCTAssertEqual(capturedMethod, "POST")
        XCTAssertEqual(task.status, "cancelled")
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_listRunMessages_decodesBareArrayResponse() async throws {
        let json = """
        [{"task_id":"t1","issue_id":"i1","seq":7,"type":"text","content":"done"}]
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/tasks/t1/messages")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let messages = try await client.listRunMessages(taskId: "t1", workspaceId: "w1")

        XCTAssertEqual(messages.first?.id, "t1:7")
        XCTAssertEqual(messages.first?.seq, 7)
        XCTAssertEqual(messages.first?.content, "done")
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
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

    func test_listProjects_infersHasMoreFromTotalWhenWrapperOmitsFlag() async throws {
        let json = """
        {"projects":[{
            "id":"p1","workspace_id":"w1","title":"iOS MVP","description":null,
            "icon":null,"status":"in_progress","priority":"none",
            "lead_type":null,"lead_id":null,
            "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z",
            "issue_count":2,"done_count":1
        }],"total":2}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/projects")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listProjects(workspaceId: "w1", limit: 1, offset: 0)

        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.total, 2)
        XCTAssertEqual(page.items.map(\.id), ["p1"])
    }

    func test_listProjectResources_decodesResourcesWrapper() async throws {
        let json = """
        {"resources":[{
            "id":"r1","project_id":"p1","workspace_id":"w1","resource_type":"github_repo",
            "resource_ref":{"url":"https://github.com/multica-ai/multica","default_branch_hint":"main"},
            "label":null,"position":0,"created_at":"2026-01-01T00:00:00Z","created_by":null
        }],"total":1}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/projects/p1/resources")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let page = try await client.listProjectResources(projectId: "p1", workspaceId: "w1")

        XCTAssertEqual(page.total, 1)
        XCTAssertEqual(page.items.first?.displayTitle, "https://github.com/multica-ai/multica")
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_getProject_sendsWorkspaceIdParamWhenProvided() async throws {
        let json = """
        {"id":"p1","workspace_id":"w1","title":"iOS MVP","description":null,
         "icon":null,"status":"in_progress","priority":"none",
         "lead_type":null,"lead_id":null,"created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z","issue_count":2,"done_count":1}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            XCTAssertEqual(req.url?.path, "/api/projects/p1")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await client.getProject(id: "p1", workspaceId: "w1")

        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=w1") ?? false)
    }

    func test_projectMutationEndpointsUseDesktopPaths() async throws {
        var requests: [(method: String?, path: String, body: [String: Any]?)] = []
        let projectJSON = """
        {"id":"p1","workspace_id":"w1","title":"Edited Project","description":"**Docs**",
         "icon":null,"status":"paused","priority":"high",
         "lead_type":null,"lead_id":null,"created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z","issue_count":0,"done_count":0}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            let body: [String: Any]?
            let data = MockURLProtocol.bodyData(for: req)
            if !data.isEmpty {
                body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            } else {
                body = nil
            }
            requests.append((req.httpMethod, req.url?.path ?? "", body))
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/projects"),
                 ("PUT", "/api/projects/p1"):
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, projectJSON)
            case ("DELETE", "/api/projects/p1"):
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
            }
        }

        _ = try await client.createProject(
            title: "Edited Project",
            description: "**Docs**",
            workspaceId: "w1",
            status: .paused,
            priority: .high
        )
        _ = try await client.updateProject(
            id: "p1",
            workspaceId: "w1",
            title: "Edited Project",
            description: nil,
            status: .paused,
            priority: .high
        )
        try await client.deleteProject(id: "p1", workspaceId: "w1")

        XCTAssertEqual(requests.map(\.method), ["POST", "PUT", "DELETE"])
        XCTAssertEqual(requests.map(\.path), ["/api/projects", "/api/projects/p1", "/api/projects/p1"])
        XCTAssertEqual(requests[0].body?["title"] as? String, "Edited Project")
        XCTAssertEqual(requests[0].body?["description"] as? String, "**Docs**")
        XCTAssertEqual(requests[0].body?["status"] as? String, "paused")
        XCTAssertEqual(requests[0].body?["priority"] as? String, "high")
        XCTAssertTrue(requests[1].body?["description"] is NSNull)
    }

    func test_pinEndpointsUseDesktopPathsAndWorkspaceSlugHeader() async throws {
        var requests: [(method: String?, path: String, workspaceSlug: String?, body: [String: Any]?)] = []
        let pinJSON = """
        {"id":"pin1","workspace_id":"w1","user_id":"u1","item_type":"issue","item_id":"i1",
         "position":1,"created_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            let body: [String: Any]?
            let data = MockURLProtocol.bodyData(for: req)
            if !data.isEmpty {
                body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            } else {
                body = nil
            }
            requests.append((req.httpMethod, req.url?.path ?? "", req.value(forHTTPHeaderField: "X-Workspace-Slug"), body))
            switch (req.httpMethod, req.url?.path) {
            case ("GET", "/api/pins"):
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[\(String(data: pinJSON, encoding: .utf8)!)]".utf8))
            case ("POST", "/api/pins"):
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, pinJSON)
            case ("DELETE", "/api/pins/issue/i1"):
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
            }
        }

        let pins = try await client.listPins(workspaceSlug: "park0er")
        _ = try await client.createPin(itemType: .issue, itemId: "i1", workspaceSlug: "park0er")
        try await client.deletePin(itemType: .issue, itemId: "i1", workspaceSlug: "park0er")

        XCTAssertEqual(pins.first?.itemType, .issue)
        XCTAssertEqual(requests.map(\.method), ["GET", "POST", "DELETE"])
        XCTAssertEqual(requests.map(\.path), ["/api/pins", "/api/pins", "/api/pins/issue/i1"])
        XCTAssertEqual(requests.map(\.workspaceSlug), ["park0er", "park0er", "park0er"])
        XCTAssertEqual(requests[1].body?["item_type"] as? String, "issue")
        XCTAssertEqual(requests[1].body?["item_id"] as? String, "i1")
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

    func test_listAgents_canIncludeArchivedAgents() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/agents")
            XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
            XCTAssertTrue(req.url?.absoluteString.contains("include_archived=true") ?? false)
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }

        let agents = try await client.listAgents(workspaceId: "w1", includeArchived: true)

        XCTAssertTrue(agents.isEmpty)
    }

    func test_createAgent_sendsDesktopFields() async throws {
        var body: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/agents")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            let json = Self.agentJSON(id: "a1", name: "Codex")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let agent = try await client.createAgent(
            name: "Codex",
            description: "Helps with code",
            instructions: "Be concise",
            runtimeId: "r1",
            visibility: "workspace",
            maxConcurrentTasks: 2,
            model: "gpt-5"
        )

        XCTAssertEqual(agent.name, "Codex")
        XCTAssertEqual(body["name"] as? String, "Codex")
        XCTAssertEqual(body["description"] as? String, "Helps with code")
        XCTAssertEqual(body["instructions"] as? String, "Be concise")
        XCTAssertEqual(body["runtime_id"] as? String, "r1")
        XCTAssertEqual(body["visibility"] as? String, "workspace")
        XCTAssertEqual(body["max_concurrent_tasks"] as? Int, 2)
        XCTAssertEqual(body["model"] as? String, "gpt-5")
    }

    func test_updateArchiveRestoreAndCancelAgentUseDesktopEndpoints() async throws {
        var requests: [(String, String)] = []
        MockURLProtocol.handler = { req in
            requests.append((req.httpMethod ?? "", req.url?.path ?? ""))
            let body: Data
            if req.url?.path == "/api/agents/a1/cancel-tasks" {
                body = #"{"cancelled":2}"#.data(using: .utf8)!
            } else {
                body = Self.agentJSON(id: "a1", name: "Updated")
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        _ = try await client.updateAgent(id: "a1", name: "Updated", description: "", instructions: "", visibility: "private", maxConcurrentTasks: 1, model: "gpt-5")
        _ = try await client.archiveAgent(id: "a1")
        _ = try await client.restoreAgent(id: "a1")
        let cancelled = try await client.cancelAgentTasks(id: "a1")

        XCTAssertEqual(requests.map { "\($0.0) \($0.1)" }, [
            "PUT /api/agents/a1",
            "POST /api/agents/a1/archive",
            "POST /api/agents/a1/restore",
            "POST /api/agents/a1/cancel-tasks",
        ])
        XCTAssertEqual(cancelled.count, 2)
    }

    func test_listRuntimes_decodesWorkspaceRuntimes() async throws {
        let json = """
        [{"id":"r1","workspace_id":"w1","daemon_id":null,"name":"MacBook",
          "runtime_mode":"cloud","provider":"multica","launch_header":"",
          "status":"online","device_info":"","metadata":{},"owner_id":null,
          "last_seen_at":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/runtimes")
            XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let runtimes = try await client.listRuntimes(workspaceId: "w1")

        XCTAssertEqual(runtimes.first?.name, "MacBook")
        XCTAssertEqual(runtimes.first?.status, "online")
    }

    func test_deleteRuntime_usesDesktopEndpoint() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { req in
            capturedRequest = req
            return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
        }

        try await client.deleteRuntime(id: "r1")

        XCTAssertEqual(capturedRequest?.httpMethod, "DELETE")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/runtimes/r1")
    }

    func test_skillEndpointsUseDesktopPaths() async throws {
        var requests: [String] = []
        MockURLProtocol.handler = { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            if req.httpMethod == "DELETE" {
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
            }
            let body: Data
            if req.url?.path == "/api/skills", req.httpMethod == "GET" {
                body = "[\(String(data: Self.skillJSON(id: "s1", name: "Writer"), encoding: .utf8)!)]".data(using: .utf8)!
            } else {
                body = Self.skillJSON(id: "s1", name: "Writer")
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let skills = try await client.listSkills()
        _ = try await client.getSkill(id: "s1")
        _ = try await client.createSkill(name: "Writer", description: "D", content: "C")
        _ = try await client.updateSkill(id: "s1", name: "Writer", description: "D2", content: "C2")
        _ = try await client.importSkill(url: "https://example.com/skill")
        try await client.deleteSkill(id: "s1")

        XCTAssertEqual(skills.map(\.id), ["s1"])
        XCTAssertEqual(requests, [
            "GET /api/skills",
            "GET /api/skills/s1",
            "POST /api/skills",
            "PUT /api/skills/s1",
            "POST /api/skills/import",
            "DELETE /api/skills/s1",
        ])
    }

    func test_autopilotEndpointsUseDesktopPaths() async throws {
        var requests: [String] = []
        MockURLProtocol.handler = { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")?\(req.url?.query ?? "")")
            let path = req.url?.path
            if req.httpMethod == "DELETE" {
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            }
            let body: Data
            switch path {
            case "/api/autopilots" where req.httpMethod == "GET":
                body = #"{"autopilots":[\#(String(data: Self.autopilotJSON(id: "ap1", title: "Daily triage"), encoding: .utf8)!)],"total":1}"#.data(using: .utf8)!
            case "/api/autopilots/ap1":
                if req.httpMethod == "GET" {
                    body = #"{"autopilot":\#(String(data: Self.autopilotJSON(id: "ap1", title: "Daily triage"), encoding: .utf8)!),"triggers":[]}"#.data(using: .utf8)!
                } else {
                    body = Self.autopilotJSON(id: "ap1", title: "Daily triage")
                }
            case "/api/autopilots/ap1/runs":
                body = #"{"runs":[\#(String(data: Self.autopilotRunJSON(id: "run1"), encoding: .utf8)!)],"total":1}"#.data(using: .utf8)!
            case "/api/autopilots/ap1/triggers":
                body = Self.autopilotTriggerJSON(id: "tr1")
            case "/api/autopilots/ap1/triggers/tr1":
                body = Self.autopilotTriggerJSON(id: "tr1")
            case "/api/autopilots/ap1/trigger":
                body = Self.autopilotRunJSON(id: "run1")
            default:
                body = Self.autopilotJSON(id: "ap1", title: "Daily triage")
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let list = try await client.listAutopilots(status: "active")
        _ = try await client.getAutopilot(id: "ap1")
        _ = try await client.createAutopilot(title: "Daily triage", description: "D", assigneeId: "a1", executionMode: "create_issue", issueTitleTemplate: "T")
        _ = try await client.updateAutopilot(id: "ap1", title: "Daily triage", description: nil, assigneeId: "a1", status: "paused", executionMode: "run_only", issueTitleTemplate: nil)
        try await client.deleteAutopilot(id: "ap1")
        _ = try await client.triggerAutopilot(id: "ap1")
        let runs = try await client.listAutopilotRuns(id: "ap1", limit: 10, offset: 20)
        _ = try await client.createAutopilotTrigger(autopilotId: "ap1", kind: "schedule", cronExpression: "0 9 * * *", timezone: "UTC", label: "Morning")
        _ = try await client.updateAutopilotTrigger(autopilotId: "ap1", triggerId: "tr1", enabled: false, cronExpression: nil, timezone: nil, label: nil)
        try await client.deleteAutopilotTrigger(autopilotId: "ap1", triggerId: "tr1")

        XCTAssertEqual(list.autopilots.map(\.id), ["ap1"])
        XCTAssertEqual(runs.runs.map(\.id), ["run1"])
        XCTAssertEqual(requests, [
            "GET /api/autopilots?status=active",
            "GET /api/autopilots/ap1?",
            "POST /api/autopilots?",
            "PATCH /api/autopilots/ap1?",
            "DELETE /api/autopilots/ap1?",
            "POST /api/autopilots/ap1/trigger?",
            "GET /api/autopilots/ap1/runs?limit=10&offset=20",
            "POST /api/autopilots/ap1/triggers?",
            "PATCH /api/autopilots/ap1/triggers/tr1?",
            "DELETE /api/autopilots/ap1/triggers/tr1?",
        ])
    }

    func test_labelEndpointsUseDesktopPaths() async throws {
        var requests: [String] = []
        MockURLProtocol.handler = { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            if req.httpMethod == "DELETE", req.url?.path == "/api/labels/l1" {
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            }
            let body: Data
            switch req.url?.path {
            case "/api/labels" where req.httpMethod == "GET":
                body = #"{"labels":[\#(String(data: Self.labelJSON(id: "l1", name: "bug"), encoding: .utf8)!)],"total":1}"#.data(using: .utf8)!
            case "/api/issues/i1/labels":
                body = #"{"labels":[\#(String(data: Self.labelJSON(id: "l1", name: "bug"), encoding: .utf8)!)]}"#.data(using: .utf8)!
            case "/api/issues/i1/labels/l1":
                body = #"{"labels":[]}"#.data(using: .utf8)!
            default:
                body = Self.labelJSON(id: "l1", name: "bug")
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let list = try await client.listLabels()
        _ = try await client.getLabel(id: "l1")
        _ = try await client.createLabel(name: "bug", color: "#ef4444")
        _ = try await client.updateLabel(id: "l1", name: "bug", color: "#dc2626")
        try await client.deleteLabel(id: "l1")
        let issueLabels = try await client.listLabelsForIssue(issueId: "i1")
        _ = try await client.attachLabel(issueId: "i1", labelId: "l1")
        _ = try await client.detachLabel(issueId: "i1", labelId: "l1")

        XCTAssertEqual(list.labels.map(\.id), ["l1"])
        XCTAssertEqual(issueLabels.labels.map(\.id), ["l1"])
        XCTAssertEqual(requests, [
            "GET /api/labels",
            "GET /api/labels/l1",
            "POST /api/labels",
            "PUT /api/labels/l1",
            "DELETE /api/labels/l1",
            "GET /api/issues/i1/labels",
            "POST /api/issues/i1/labels",
            "DELETE /api/issues/i1/labels/l1",
        ])
    }

    func test_issueSubscriberEndpointsUseDesktopPaths() async throws {
        var requests: [String] = []
        var subscribeBody: [String: Any] = [:]
        var unsubscribeBody: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch req.url?.path {
            case "/api/issues/i1/subscribers":
                let body = """
                [{"issue_id":"i1","user_type":"member","user_id":"u1","reason":"manual",
                  "created_at":"2026-01-01T00:00:00Z"}]
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            case "/api/issues/i1/subscribe":
                subscribeBody = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            case "/api/issues/i1/unsubscribe":
                unsubscribeBody = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            default:
                return (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let subscribers = try await client.listIssueSubscribers(issueId: "i1")
        try await client.subscribeToIssue(issueId: "i1", userId: "u2", userType: "member")
        try await client.unsubscribeFromIssue(issueId: "i1", userId: "a1", userType: "agent")

        XCTAssertEqual(subscribers.map(\.id), ["member:u1"])
        XCTAssertEqual(subscribeBody["user_id"] as? String, "u2")
        XCTAssertEqual(subscribeBody["user_type"] as? String, "member")
        XCTAssertEqual(unsubscribeBody["user_id"] as? String, "a1")
        XCTAssertEqual(unsubscribeBody["user_type"] as? String, "agent")
        XCTAssertEqual(requests, [
            "GET /api/issues/i1/subscribers",
            "POST /api/issues/i1/subscribe",
            "POST /api/issues/i1/unsubscribe",
        ])
    }

    func test_reactionEndpointsUseDesktopPaths() async throws {
        var requests: [String] = []
        var bodies: [[String: Any]] = []
        MockURLProtocol.handler = { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch req.url?.path {
            case "/api/comments/c1/reactions":
                bodies.append(try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:])
                if req.httpMethod == "DELETE" {
                    return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
                }
                let body = """
                {"id":"r1","comment_id":"c1","actor_type":"member","actor_id":"u1",
                 "emoji":"👍","created_at":"2026-01-01T00:00:00Z"}
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            case "/api/issues/i1/reactions":
                bodies.append(try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:])
                if req.httpMethod == "DELETE" {
                    return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
                }
                let body = """
                {"id":"ir1","issue_id":"i1","actor_type":"member","actor_id":"u1",
                 "emoji":"👀","created_at":"2026-01-01T00:00:00Z"}
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            default:
                return (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let commentReaction = try await client.addReaction(commentId: "c1", emoji: "👍")
        try await client.removeReaction(commentId: "c1", emoji: "👍")
        let issueReaction = try await client.addIssueReaction(issueId: "i1", emoji: "👀")
        try await client.removeIssueReaction(issueId: "i1", emoji: "👀")

        XCTAssertEqual(commentReaction.id, "r1")
        XCTAssertEqual(issueReaction.id, "ir1")
        XCTAssertEqual(bodies.compactMap { $0["emoji"] as? String }, ["👍", "👍", "👀", "👀"])
        XCTAssertEqual(requests, [
            "POST /api/comments/c1/reactions",
            "DELETE /api/comments/c1/reactions",
            "POST /api/issues/i1/reactions",
            "DELETE /api/issues/i1/reactions",
        ])
    }

    func test_commentMutationEndpointsUseDesktopPaths() async throws {
        var requests: [String] = []
        var updateBody: [String: Any] = [:]
        MockURLProtocol.handler = { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch (req.httpMethod, req.url?.path) {
            case ("PUT", "/api/comments/c1"):
                updateBody = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                let body = """
                {"id":"c1","content":"Updated **markdown**","author_id":"u1","author_type":"member",
                 "parent_id":null,"issue_id":"i1","created_at":"2026-01-01T00:00:00Z"}
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            case ("DELETE", "/api/comments/c1"):
                return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            default:
                return (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let comment = try await client.updateComment(commentId: "c1", content: "Updated **markdown**")
        try await client.deleteComment(commentId: "c1")

        XCTAssertEqual(comment.content, "Updated **markdown**")
        XCTAssertEqual(updateBody["content"] as? String, "Updated **markdown**")
        XCTAssertEqual(requests, [
            "PUT /api/comments/c1",
            "DELETE /api/comments/c1",
        ])
    }

    private static func agentJSON(id: String, name: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","runtime_id":"r1","name":"\(name)",
          "description":"","instructions":"","avatar_url":null,"runtime_mode":"cloud",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"idle","max_concurrent_tasks":1,
          "model":"gpt","owner_id":null,"skills":[],"created_at":"2026-01-01T00:00:00Z",
          "updated_at":"2026-01-01T00:00:00Z","archived_at":null,"archived_by":null}
        """.data(using: .utf8)!
    }

    private static func skillJSON(id: String, name: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","name":"\(name)","description":"**D**",
         "content":"# Skill","config":{},"files":[],"created_by":"u1",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }

    private static func autopilotJSON(id: String, title: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","title":"\(title)","description":"**D**",
         "assignee_id":"a1","status":"active","execution_mode":"create_issue",
         "issue_title_template":"T","created_by_type":"member","created_by_id":"u1",
         "last_run_at":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }

    private static func autopilotTriggerJSON(id: String) -> Data {
        """
        {"id":"\(id)","autopilot_id":"ap1","kind":"schedule","enabled":true,
         "cron_expression":"0 9 * * *","timezone":"UTC","next_run_at":null,
         "webhook_token":null,"label":"Morning","last_fired_at":null,
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }

    private static func autopilotRunJSON(id: String) -> Data {
        """
        {"id":"\(id)","autopilot_id":"ap1","trigger_id":null,"source":"manual",
         "status":"running","issue_id":null,"task_id":"t1","triggered_at":"2026-01-01T00:00:00Z",
         "completed_at":null,"failure_reason":null,"trigger_payload":{},"result":null,
         "created_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }

    private static func labelJSON(id: String, name: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","name":"\(name)","color":"#ef4444",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
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
