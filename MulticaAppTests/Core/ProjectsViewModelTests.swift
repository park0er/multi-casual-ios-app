import XCTest
@testable import MultiCasual

@MainActor
final class ProjectsViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadNext_withoutWorkspaceSurfacesActionableError() async throws {
        let vm = ProjectsViewModel(api: makeClient(), authSession: AuthSession(userDefaults: makeUserDefaults()))

        await vm.loadNext()

        XCTAssertEqual(vm.lastError?.localizedDescription, "Pick a workspace before opening Projects.")
    }

    func test_createUpdateAndDeleteProjectKeepLoadedListInSync() async throws {
        var requests: [(method: String?, path: String, workspaceId: String?, body: [String: Any]?)] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            let workspaceId = components?.queryItems?.first(where: { $0.name == "workspace_id" })?.value
            let body: [String: Any]?
            let data = MockURLProtocol.bodyData(for: req)
            if !data.isEmpty {
                body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            } else {
                body = nil
            }
            requests.append((req.httpMethod, req.url?.path ?? "", workspaceId, body))
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/projects"):
                return Self.response(for: req, body: Self.projectJSON(id: "p2", title: "Beta", status: "planned"))
            case ("PUT", "/api/projects/p1"):
                return Self.response(for: req, body: Self.projectJSON(id: "p1", title: "Alpha Edited", status: "paused"))
            case ("DELETE", "/api/projects/p2"):
                return Self.response(for: req, body: Data(), status: 204)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ProjectsViewModel(api: client, authSession: makeSession())
        vm.loader.items = [
            Project(id: "p1", name: "Alpha", description: nil, workspaceId: "w1", createdAt: Date())
        ]

        let created = await vm.createProject(title: "Beta", description: "**Docs**", status: .planned, priority: .medium)
        let updated = await vm.updateProject(id: "p1", title: "Alpha Edited", description: nil, status: .paused, priority: .high)
        await vm.deleteProject(id: "p2")

        XCTAssertEqual(created?.id, "p2")
        XCTAssertEqual(updated?.name, "Alpha Edited")
        XCTAssertEqual(vm.loader.items.map(\.name), ["Alpha Edited"])
        XCTAssertEqual(requests.map(\.method), ["POST", "PUT", "DELETE"])
        XCTAssertEqual(requests.map(\.workspaceId), ["w1", "w1", "w1"])
        XCTAssertEqual(requests[0].body?["description"] as? String, "**Docs**")
        XCTAssertTrue(requests[1].body?["description"] is NSNull)
        XCTAssertNil(vm.lastError)
    }

    private func makeClient() -> APIClient {
        makeClient { req in
            XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
            return Self.response(for: req, body: Data(), status: 500)
        }
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return APIClient(session: URLSession(configuration: config), token: "test-token")
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.projects.test"), userDefaults: makeUserDefaults())
        session.currentWorkspace = workspace
        session.workspaces = [workspace]
        return session
    }

    private func makeUserDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ProjectsViewModelTests.\(UUID().uuidString)")!
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

    private static func projectJSON(id: String, title: String, status: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","title":"\(title)","description":null,
         "icon":null,"status":"\(status)","priority":"high",
         "lead_type":null,"lead_id":null,"created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z","issue_count":0,"done_count":0}
        """.data(using: .utf8)!
    }
}
