import Foundation
@testable import MultiCasual
import XCTest

@MainActor
final class PinToggleViewModelTests: XCTestCase {
    func test_loadAndTogglePinKeepsStateInSync() async throws {
        var requests: [(method: String?, path: String, query: String?, workspaceSlug: String?)] = []
        let client = makeClient { req in
            requests.append((req.httpMethod, req.url?.path ?? "", req.url?.query, req.value(forHTTPHeaderField: "X-Workspace-Slug")))
            switch (req.httpMethod, req.url?.path) {
            case ("GET", "/api/pins"):
                return Self.response(for: req, body: Self.pinsJSON(itemId: "i1"))
            case ("DELETE", "/api/pins/issue/i1"):
                return Self.response(for: req, body: Data(), status: 204)
            case ("POST", "/api/pins"):
                return Self.response(for: req, body: Self.pinJSON(itemId: "i1"))
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = PinToggleViewModel(itemType: .issue, itemId: "i1", api: client, authSession: makeSession())

        await vm.load()
        XCTAssertTrue(vm.isPinned)
        XCTAssertNil(vm.errorMessage)

        await vm.toggle()
        XCTAssertFalse(vm.isPinned)

        await vm.toggle()
        XCTAssertTrue(vm.isPinned)

        XCTAssertEqual(requests.map(\.method), ["GET", "DELETE", "POST"])
        XCTAssertEqual(requests.map(\.path), ["/api/pins", "/api/pins/issue/i1", "/api/pins"])
        XCTAssertEqual(requests.map(\.query), ["workspace_id=w1", "workspace_id=w1", "workspace_id=w1"])
        XCTAssertEqual(requests.map(\.workspaceSlug), ["park0er", "park0er", "park0er"])
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(
            keychain: KeychainStore(service: "ai.multica.app.pin-toggle.test"),
            userDefaults: UserDefaults(suiteName: "PinToggleViewModelTests.\(UUID().uuidString)")!
        )
        let workspace = Workspace(id: "w1", name: "Parker", slug: "park0er", issuePrefix: "PAR")
        session.workspaces = [workspace]
        session.currentWorkspace = workspace
        return session
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return APIClient(session: URLSession(configuration: config), token: "test-token")
    }

    private static func response(for request: URLRequest, body: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            body
        )
    }

    private static func pinsJSON(itemId: String) -> Data {
        Data("[\(String(data: pinJSON(itemId: itemId), encoding: .utf8)!)]".utf8)
    }

    private static func pinJSON(itemId: String) -> Data {
        """
        {"id":"pin1","workspace_id":"w1","user_id":"u1","item_type":"issue","item_id":"\(itemId)",
         "position":1,"created_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }
}
