import XCTest
@testable import MultiCasual

@MainActor
final class ProjectDetailViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")
    private let project = Project(
        id: "p1",
        name: "iOS MVP",
        description: "Mobile client",
        workspaceId: "w1",
        createdAt: Date(),
        issueCount: 2,
        doneCount: 1
    )

    func test_load_fetchesProjectIssuesAndResources() async throws {
        var issueRequests: [(status: String?, projectId: String?)] = []
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/issues":
                let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
                let status = components?.queryItems?.first(where: { $0.name == "status" })?.value
                let projectId = components?.queryItems?.first(where: { $0.name == "project_id" })?.value
                issueRequests.append((status, projectId))
                let json = """
                {"issues": [
                    {"id":"i1","identifier":"PAR-1","number":1,"title":"In project","description":null,
                     "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
                     "project_id":"p1","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"},
                    {"id":"i2","identifier":"PAR-2","number":2,"title":"Elsewhere","description":null,
                     "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
                     "project_id":"p2","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
                ], "total": 2}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/projects/p1/resources":
                let json = """
                {"resources":[{
                    "id":"r1","project_id":"p1","workspace_id":"w1","resource_type":"github_repo",
                    "resource_ref":{"url":"https://github.com/multica-ai/multica","default_branch_hint":"main"},
                    "label":"Multica repo","position":0,"created_at":"2026-01-01T00:00:00Z","created_by":null
                }],"total":1}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ProjectDetailViewModel(project: project, api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.issues.map(\.id), ["i1"])
        XCTAssertEqual(issueRequests.map(\.status), ["backlog", "todo", "in_progress", "in_review", "done", "blocked"])
        XCTAssertEqual(issueRequests.map(\.projectId), Array(repeating: "p1", count: 6))
        XCTAssertEqual(vm.resources.map(\.displayTitle), ["Multica repo"])
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.project-detail.test"))
        session.currentWorkspace = workspace
        session.workspaces = [workspace]
        return session
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
}
