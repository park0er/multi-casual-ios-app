import XCTest
@testable import MultiCasual

@MainActor
final class AgentsViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadFetchesArchivedAgentsAndRuntimes() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/agents":
                XCTAssertTrue(req.url?.absoluteString.contains("include_archived=true") ?? false)
                return Self.response(for: req, body: Self.agentListJSON())
            case "/api/runtimes":
                return Self.response(for: req, body: Self.runtimeListJSON())
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = AgentsViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.agents.map(\.id), ["a1"])
        XCTAssertEqual(vm.runtimes.map(\.id), ["r1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_createAndUpdateReplaceAgentInList() async throws {
        var requests: [(String, String)] = []
        let client = makeClient { req in
            requests.append((req.httpMethod ?? "", req.url?.path ?? ""))
            let name = req.httpMethod == "POST" ? "Created" : "Updated"
            return Self.response(for: req, body: Self.agentJSON(id: "a1", name: name))
        }
        let vm = AgentsViewModel(api: client, authSession: makeSession())

        let created = await vm.createAgent(name: "Created", description: "", instructions: "", runtimeId: "r1", visibility: "workspace", maxConcurrentTasks: 1, model: "gpt")
        let updated = await vm.updateAgent(id: "a1", name: "Updated", description: "D", instructions: "I", visibility: "private", maxConcurrentTasks: 2, model: "gpt-5")

        XCTAssertEqual(created?.name, "Created")
        XCTAssertEqual(updated?.name, "Updated")
        XCTAssertEqual(vm.agents.map(\.name), ["Updated"])
        XCTAssertEqual(requests.map { "\($0.0) \($0.1)" }, ["POST /api/agents", "PUT /api/agents/a1"])
        XCTAssertNil(vm.errorMessage)
    }

    func testArchiveRestoreAndCancelTasksSurfaceResults() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/agents/a1/archive", "/api/agents/a1/restore":
                return Self.response(for: req, body: Self.agentJSON(id: "a1", name: "Codex"))
            case "/api/agents/a1/cancel-tasks":
                return Self.response(for: req, body: #"{"cancelled":3}"#.data(using: .utf8)!)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = AgentsViewModel(api: client, authSession: makeSession())

        await vm.archiveAgent(id: "a1")
        await vm.restoreAgent(id: "a1")
        let cancelled = await vm.cancelAgentTasks(id: "a1")

        XCTAssertEqual(cancelled, 3)
        XCTAssertEqual(vm.agents.map(\.id), ["a1"])
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.agents.test"))
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

    private static func agentListJSON() -> Data {
        "[\(String(data: agentJSON(id: "a1", name: "Codex"), encoding: .utf8)!)]".data(using: .utf8)!
    }

    private static func agentJSON(id: String, name: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","runtime_id":"r1","name":"\(name)",
          "description":"**Markdown** description","instructions":"Be useful","avatar_url":null,"runtime_mode":"cloud",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"idle","max_concurrent_tasks":1,
          "model":"gpt","owner_id":null,"skills":[],"created_at":"2026-01-01T00:00:00Z",
          "updated_at":"2026-01-01T00:00:00Z","archived_at":null,"archived_by":null}
        """.data(using: .utf8)!
    }

    private static func runtimeListJSON() -> Data {
        """
        [{"id":"r1","workspace_id":"w1","daemon_id":null,"name":"MacBook",
          "runtime_mode":"cloud","provider":"multica","launch_header":"",
          "status":"online","device_info":"","metadata":{},"owner_id":null,
          "last_seen_at":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
        """.data(using: .utf8)!
    }
}
