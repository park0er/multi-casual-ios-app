import XCTest
@testable import MultiCasual

@MainActor
final class WorkspaceMembersViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func test_loadFetchesMembersAndPendingInvitations() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch req.url?.path {
            case "/api/workspaces/w1/members":
                return Self.response(for: req, body: "[\(String(data: Self.memberJSON(id: "m1", name: "Parker", role: "owner"), encoding: .utf8)!)]".data(using: .utf8)!)
            case "/api/workspaces/w1/invitations":
                return Self.response(for: req, body: "[\(String(data: Self.invitationJSON(id: "inv1", email: "new@example.com"), encoding: .utf8)!)]".data(using: .utf8)!)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data(), status: 404)
            }
        }
        let vm = WorkspaceMembersViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.members.map(\.id), ["m1"])
        XCTAssertEqual(vm.invitations.map(\.id), ["inv1"])
        XCTAssertEqual(Set(requests), Set(["GET /api/workspaces/w1/members", "GET /api/workspaces/w1/invitations"]))
        XCTAssertNil(vm.errorMessage)
    }

    func test_inviteUpdateRemoveAndRevokeKeepListsInSync() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/workspaces/w1/members"):
                return Self.response(for: req, body: Self.invitationJSON(id: "inv1", email: "new@example.com"))
            case ("PATCH", "/api/workspaces/w1/members/m1"):
                return Self.response(for: req, body: Self.memberJSON(id: "m1", name: "Parker", role: "admin"))
            case ("DELETE", "/api/workspaces/w1/members/m1"):
                return Self.response(for: req, body: Data(), status: 204)
            case ("DELETE", "/api/workspaces/w1/invitations/inv1"):
                return Self.response(for: req, body: Data(), status: 204)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data(), status: 404)
            }
        }
        let vm = WorkspaceMembersViewModel(api: client, authSession: makeSession())
        let decoder = JSONDecoder()
        vm.members = [try decoder.decode(WorkspaceMember.self, from: Self.memberJSON(id: "m1", name: "Parker", role: "member"))]
        vm.invitations = [try decoder.decode(Invitation.self, from: Self.invitationJSON(id: "inv1", email: "new@example.com"))]

        let invited = await vm.inviteMember(email: "new@example.com", role: "member")
        let updated = await vm.updateMemberRole(memberId: "m1", role: "admin")
        await vm.removeMember(id: "m1")
        await vm.revokeInvitation(id: "inv1")

        XCTAssertEqual(invited?.id, "inv1")
        XCTAssertEqual(updated?.role, "admin")
        XCTAssertTrue(vm.members.isEmpty)
        XCTAssertTrue(vm.invitations.isEmpty)
        XCTAssertEqual(requests, [
            "POST /api/workspaces/w1/members",
            "PATCH /api/workspaces/w1/members/m1",
            "DELETE /api/workspaces/w1/members/m1",
            "DELETE /api/workspaces/w1/invitations/inv1",
        ])
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multi-casual.app.workspace-members.test"))
        session.currentWorkspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "W")
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

    private static func memberJSON(id: String, name: String, role: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","user_id":"u1","role":"\(role)",
         "created_at":"2026-01-01T00:00:00Z","name":"\(name)",
         "email":"p@example.com","avatar_url":null}
        """.data(using: .utf8)!
    }

    private static func invitationJSON(id: String, email: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","email":"\(email)","role":"member",
         "status":"pending","created_at":"2026-01-01T00:00:00Z","expires_at":null}
        """.data(using: .utf8)!
    }
}
