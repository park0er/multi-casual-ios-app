import XCTest
@testable import MultiCasual

@MainActor
final class NotificationPreferencesViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadTreatsMissingPreferencesAsEnabled() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/notification-preferences")
            XCTAssertEqual(req.url?.query, "workspace_id=w1")
            return Self.response(
                for: req,
                body: Data(#"{"workspace_id":"w1","preferences":{"comments":"muted"}}"#.utf8)
            )
        }
        let vm = NotificationPreferencesViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.value(for: .comments), .muted)
        XCTAssertEqual(vm.value(for: .assignments), .all)
        XCTAssertNil(vm.errorMessage)
    }

    func test_togglePersistsMutedPreferenceAndUpdatesLocalState() async throws {
        var requests: [String] = []
        var updateBody: [String: Any]?
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            if req.httpMethod == "PUT" {
                let requestBody = MockURLProtocol.bodyData(for: req)
                updateBody = requestBody.isEmpty
                    ? nil
                    : (try? JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
                return Self.response(
                    for: req,
                    body: Data(#"{"workspace_id":"w1","preferences":{"agent_activity":"muted"}}"#.utf8)
                )
            }
            return Self.response(
                for: req,
                body: Data(#"{"workspace_id":"w1","preferences":{}}"#.utf8)
            )
        }
        let vm = NotificationPreferencesViewModel(api: client, authSession: makeSession())

        await vm.load()
        await vm.set(.agentActivity, enabled: false)

        XCTAssertEqual(requests, [
            "GET /api/notification-preferences",
            "PUT /api/notification-preferences",
        ])
        XCTAssertEqual((updateBody?["preferences"] as? [String: String])?["agent_activity"], "muted")
        XCTAssertEqual(vm.value(for: .agentActivity), .muted)
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multi-casual.app.notification-prefs.test"))
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
