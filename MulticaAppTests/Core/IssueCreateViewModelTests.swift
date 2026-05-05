import XCTest
@testable import MultiCasual

@MainActor
final class IssueCreateViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadOptions_buildsAssigneeAndProjectChoices() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/workspaces/w1/members":
                let json = """
                [{"id":"m1","workspace_id":"w1","user_id":"u1","role":"owner",
                  "created_at":"2026-01-01T00:00:00Z","name":"Parker",
                  "email":"p@example.com","avatar_url":null}]
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
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
        let vm = IssueCreateViewModel(api: client, authSession: makeSession())

        await vm.loadOptions()

        XCTAssertEqual(vm.assigneeOptions.map(\.id), ["member:u1", "agent:a1"])
        XCTAssertEqual(vm.assigneeOptions.map(\.displayName), ["Parker", "Codex"])
        XCTAssertEqual(vm.projects.map(\.id), ["p1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadOptions_paginatesProjectChoices() async throws {
        var projectOffsets: [String?] = []
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/workspaces/w1/members":
                return Self.response(for: req, body: Data("[]".utf8))
            case "/api/agents":
                return Self.response(for: req, body: Data("[]".utf8))
            case "/api/projects":
                let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
                let offset = components?.queryItems?.first(where: { $0.name == "offset" })?.value ?? "0"
                projectOffsets.append(offset)
                let title = offset == "0" ? "First page" : "Second page"
                let id = offset == "0" ? "p1" : "p2"
                let json = """
                {"projects":[{
                    "id":"\(id)","workspace_id":"w1","title":"\(title)","description":null,
                    "icon":null,"status":"in_progress","priority":"none",
                    "lead_type":null,"lead_id":null,
                    "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z",
                    "issue_count":2,"done_count":1
                }],"total":2}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = IssueCreateViewModel(api: client, authSession: makeSession())

        await vm.loadOptions()

        XCTAssertEqual(projectOffsets, ["0", "1"])
        XCTAssertEqual(vm.projects.map { $0.id }, ["p1", "p2"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_submitSendsSelectedDesktopFields() async throws {
        let dueDate = Date(timeIntervalSince1970: 1_778_025_600)
        var body: [String: Any] = [:]
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/issues")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            let json = """
            {"id":"i1","identifier":"PAR-1","number":1,"title":"T","description":"D",
             "status":"in_review","priority":"urgent","assignee_id":"a1","assignee_type":"agent",
             "project_id":"p1","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
             "updated_at":"2026-01-01T00:00:00Z"}
            """.data(using: .utf8)!
            return Self.response(for: req, body: json)
        }
        let vm = IssueCreateViewModel(api: client, authSession: makeSession())
        vm.title = " T "
        vm.description = " D "
        vm.status = .inReview
        vm.priority = .urgent
        vm.assigneeOptions = [
            IssueAssigneeOption(id: "agent:a1", type: "agent", assigneeId: "a1", displayName: "Codex", subtitle: "Agent")
        ]
        vm.selectedAssigneeOptionId = "agent:a1"
        vm.projects = [Project(id: "p1", name: "iOS MVP", description: nil, workspaceId: "w1", createdAt: Date())]
        vm.selectedProjectId = "p1"
        vm.includesDueDate = true
        vm.dueDate = dueDate

        let created = await vm.submit()

        XCTAssertTrue(created)
        XCTAssertEqual(body["title"] as? String, "T")
        XCTAssertEqual(body["description"] as? String, "D")
        XCTAssertEqual(body["workspace_id"] as? String, "w1")
        XCTAssertEqual(body["status"] as? String, "in_review")
        XCTAssertEqual(body["priority"] as? String, "urgent")
        XCTAssertEqual(body["assignee_type"] as? String, "agent")
        XCTAssertEqual(body["assignee_id"] as? String, "a1")
        XCTAssertEqual(body["project_id"] as? String, "p1")
        XCTAssertEqual(body["due_date"] as? String, "2026-05-06T00:00:00Z")
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.issue-create.test"))
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
