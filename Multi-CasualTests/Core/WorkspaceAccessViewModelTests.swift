import XCTest
@testable import MultiCasual

@MainActor
final class WorkspaceAccessViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func test_loadFetchesMyInvitations() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.httpMethod, "GET")
            XCTAssertEqual(req.url?.path, "/api/invitations")
            return Self.response(for: req, body: "[\(String(data: Self.invitationJSON(id: "inv1", workspaceId: "w2"), encoding: .utf8)!)]".data(using: .utf8)!)
        }
        let vm = WorkspaceAccessViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.invitations.map(\.id), ["inv1"])
        XCTAssertEqual(vm.invitations.first?.workspaceName, "Beta")
        XCTAssertNil(vm.errorMessage)
    }

    func test_createWorkspaceAddsAndSelectsWorkspace() async throws {
        var body: [String: Any] = [:]
        let client = makeClient { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/api/workspaces")
            body = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return Self.response(for: req, body: Self.workspaceJSON(id: "w2", name: "Beta", slug: "beta"))
        }
        let session = makeSession()
        let vm = WorkspaceAccessViewModel(api: client, authSession: session)

        let workspace = await vm.createWorkspace(name: "Beta", slug: "beta", description: "Docs", context: "Use **Markdown**")

        XCTAssertEqual(workspace?.id, "w2")
        XCTAssertEqual(session.workspaces.map(\.id), ["w1", "w2"])
        XCTAssertEqual(session.currentWorkspace?.id, "w2")
        XCTAssertEqual(body["name"] as? String, "Beta")
        XCTAssertEqual(body["slug"] as? String, "beta")
        XCTAssertEqual(body["description"] as? String, "Docs")
        XCTAssertEqual(body["context"] as? String, "Use **Markdown**")
        XCTAssertNil(vm.errorMessage)
    }

    func test_leaveAndDeleteWorkspaceRemoveFromSessionAndFallbackSelection() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")?\(req.url?.query ?? "")")
            return Self.response(for: req, body: Data(), status: 204)
        }
        let session = makeSession(extraWorkspace: Workspace(id: "w2", name: "Beta", slug: "beta", issuePrefix: "BET"))
        session.setWorkspace(session.workspaces[1])
        let vm = WorkspaceAccessViewModel(api: client, authSession: session)

        await vm.leaveWorkspace(id: "w2")
        await vm.deleteWorkspace(id: "w1")

        XCTAssertTrue(session.workspaces.isEmpty)
        XCTAssertNil(session.currentWorkspace)
        XCTAssertEqual(requests, [
            "POST /api/workspaces/w2/leave?workspace_id=w2",
            "DELETE /api/workspaces/w1?workspace_id=w1",
        ])
        XCTAssertNil(vm.errorMessage)
    }

    func test_acceptAndDeclineInvitationUpdateInvitationsAndWorkspaces() async throws {
        var requestIndex = 0
        let client = makeClient { req in
            defer { requestIndex += 1 }
            switch (req.httpMethod, req.url?.path, requestIndex) {
            case ("POST", "/api/invitations/inv1/accept", 0):
                return Self.response(for: req, body: Self.memberJSON(workspaceId: "w2"))
            case ("GET", "/api/workspaces", 1):
                let workspaces = [
                    String(data: Self.workspaceJSON(id: "w1", name: "Workspace", slug: "workspace"), encoding: .utf8)!,
                    String(data: Self.workspaceJSON(id: "w2", name: "Beta", slug: "beta"), encoding: .utf8)!,
                ].joined(separator: ",")
                return Self.response(for: req, body: "[\(workspaces)]".data(using: .utf8)!)
            case ("POST", "/api/invitations/inv2/decline", 2):
                return Self.response(for: req, body: Data(), status: 204)
            default:
                XCTFail("Unexpected request \(requestIndex): \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data(), status: 404)
            }
        }
        let session = makeSession()
        let vm = WorkspaceAccessViewModel(api: client, authSession: session)
        vm.invitations = [
            try JSONDecoder().decode(Invitation.self, from: Self.invitationJSON(id: "inv1", workspaceId: "w2")),
            try JSONDecoder().decode(Invitation.self, from: Self.invitationJSON(id: "inv2", workspaceId: "w3")),
        ]

        let accepted = await vm.acceptInvitation(id: "inv1")
        await vm.declineInvitation(id: "inv2")

        XCTAssertEqual(accepted?.workspaceId, "w2")
        XCTAssertTrue(vm.invitations.isEmpty)
        XCTAssertEqual(session.workspaces.map(\.id), ["w1", "w2"])
        XCTAssertEqual(session.currentWorkspace?.id, "w2")
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession(extraWorkspace: Workspace? = nil) -> AuthSession {
        let session = AuthSession(
            keychain: KeychainStore(service: "ai.multi-casual.app.workspace-access.test.\(UUID().uuidString)"),
            userDefaults: UserDefaults(suiteName: "WorkspaceAccessViewModelTests.\(UUID().uuidString)")!
        )
        let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "W")
        session.currentWorkspace = workspace
        session.workspaces = [workspace] + (extraWorkspace.map { [$0] } ?? [])
        return session
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return APIClient(session: URLSession(configuration: config), token: "test-token")
    }

    private static func response(for request: URLRequest, body: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, body)
    }

    private static func workspaceJSON(id: String, name: String, slug: String) -> Data {
        """
        {"id":"\(id)","name":"\(name)","slug":"\(slug)","description":null,
         "context":null,"issue_prefix":"BET","repos":[]}
        """.data(using: .utf8)!
    }

    private static func invitationJSON(id: String, workspaceId: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"\(workspaceId)","inviter_id":"u1",
         "invitee_email":"me@example.com","invitee_user_id":null,"role":"member",
         "status":"pending","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z","expires_at":"2026-02-01T00:00:00Z",
         "workspace_name":"Beta","inviter_name":"Parker","inviter_email":"p@example.com"}
        """.data(using: .utf8)!
    }

    private static func memberJSON(workspaceId: String) -> Data {
        """
        {"id":"m1","workspace_id":"\(workspaceId)","user_id":"u2","role":"member",
         "created_at":"2026-01-01T00:00:00Z","name":"Me",
         "email":"me@example.com","avatar_url":null}
        """.data(using: .utf8)!
    }
}
