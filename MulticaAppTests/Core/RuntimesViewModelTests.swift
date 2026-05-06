import XCTest
@testable import MultiCasual

@MainActor
final class RuntimesViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadFetchesWorkspaceRuntimes() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/runtimes")
            XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
            return Self.response(for: req, body: Self.runtimesJSON())
        }
        let vm = RuntimesViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.runtimes.map(\.id), ["r1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_deleteRuntimeRemovesRuntimeFromList() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.httpMethod, "DELETE")
            XCTAssertEqual(req.url?.path, "/api/runtimes/r1")
            XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
            return Self.response(for: req, body: Data("{}".utf8), status: 204)
        }
        let vm = RuntimesViewModel(api: client, authSession: makeSession())
        vm.runtimes = [AgentRuntime(id: "r1", workspaceId: "w1", name: "MacBook", runtimeMode: "cloud", provider: "multica", status: "online")]

        await vm.deleteRuntime(id: "r1")

        XCTAssertTrue(vm.runtimes.isEmpty)
        XCTAssertNil(vm.errorMessage)
    }

    func test_runtimeDetailLoadsOwnerServingAgentsUsageAndTelemetry() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/workspaces/w1/members":
                return Self.response(for: req, body: Self.membersJSON())
            case "/api/agents":
                return Self.response(for: req, body: Self.agentsJSON())
            case "/api/runtimes/r1/usage":
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                XCTAssertTrue(req.url?.absoluteString.contains("days=30") ?? false)
                return Self.response(for: req, body: Self.runtimeUsageJSON())
            case "/api/runtimes/r1/activity":
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                return Self.response(for: req, body: Self.runtimeActivityJSON())
            case "/api/runtimes/r1/usage/by-agent":
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                XCTAssertTrue(req.url?.absoluteString.contains("days=30") ?? false)
                return Self.response(for: req, body: Self.runtimeUsageByAgentJSON())
            case "/api/runtimes/r1/usage/by-hour":
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                XCTAssertTrue(req.url?.absoluteString.contains("days=30") ?? false)
                return Self.response(for: req, body: Self.runtimeUsageByHourJSON())
            default:
                XCTFail("Unexpected request \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 500)
            }
        }
        let runtime = AgentRuntime(
            id: "r1",
            workspaceId: "w1",
            name: "MacBook **Pro**",
            runtimeMode: "local",
            provider: "claude",
            status: "online",
            daemonId: "daemon-123456",
            launchHeader: "multica runtime",
            deviceInfo: "host.local · darwin-arm64",
            metadata: ["cli_version": .string("0.2.17")],
            ownerId: "u1",
            lastSeenAt: ISO8601DateFormatter().date(from: "2026-01-02T03:04:05Z"),
            createdAt: ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z"),
            updatedAt: ISO8601DateFormatter().date(from: "2026-01-03T00:00:00Z")
        )
        let vm = RuntimeDetailViewModel(runtime: runtime, api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.ownerName, "Parker")
        XCTAssertEqual(vm.servingAgents.map(\.id), ["a1"])
        XCTAssertEqual(vm.usageSummary?.totalTokens, 3_700)
        XCTAssertEqual(vm.activity.first?.totalTasks, 15)
        XCTAssertEqual(vm.usageByAgent.first?.agentName, "Codex")
        XCTAssertEqual(vm.usageByAgent.first?.totalTokens, 370)
        XCTAssertEqual(vm.usageByHour.first?.totalTokens, 37)
        XCTAssertEqual(vm.cliVersion, "0.2.17")
        XCTAssertNil(vm.errorMessage)
    }

    func test_runtimeDetailCanRequestModelsAndLocalSkillsOnDemand() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/runtimes/r1/models"):
                return Self.response(for: req, body: Self.runtimeModelsJSON())
            case ("POST", "/api/runtimes/r1/local-skills"):
                return Self.response(for: req, body: Self.runtimeLocalSkillsJSON())
            default:
                XCTFail("Unexpected request \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 500)
            }
        }
        let runtime = AgentRuntime(id: "r1", workspaceId: "w1", name: "MacBook", runtimeMode: "local", provider: "claude", status: "online")
        let vm = RuntimeDetailViewModel(runtime: runtime, api: client, authSession: makeSession())

        await vm.refreshModels()
        await vm.refreshLocalSkills()

        XCTAssertEqual(requests, [
            "POST /api/runtimes/r1/models",
            "POST /api/runtimes/r1/local-skills",
        ])
        XCTAssertEqual(vm.modelList?.models.map(\.name), ["gpt-5.1"])
        XCTAssertEqual(vm.localSkillList?.skills.map(\.name), ["Writer"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_runtimeDetailCanStartUpdateAndImportLocalSkill() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/runtimes/r1/update"):
                return Self.response(for: req, body: Self.runtimeUpdateJSON())
            case ("POST", "/api/runtimes/r1/local-skills/import"):
                return Self.response(for: req, body: Self.runtimeLocalSkillImportJSON())
            default:
                XCTFail("Unexpected request \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 500)
            }
        }
        let runtime = AgentRuntime(id: "r1", workspaceId: "w1", name: "MacBook", runtimeMode: "local", provider: "claude", status: "online")
        let vm = RuntimeDetailViewModel(runtime: runtime, api: client, authSession: makeSession())

        await vm.startUpdate(targetVersion: "v1.2.3")
        await vm.importLocalSkill(skillKey: "review-helper", name: "Review Helper", description: "Review pull requests")

        XCTAssertEqual(requests, [
            "POST /api/runtimes/r1/update",
            "POST /api/runtimes/r1/local-skills/import",
        ])
        XCTAssertEqual(vm.updateRequest?.targetVersion, "v1.2.3")
        XCTAssertEqual(vm.localSkillImport?.skillKey, "review-helper")
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.runtimes.test"))
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

    private static func runtimesJSON() -> Data {
        """
        [{"id":"r1","workspace_id":"w1","daemon_id":null,"name":"MacBook",
          "runtime_mode":"cloud","provider":"multica","launch_header":"",
          "status":"online","device_info":"","metadata":{},"owner_id":null,
          "last_seen_at":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]
        """.data(using: .utf8)!
    }

    private static func membersJSON() -> Data {
        """
        [{"id":"m1","workspace_id":"w1","user_id":"u1","role":"owner",
          "name":"Parker","email":"p@example.com","avatar_url":null}]
        """.data(using: .utf8)!
    }

    private static func agentsJSON() -> Data {
        """
        [{
          "id":"a1","workspace_id":"w1","runtime_id":"r1","name":"Codex",
          "description":"","instructions":"","avatar_url":null,"runtime_mode":"local",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"idle","max_concurrent_tasks":1,"model":"gpt-5",
          "owner_id":"u1","archived_at":null,
          "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"
        }, {
          "id":"a2","workspace_id":"w1","runtime_id":"other","name":"Other Agent",
          "description":"","instructions":"","avatar_url":null,"runtime_mode":"local",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"idle","max_concurrent_tasks":1,"model":"gpt-5",
          "owner_id":"u1","archived_at":null,
          "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"
        }]
        """.data(using: .utf8)!
    }

    private static func runtimeUsageJSON() -> Data {
        """
        [{"runtime_id":"r1","date":"2026-01-01","provider":"anthropic","model":"claude-sonnet-4",
          "input_tokens":1000,"output_tokens":2000,"cache_read_tokens":300,"cache_write_tokens":400}]
        """.data(using: .utf8)!
    }

    private static func runtimeActivityJSON() -> Data {
        """
        [{"hour":"2026-01-01T00:00:00Z","queued":1,"running":2,"completed":3,"failed":4,"cancelled":5}]
        """.data(using: .utf8)!
    }

    private static func runtimeUsageByAgentJSON() -> Data {
        """
        [{"agent_id":"a1","agent_name":"Codex","input_tokens":100,"output_tokens":200,
          "cache_read_tokens":30,"cache_write_tokens":40}]
        """.data(using: .utf8)!
    }

    private static func runtimeUsageByHourJSON() -> Data {
        """
        [{"hour":"2026-01-01T00:00:00Z","input_tokens":10,"output_tokens":20,
          "cache_read_tokens":3,"cache_write_tokens":4}]
        """.data(using: .utf8)!
    }

    private static func runtimeModelsJSON() -> Data {
        """
        {"id":"models-1","runtime_id":"r1","status":"completed",
         "models":[{"id":"m1","name":"gpt-5.1","provider":"openai"}]}
        """.data(using: .utf8)!
    }

    private static func runtimeLocalSkillsJSON() -> Data {
        """
        {"id":"skills-1","runtime_id":"r1","status":"completed",
         "skills":[{"id":"s1","name":"Writer","path":"/skills/writer"}]}
        """.data(using: .utf8)!
    }

    private static func runtimeUpdateJSON() -> Data {
        """
        {"id":"update-1","runtime_id":"r1","status":"pending",
         "target_version":"v1.2.3","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }

    private static func runtimeLocalSkillImportJSON() -> Data {
        """
        {"id":"import-1","runtime_id":"r1","skill_key":"review-helper",
         "name":"Review Helper","description":"Review pull requests",
         "status":"pending","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }
}
