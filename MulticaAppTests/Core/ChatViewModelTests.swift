import XCTest
@testable import MultiCasual

@MainActor
final class ChatViewModelTests: XCTestCase {
    func test_loadFetchesSessionsAgentsAndPendingTasksForCurrentWorkspace() async throws {
        var requested: [(method: String?, path: String, workspaceId: String?)] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            requested.append((
                req.httpMethod,
                req.url?.path ?? "",
                components?.queryItems?.first(where: { $0.name == "workspace_id" })?.value
            ))
            switch (req.httpMethod, req.url?.path) {
            case ("GET", "/api/chat/sessions"):
                return Self.response(req, body: Self.chatSessionsJSON())
            case ("GET", "/api/chat/pending-tasks"):
                return Self.response(req, body: Self.pendingChatTasksJSON())
            case ("GET", "/api/agents"):
                return Self.response(req, body: "[\(String(data: Self.agentJSON(id: "a1", name: "Codex"), encoding: .utf8)!)]".data(using: .utf8)!)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ChatViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.sessions.map(\.id), ["c1"])
        XCTAssertEqual(vm.agentName(for: "a1"), "Codex")
        XCTAssertEqual(vm.pendingTasks.tasks.map(\.taskId), ["t1"])
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(requested.allSatisfy { $0.workspaceId == "w1" })
    }

    func test_createSessionSelectsNewSessionAndLoadsMessages() async throws {
        var requests: [(method: String?, path: String, body: [String: Any]?)] = []
        let client = makeClient { req in
            requests.append((
                req.httpMethod,
                req.url?.path ?? "",
                try? JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any]
            ))
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/chat/sessions"):
                return Self.response(req, body: Self.chatSessionJSON(id: "c2", title: "New **Chat**"))
            case ("GET", "/api/chat/sessions/c2/messages"):
                return Self.response(req, body: Self.chatMessagesJSON(sessionId: "c2"))
            case ("GET", "/api/chat/sessions/c2/pending-task"):
                return Self.response(req, body: Data("{}".utf8))
            case ("POST", "/api/chat/sessions/c2/read"):
                return Self.response(req, body: Data(), status: 204)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ChatViewModel(api: client, authSession: makeSession())

        await vm.createSession(agentId: "a1", title: "New **Chat**")

        XCTAssertEqual(vm.sessions.map(\.id), ["c2"])
        XCTAssertEqual(vm.selectedSession?.id, "c2")
        XCTAssertEqual(vm.messages.map(\.content), ["Hi", "Hello"])
        XCTAssertEqual(requests.first?.body?["agent_id"] as? String, "a1")
        XCTAssertEqual(requests.first?.body?["title"] as? String, "New **Chat**")
    }

