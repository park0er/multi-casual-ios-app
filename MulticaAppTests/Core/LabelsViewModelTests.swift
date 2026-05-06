import XCTest
@testable import MultiCasual

@MainActor
final class LabelsViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func test_loadFetchesLabelsForCurrentWorkspace() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/labels")
            XCTAssertEqual(req.url?.query, "workspace_id=w1")
            return Self.response(for: req, body: #"{"labels":[\#(String(data: Self.labelJSON(id: "l1", name: "Bug", color: "#ef4444"), encoding: .utf8)!)],"total":1}"#.data(using: .utf8)!)
        }
        let vm = LabelsViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.labels.map(\.id), ["l1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_createUpdateAndDeleteKeepListInSync() async throws {
        var requests: [String] = []
        var workspaceIds: [String?] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            workspaceIds.append(URLComponents(url: req.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "workspace_id" })?.value)
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/labels"):
                return Self.response(for: req, body: Self.labelJSON(id: "l2", name: "Feature", color: "#22c55e"))
            case ("PUT", "/api/labels/l1"):
                return Self.response(for: req, body: Self.labelJSON(id: "l1", name: "Urgent", color: "#f97316"))
            case ("DELETE", "/api/labels/l2"):
                return Self.response(for: req, body: Data(), status: 204)
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data(), status: 404)
            }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let vm = LabelsViewModel(api: client, authSession: makeSession())
        vm.labels = [try decoder.decode(IssueLabel.self, from: Self.labelJSON(id: "l1", name: "Bug", color: "#ef4444"))]

        let created = await vm.createLabel(name: " Feature ", color: "#22c55e")
        let updated = await vm.updateLabel(id: "l1", name: "Urgent", color: "#f97316")
        await vm.deleteLabel(id: "l2")

        XCTAssertEqual(created?.id, "l2")
        XCTAssertEqual(updated?.name, "Urgent")
        XCTAssertEqual(vm.labels.map(\.name), ["Urgent"])
        XCTAssertEqual(requests, [
            "POST /api/labels",
            "PUT /api/labels/l1",
            "DELETE /api/labels/l2",
        ])
        XCTAssertEqual(workspaceIds, ["w1", "w1", "w1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_missingWorkspaceShowsActionableErrorAndSkipsRequest() async {
        var didRequest = false
        let client = makeClient { req in
            didRequest = true
            return Self.response(for: req, body: Data(), status: 500)
        }
        let vm = LabelsViewModel(api: client, authSession: AuthSession(keychain: KeychainStore(service: "ai.multica.app.labels.empty.test")))

        await vm.load()

        XCTAssertFalse(didRequest)
        XCTAssertEqual(vm.errorMessage, "Pick a workspace before managing labels.")
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.labels.test"))
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

    private static func response(for request: URLRequest, body: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, body)
    }

    private static func labelJSON(id: String, name: String, color: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","name":"\(name)","color":"\(color)",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }
}
