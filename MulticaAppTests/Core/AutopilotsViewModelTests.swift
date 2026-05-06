import XCTest
@testable import MultiCasual

@MainActor
final class AutopilotsViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadFetchesAutopilotsAndAgents() async throws {
        var requestURLs: [URL] = []
        let client = makeClient { req in
            requestURLs.append(req.url!)
            switch req.url?.path {
            case "/api/autopilots":
                return Self.response(for: req, body: Self.autopilotListJSON())
            case "/api/agents":
                return Self.response(for: req, body: Self.agentListJSON())
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = AutopilotsViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.autopilots.map(\.id), ["ap1"])
        XCTAssertEqual(vm.agents.map(\.id), ["a1"])
        XCTAssertTrue(requestURLs.allSatisfy { $0.absoluteString.contains("workspace_id=w1") })
        XCTAssertNil(vm.errorMessage)
    }

    func test_createUpdateDeleteAndTriggerKeepListInSync() async throws {
        var requests: [String] = []
        var requestURLs: [URL] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            requestURLs.append(req.url!)
            if req.httpMethod == "DELETE" {
                return Self.response(for: req, body: Data(), status: 204)
            }
            if req.url?.path == "/api/autopilots/ap1/trigger" {
                return Self.response(for: req, body: Self.autopilotRunJSON(id: "run1"))
            }
            let title = req.httpMethod == "PATCH" ? "Updated" : "Created"
            return Self.response(for: req, body: Self.autopilotJSON(id: "ap1", title: title))
        }
        let vm = AutopilotsViewModel(api: client, authSession: makeSession())

        _ = await vm.createAutopilot(title: "Created", description: "D", assigneeId: "a1", executionMode: "create_issue", issueTitleTemplate: "T")
        _ = await vm.updateAutopilot(id: "ap1", title: "Updated", description: nil, assigneeId: "a1", status: "paused", executionMode: "run_only", issueTitleTemplate: nil)
        let run = await vm.triggerAutopilot(id: "ap1")
        await vm.deleteAutopilot(id: "ap1")

        XCTAssertEqual(run?.id, "run1")
        XCTAssertTrue(vm.autopilots.isEmpty)
        XCTAssertEqual(requests, [
            "POST /api/autopilots",
            "PATCH /api/autopilots/ap1",
            "POST /api/autopilots/ap1/trigger",
            "DELETE /api/autopilots/ap1",
        ])
        XCTAssertTrue(requestURLs.allSatisfy { $0.absoluteString.contains("workspace_id=w1") })
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.autopilots.test"))
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

    private static func autopilotListJSON() -> Data {
        #"{"autopilots":[\#(String(data: autopilotJSON(id: "ap1", title: "Daily triage"), encoding: .utf8)!)],"total":1}"#.data(using: .utf8)!
    }

    private static func autopilotJSON(id: String, title: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","title":"\(title)","description":"**D**",
         "assignee_id":"a1","status":"active","execution_mode":"create_issue",
         "issue_title_template":"T","created_by_type":"member","created_by_id":"u1",
         "last_run_at":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
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

    private static func agentListJSON() -> Data {
        """
        [{"id":"a1","workspace_id":"w1","runtime_id":"r1","name":"Codex",
          "description":"","instructions":"","avatar_url":null,"runtime_mode":"cloud",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"idle","max_concurrent_tasks":1,
          "model":"gpt","owner_id":null,"skills":[],"created_at":"2026-01-01T00:00:00Z",
          "updated_at":"2026-01-01T00:00:00Z","archived_at":null,"archived_by":null}]
        """.data(using: .utf8)!
    }
}
