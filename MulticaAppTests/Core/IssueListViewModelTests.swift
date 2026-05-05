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

    private static func issuesResponse(
        for request: URLRequest,
        status: String,
        suffix: String = "1",
        total: Int
    ) -> (HTTPURLResponse, Data) {
        let id = "\(status)-\(suffix)"
        let json = """
        {"issues":[{"id":"\(id)","identifier":"PAR-\(suffix)","number":\(suffix),
         "title":"\(status) issue","description":null,"status":"\(status)","priority":"none",
         "assignee_id":null,"assignee_type":null,"project_id":null,"workspace_id":"w1",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}],
         "has_more":false,"total":\(total)}
        """.data(using: .utf8)!
        return (
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            json
        )
    }
}
