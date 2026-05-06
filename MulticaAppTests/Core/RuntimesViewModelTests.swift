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
}
