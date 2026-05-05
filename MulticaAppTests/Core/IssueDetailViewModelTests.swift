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
