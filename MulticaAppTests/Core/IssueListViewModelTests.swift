import XCTest
@testable import MultiCasual

@MainActor
final class IssueListViewModelTests: XCTestCase {
    func test_loadNext_withoutWorkspaceSurfacesActionableError() async throws {
        let vm = IssueListViewModel(api: makeClient(), authSession: AuthSession(userDefaults: makeUserDefaults()))

        await vm.loadNext()

        XCTAssertEqual(vm.lastError?.localizedDescription, "Pick a workspace before opening Issues.")
    }

    func test_loadNext_fetchesFirstPageForEachDesktopBoardStatus() async throws {
        var requestedStatuses: [String] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            guard let status = components?.queryItems?.first(where: { $0.name == "status" })?.value else {
                XCTFail("Expected status query in \(req.url?.absoluteString ?? "")")
                return Self.emptyIssuesResponse(for: req)
            }
            requestedStatuses.append(status)
            return Self.issuesResponse(for: req, status: status, total: 1)
        }
        let vm = IssueListViewModel(api: client, authSession: makeAuthSession())

        await vm.loadNext()

        XCTAssertEqual(requestedStatuses, ["backlog", "todo", "in_progress", "in_review", "done", "blocked"])
        XCTAssertEqual(vm.loader.items.map(\.status), [.backlog, .todo, .inProgress, .inReview, .done, .blocked])
        XCTAssertEqual(vm.issuesByStatus[.todo]?.map(\.id), ["todo-1"])
        XCTAssertFalse(vm.loader.hasMore)
    }

    func test_loadNext_paginatesNextStatusBucketWithRemainingItems() async throws {
        var requested: [(status: String, offset: String?)] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            guard let status = components?.queryItems?.first(where: { $0.name == "status" })?.value else {
                XCTFail("Expected status query in \(req.url?.absoluteString ?? "")")
                return Self.emptyIssuesResponse(for: req)
            }
            let offset = components?.queryItems?.first(where: { $0.name == "offset" })?.value
            requested.append((status, offset))
            if status == "todo" && offset == "0" {
                return Self.issuesResponse(for: req, status: status, suffix: "1", total: 2)
            }
            if status == "todo" && offset == "1" {
                return Self.issuesResponse(for: req, status: status, suffix: "2", total: 2)
            }
            return Self.issuesResponse(for: req, status: status, total: 0)
        }
        let vm = IssueListViewModel(api: client, authSession: makeAuthSession())

        await vm.loadNext()
        await vm.loadNext()

        XCTAssertTrue(requested.contains { $0.status == "todo" && $0.offset == "1" })
        XCTAssertEqual(vm.issuesByStatus[.todo]?.map(\.id), ["todo-1", "todo-2"])
        XCTAssertFalse(vm.loader.hasMore)
    }

    func test_loadNext_appliesPriorityFilterToStatusBuckets() async throws {
        var requestedPriorities: [String?] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            let status = components?.queryItems?.first(where: { $0.name == "status" })?.value ?? "todo"
            requestedPriorities.append(components?.queryItems?.first(where: { $0.name == "priority" })?.value)
            return Self.issuesResponse(for: req, status: status, priority: "urgent", total: 1)
        }
        let vm = IssueListViewModel(api: client, authSession: makeAuthSession())
        vm.priorityFilter = .urgent

        await vm.loadNext()

        XCTAssertEqual(requestedPriorities, Array(repeating: "urgent", count: IssueStatus.boardCases.count))
        XCTAssertEqual(Set(vm.loader.items.map(\.priority)), [.urgent])
    }

    func test_setSortOption_sortsLoadedIssuesByPriority() async throws {
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            let status = components?.queryItems?.first(where: { $0.name == "status" })?.value ?? "todo"
            switch status {
            case "backlog":
                return Self.issuesResponse(for: req, status: status, priority: "low", total: 1)
            case "todo":
                return Self.issuesResponse(for: req, status: status, priority: "urgent", total: 1)
            default:
                return Self.emptyIssuesResponse(for: req)
            }
        }
        let vm = IssueListViewModel(api: client, authSession: makeAuthSession())

        await vm.loadNext()
        vm.setSortOption(.priority)

        XCTAssertEqual(vm.loader.items.map(\.priority), [.urgent, .low])
        XCTAssertEqual(vm.loader.items.map(\.id), ["todo-1", "backlog-1"])
    }

    func test_updateStatus_updatesServerAndMovesIssueBetweenStatusBuckets() async throws {
        var updateRequestBody: [String: Any] = [:]
        let client = makeClient { req in
            switch (req.httpMethod, req.url?.path) {
            case ("GET", "/api/issues"):
                let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
                let status = components?.queryItems?.first(where: { $0.name == "status" })?.value ?? "todo"
                if status == "todo" {
                    return Self.issuesResponse(for: req, status: status, total: 1)
                }
                return Self.emptyIssuesResponse(for: req)
            case ("PUT", "/api/issues/todo-1"):
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                updateRequestBody = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                return Self.response(
                    for: req,
                    body: Self.issueJSON(id: "todo-1", status: "done", priority: "none")
                )
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.emptyIssuesResponse(for: req)
            }
        }
        let vm = IssueListViewModel(api: client, authSession: makeAuthSession())

        await vm.loadNext()
        await vm.updateStatus(issueId: "todo-1", to: IssueStatus.done)

        XCTAssertEqual(updateRequestBody["status"] as? String, "done")
        XCTAssertEqual(vm.loader.items.map { $0.status }, [IssueStatus.done])
        XCTAssertEqual(vm.issuesByStatus[IssueStatus.todo]?.map { $0.id } ?? [], [])
        XCTAssertEqual(vm.issuesByStatus[IssueStatus.done]?.map { $0.id }, ["todo-1"])
        XCTAssertFalse(vm.loader.hasMore)
        XCTAssertNil(vm.lastError)
    }

    private func makeClient(handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? = nil) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler ?? { req in
            XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
            return (
                HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }
        return APIClient(session: URLSession(configuration: config), token: "test-token")
    }

    private func makeUserDefaults() -> UserDefaults {
        UserDefaults(suiteName: "IssueListViewModelTests.\(UUID().uuidString)")!
    }

    private func makeAuthSession() -> AuthSession {
        let session = AuthSession(userDefaults: makeUserDefaults())
        try! session.login(
            user: User(id: "u1", email: "u@example.com", name: "User", avatarUrl: nil),
            workspaces: [Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")],
            token: "token"
        )
        return session
    }

    private static func emptyIssuesResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            #"{"issues":[],"has_more":false,"total":0}"#.data(using: .utf8)!
        )
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

    private static func issuesResponse(
        for request: URLRequest,
        status: String,
        suffix: String = "1",
        priority: String = "none",
        total: Int
    ) -> (HTTPURLResponse, Data) {
        let id = "\(status)-\(suffix)"
        let json = """
        {"issues":[{"id":"\(id)","identifier":"PAR-\(suffix)","number":\(suffix),
         "title":"\(status) issue","description":null,"status":"\(status)","priority":"\(priority)",
         "assignee_id":null,"assignee_type":null,"project_id":null,"workspace_id":"w1",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}],
         "has_more":false,"total":\(total)}
        """.data(using: .utf8)!
        return (
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            json
        )
    }

    private static func issueJSON(id: String, status: String, priority: String) -> Data {
        """
        {"id":"\(id)","identifier":"PAR-1","number":1,
         "title":"\(status) issue","description":null,"status":"\(status)","priority":"\(priority)",
         "assignee_id":null,"assignee_type":null,"project_id":null,"workspace_id":"w1",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}
        """.data(using: .utf8)!
    }
}
