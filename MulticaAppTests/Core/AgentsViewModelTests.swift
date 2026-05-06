import XCTest
@testable import MultiCasual

@MainActor
final class AgentsViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadFetchesArchivedAgentsAndRuntimes() async throws {
        var requestURLs: [URL] = []
        let client = makeClient { req in
            requestURLs.append(req.url!)
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
        XCTAssertTrue(requestURLs.allSatisfy { $0.absoluteString.contains("workspace_id=w1") })
        XCTAssertNil(vm.errorMessage)
    }

    func test_createAndUpdateReplaceAgentInList() async throws {
        var requests: [(String, String)] = []
        var requestURLs: [URL] = []
        var bodies: [[String: Any]] = []
        let client = makeClient { req in
            requests.append((req.httpMethod ?? "", req.url?.path ?? ""))
            requestURLs.append(req.url!)
            bodies.append((try? JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any]) ?? [:])
            let name = req.httpMethod == "POST" ? "Created" : "Updated"
            return Self.response(for: req, body: Self.agentJSON(id: "a1", name: name))
        }
        let vm = AgentsViewModel(api: client, authSession: makeSession())

        let created = await vm.createAgent(
            name: "Created",
            description: "",
            instructions: "",
            runtimeId: "r1",
            visibility: "workspace",
            maxConcurrentTasks: 1,
            model: "gpt",
            customEnv: ["ANTHROPIC_BASE_URL": "https://example.com"],
            customArgs: ["--verbose"]
        )
        let updated = await vm.updateAgent(
            id: "a1",
            name: "Updated",
            description: "D",
            instructions: "I",
            visibility: "private",
            maxConcurrentTasks: 2,
            model: "gpt-5",
            customEnv: ["OPENAI_API_KEY": "sk-test"],
            customArgs: ["--debug"]
        )

