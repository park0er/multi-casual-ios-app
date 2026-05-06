import XCTest
@testable import MultiCasual

@MainActor
final class IssueEditViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadOptionsBuildsAssigneeAndProjectChoicesAndKeepsCurrentSelections() async throws {
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
        let vm = IssueEditViewModel(issue: issue(assigneeType: "agent", assigneeId: "a1", projectId: "p1"), api: client, authSession: makeSession())

        await vm.loadOptions()

        XCTAssertEqual(vm.assigneeOptions.map(\.id), ["member:u1", "agent:a1"])
        XCTAssertEqual(vm.selectedAssigneeOptionId, "agent:a1")
        XCTAssertEqual(vm.projects.map(\.id), ["p1"])
        XCTAssertEqual(vm.selectedProjectId, "p1")
        XCTAssertNil(vm.errorMessage)
    }

    func test_submitUpdatesIssueAndCanClearAssigneeAndProject() async throws {
        var body: [String: Any] = [:]
        let client = makeClient { req in
            XCTAssertEqual(req.httpMethod, "PUT")
            XCTAssertEqual(req.url?.path, "/api/issues/i1")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            let json = """
            {"id":"i1","identifier":"PAR-1","number":1,"title":"Updated","description":null,
             "status":"in_review","priority":"urgent","assignee_id":null,"assignee_type":null,
             "project_id":null,"due_date":null,"workspace_id":"w1","created_at":"2026-01-01T00:00:00Z",
             "updated_at":"2026-01-02T00:00:00Z"}
            """.data(using: .utf8)!
            return Self.response(for: req, body: json)
        }
        let vm = IssueEditViewModel(issue: issue(assigneeType: "member", assigneeId: "u1", projectId: "p1"), api: client, authSession: makeSession())
        vm.title = " Updated "
        vm.description = " \n "
        vm.status = .inReview
        vm.priority = .urgent
        vm.selectedAssigneeOptionId = IssueEditViewModel.noAssigneeId
        vm.selectedProjectId = IssueEditViewModel.noProjectId
        vm.includesDueDate = false

        let updated = await vm.submit()

        XCTAssertEqual(updated?.title, "Updated")
        XCTAssertEqual(body["title"] as? String, "Updated")
        XCTAssertTrue(body["description"] is NSNull)
        XCTAssertEqual(body["status"] as? String, "in_review")
        XCTAssertEqual(body["priority"] as? String, "urgent")
        XCTAssertTrue(body["assignee_type"] is NSNull)
        XCTAssertTrue(body["assignee_id"] is NSNull)
        XCTAssertTrue(body["project_id"] is NSNull)
        XCTAssertTrue(body["due_date"] is NSNull)
        XCTAssertNil(vm.errorMessage)
    }

    private func issue(assigneeType: String?, assigneeId: String?, projectId: String?) -> Issue {
        Issue(
            id: "i1",
            identifier: "PAR-1",
            number: 1,
            title: "Original",
            description: "Body",
            status: .todo,
            priority: .noPriority,
            assigneeId: assigneeId,
            assigneeType: assigneeType,
            projectId: projectId,
            workspaceId: "w1",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.issue-edit.test"))
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