    func test_sendMessageAddsOptimisticUserMessageAndRefreshesPendingTask() async throws {
        var sentBody: [String: Any] = [:]
        let client = makeClient { req in
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/chat/sessions/c1/messages"):
                sentBody = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
                return Self.response(req, body: Self.sendChatMessageJSON())
            case ("GET", "/api/chat/sessions/c1/pending-task"):
                return Self.response(req, body: Self.chatPendingTaskJSON())
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ChatViewModel(api: client, authSession: makeSession())
        vm.selectedSession = Self.chatSession(id: "c1")

        await vm.sendMessage("Please do **this**")

        XCTAssertEqual(sentBody["content"] as? String, "Please do **this**")
        XCTAssertEqual(vm.messages.last?.role, .user)
        XCTAssertEqual(vm.messages.last?.content, "Please do **this**")
        XCTAssertEqual(vm.pendingTask?.taskId, "t2")
        XCTAssertNil(vm.errorMessage)
    }

    func test_cancelPendingTaskClearsTaskAndRefreshesPendingTaskList() async throws {
        var requested: [(method: String?, path: String, workspaceId: String?)] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            requested.append((
                req.httpMethod,
                req.url?.path ?? "",
                components?.queryItems?.first(where: { $0.name == "workspace_id" })?.value
            ))
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/tasks/t2/cancel"):
                return Self.response(req, body: Data(), status: 204)
            case ("GET", "/api/chat/pending-tasks"):
                return Self.response(req, body: #"{"tasks":[]}"#.data(using: .utf8)!)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ChatViewModel(api: client, authSession: makeSession())
        vm.selectedSession = Self.chatSession(id: "c1")
        vm.pendingTask = ChatPendingTask(taskId: "t2", status: "running", createdAt: nil)
        vm.pendingTasks = PendingChatTasksResponse(tasks: [
            PendingChatTaskItem(taskId: "t2", status: "running", chatSessionId: "c1")
        ])

        await vm.cancelPendingTask()

        XCTAssertNil(vm.pendingTask?.taskId)
        XCTAssertTrue(vm.pendingTasks.tasks.isEmpty)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(
            requested.map { "\($0.method ?? "") \($0.path)" },
            ["POST /api/tasks/t2/cancel", "GET /api/chat/pending-tasks"]
        )
        XCTAssertTrue(requested.allSatisfy { $0.workspaceId == "w1" })
    }

    private static func chatSession(id: String) -> ChatSession {
        ChatSession(
            id: id,
            workspaceId: "w1",
            agentId: "a1",
            creatorId: "u1",
            title: "Launch **Plan**",
            status: .active,
            hasUnread: false,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(userDefaults: UserDefaults(suiteName: "ChatViewModelTests.\(UUID().uuidString)")!)
        session.currentUser = User(id: "u1", email: "u@example.com", name: "User", avatarUrl: nil)
        let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "W")
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

    private static func response(_ request: URLRequest, body: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            body
        )
    }

    private static func chatSessionJSON(id: String, title: String = "Launch **Plan**") -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","agent_id":"a1","creator_id":"u1",
         "title":"\(title)","status":"active","has_unread":true,
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:01:00Z"}
        """.data(using: .utf8)!
    }

    private static func chatSessionsJSON() -> Data {
        "[\(String(data: chatSessionJSON(id: "c1"), encoding: .utf8)!)]".data(using: .utf8)!
    }

    private static func chatMessagesJSON(sessionId: String = "c1") -> Data {
        """
        [
          {"id":"m1","chat_session_id":"\(sessionId)","role":"user","content":"Hi",
           "task_id":null,"created_at":"2026-01-01T00:00:01Z","failure_reason":null,"elapsed_ms":null},
          {"id":"m2","chat_session_id":"\(sessionId)","role":"assistant","content":"Hello",
           "task_id":"t1","created_at":"2026-01-01T00:00:02Z","failure_reason":null,"elapsed_ms":1000}
        ]
        """.data(using: .utf8)!
    }

    private static func sendChatMessageJSON() -> Data {
        """
        {"message_id":"m3","task_id":"t2","created_at":"2026-01-01T00:00:03Z"}
        """.data(using: .utf8)!
    }

    private static func chatPendingTaskJSON() -> Data {
        """
        {"task_id":"t2","status":"running","created_at":"2026-01-01T00:00:03Z"}
        """.data(using: .utf8)!
    }

    private static func pendingChatTasksJSON() -> Data {
        """
        {"tasks":[{"task_id":"t1","status":"running","chat_session_id":"c1"}]}
        """.data(using: .utf8)!
    }

    private static func agentJSON(id: String, name: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","runtime_id":"r1","name":"\(name)",
          "description":"","instructions":"","avatar_url":null,"runtime_mode":"cloud",
          "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
          "visibility":"workspace","status":"idle","max_concurrent_tasks":1,
          "model":"gpt","owner_id":"u1","skills":[],"created_at":"2026-01-01T00:00:00Z",
          "updated_at":"2026-01-01T00:00:00Z","archived_at":null,"archived_by":null}
        """.data(using: .utf8)!
    }
}