        XCTAssertEqual(created?.name, "Created")
        XCTAssertEqual(updated?.name, "Updated")
        XCTAssertEqual(vm.agents.map(\.name), ["Updated"])
        XCTAssertEqual(requests.map { "\($0.0) \($0.1)" }, ["POST /api/agents", "PUT /api/agents/a1"])
        XCTAssertTrue(requestURLs.allSatisfy { $0.absoluteString.contains("workspace_id=w1") })
        XCTAssertEqual((bodies[0]["custom_env"] as? [String: String])?["ANTHROPIC_BASE_URL"], "https://example.com")
        XCTAssertEqual(bodies[0]["custom_args"] as? [String], ["--verbose"])
        XCTAssertEqual((bodies[1]["custom_env"] as? [String: String])?["OPENAI_API_KEY"], "sk-test")
        XCTAssertEqual(bodies[1]["custom_args"] as? [String], ["--debug"])
        XCTAssertNil(vm.errorMessage)
    }

    func testArchiveRestoreAndCancelTasksSurfaceResults() async throws {
        var requestURLs: [URL] = []
        let client = makeClient { req in
            requestURLs.append(req.url!)
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
        XCTAssertTrue(requestURLs.allSatisfy { $0.absoluteString.contains("workspace_id=w1") })
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadSkillOptionsFetchesAvailableAndAssignedSkills() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch req.url?.path {
            case "/api/skills":
                return Self.response(for: req, body: "[\(String(data: Self.skillJSON(id: "s1", name: "Writer"), encoding: .utf8)!),\(String(data: Self.skillJSON(id: "s2", name: "Reviewer"), encoding: .utf8)!)]".data(using: .utf8)!)
            case "/api/agents/a1/skills":
                return Self.response(for: req, body: "[\(String(data: Self.skillJSON(id: "s2", name: "Reviewer"), encoding: .utf8)!)]".data(using: .utf8)!)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = AgentsViewModel(api: client, authSession: makeSession())

        await vm.loadSkillOptions(for: "a1")

        XCTAssertEqual(vm.skills.map(\.id), ["s2", "s1"])
        XCTAssertEqual(vm.assignedSkillIdsByAgentId["a1"], Set(["s2"]))
        XCTAssertEqual(Set(requests), Set(["GET /api/skills", "GET /api/agents/a1/skills"]))
        XCTAssertNil(vm.errorMessage)
    }

    func test_agentDetailLoadsOwnerRuntimeAndTasks() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch req.url?.path {
            case "/api/workspaces/w1/members":
                return Self.response(for: req, body: Self.membersJSON())
            case "/api/runtimes":
                return Self.response(for: req, body: Self.runtimeListJSON())
            case "/api/agents/a1/tasks":
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                return Self.response(for: req, body: Self.agentTasksJSON())
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let agent = try decoder.decode(Agent.self, from: Self.agentJSON(id: "a1", name: "Codex", ownerId: "u1"))
        let vm = AgentDetailViewModel(agent: agent, api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(Set(requests), Set([
            "GET /api/workspaces/w1/members",
            "GET /api/runtimes",
            "GET /api/agents/a1/tasks",
        ]))
        XCTAssertEqual(vm.ownerName, "Parker")
        XCTAssertEqual(vm.runtimeName, "MacBook")
        XCTAssertEqual(vm.activeTasks.map(\.id), ["t2"])
        XCTAssertEqual(vm.recentTasks.map(\.id), ["t1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_updateAgentSavesSkillAssignments() async throws {
        var requests: [String] = []
        var skillBody: [String: Any] = [:]
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch (req.httpMethod, req.url?.path) {
            case ("PUT", "/api/agents/a1"):
                return Self.response(for: req, body: Self.agentJSON(id: "a1", name: "Updated"))
            case ("PUT", "/api/agents/a1/skills"):
                skillBody = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                return Self.response(for: req, body: Data(), status: 204)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = AgentsViewModel(api: client, authSession: makeSession())

        let updated = await vm.updateAgent(
            id: "a1",
            name: "Updated",
            description: "D",
            instructions: "I",
            visibility: "private",
            maxConcurrentTasks: 2,
            model: "gpt-5",
            skillIds: Set(["s2", "s1"])
        )

        XCTAssertEqual(updated?.name, "Updated")
        XCTAssertEqual(vm.assignedSkillIdsByAgentId["a1"], Set(["s1", "s2"]))
        XCTAssertEqual(skillBody["skill_ids"] as? [String], ["s1", "s2"])
        XCTAssertEqual(requests, ["PUT /api/agents/a1", "PUT /api/agents/a1/skills"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_agentFormDraftParsesCustomEnvironmentAndArgs() throws {
        let env = try AgentFormDraft.parseCustomEnvironment(
            """
            ANTHROPIC_BASE_URL=https://example.com
            OPENAI_API_KEY = sk-test

            EMPTY=
            """
        )
        let args = AgentFormDraft.parseCustomArgs("--verbose\n--model gpt-5  --debug")

        XCTAssertEqual(env["ANTHROPIC_BASE_URL"], "https://example.com")
        XCTAssertEqual(env["OPENAI_API_KEY"], "sk-test")
        XCTAssertEqual(env["EMPTY"], "")
        XCTAssertEqual(args, ["--verbose", "--model", "gpt-5", "--debug"])
    }

    func test_agentFormDraftRejectsDuplicateEnvironmentKeys() throws {
        XCTAssertThrowsError(
            try AgentFormDraft.parseCustomEnvironment(
                """
                OPENAI_API_KEY=one
                OPENAI_API_KEY=two
                """
            )
        ) { error in
            XCTAssertEqual(error as? AgentFormDraft.ValidationError, .duplicateEnvironmentKey("OPENAI_API_KEY"))
        }
    }

    func test_agentFormDraftFormatsExistingEnvironmentAndArgs() {
        let envText = AgentFormDraft.environmentText(from: [
            "B": .string("two"),
            "A": .string("one"),
            "OBJECT": .object(["x": .string("ignored")]),
        ])
        let argsText = AgentFormDraft.argsText(from: ["--model", "gpt-5"])

        XCTAssertEqual(envText, "A=one\nB=two")
        XCTAssertEqual(argsText, "--model\ngpt-5")
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

    private static func agentJSON(id: String, name: String, ownerId: String? = nil) -> Data {
        let ownerJSON = ownerId.map { "\"\($0)\"" } ?? "null"
        return """
        {"id":"\(id)","workspace_id":"w1","runtime_id":"r1","name":"\(name)",
          "description":"**Markdown** description","instructions":"Be useful","avatar_url":null,"runtime_mode":"cloud",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"idle","max_concurrent_tasks":1,
          "model":"gpt","owner_id":\(ownerJSON),"skills":[],"created_at":"2026-01-01T00:00:00Z",
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

    private static func membersJSON() -> Data {
        """
        [{"id":"m1","workspace_id":"w1","user_id":"u1","role":"owner",
          "name":"Parker","email":"p@example.com","avatar_url":null}]
        """.data(using: .utf8)!
    }

    private static func agentTasksJSON() -> Data {
        """
        [
          {"id":"t1","agent_id":"a1","issue_id":"i1","status":"completed",
           "started_at":"2026-01-01T00:00:00Z","completed_at":"2026-01-01T00:05:00Z","error":null},
          {"id":"t2","agent_id":"a1","issue_id":"i2","status":"running",
           "started_at":"2026-01-02T00:00:00Z","completed_at":null,"error":null}
        ]
        """.data(using: .utf8)!
    }

    private static func skillJSON(id: String, name: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","name":"\(name)","description":"**Useful** skill",
         "content":"# Skill","config":{},"files":[],"created_by":"u1",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }
}
