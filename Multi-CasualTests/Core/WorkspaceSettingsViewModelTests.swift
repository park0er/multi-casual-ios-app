import XCTest
@testable import MultiCasual

@MainActor
final class WorkspaceSettingsViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func test_loadFetchesCurrentWorkspaceAndPopulatesEditableFields() async throws {
        var capturedURL: URL?
        let client = makeClient { req in
            capturedURL = req.url
            XCTAssertEqual(req.httpMethod, "GET")
            XCTAssertEqual(req.url?.path, "/api/workspaces/w1")
            return Self.response(for: req, body: Self.workspaceJSON(name: "Workspace", description: "Docs", context: "Use **Markdown**"))
        }
        let vm = WorkspaceSettingsViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(capturedURL?.query, "workspace_id=w1")
        XCTAssertEqual(vm.name, "Workspace")
        XCTAssertEqual(vm.description, "Docs")
        XCTAssertEqual(vm.context, "Use **Markdown**")
        XCTAssertEqual(vm.repoText, "https://github.com/multica-ai/multica")
        XCTAssertNil(vm.errorMessage)
    }

    func test_saveUpdatesWorkspaceAndAuthSession() async throws {
        var requestBody: [String: Any] = [:]
        let client = makeClient { req in
            XCTAssertEqual(req.httpMethod, "PATCH")
            XCTAssertEqual(req.url?.path, "/api/workspaces/w1")
            XCTAssertEqual(req.url?.query, "workspace_id=w1")
            requestBody = try JSONSerialization.jsonObject(with: MockURLProtocol.bodyData(for: req)) as? [String: Any] ?? [:]
            return Self.response(for: req, body: Self.workspaceJSON(name: "Updated", description: nil, context: "New context"))
        }
        let session = makeSession()
        let vm = WorkspaceSettingsViewModel(api: client, authSession: session)
        vm.name = "Updated"
        vm.description = "   "
        vm.context = "New context"
        vm.repoText = """
        https://github.com/multica-ai/multica

        https://github.com/multica-ai/ios
        """

        let updated = await vm.save()

        XCTAssertEqual(updated?.name, "Updated")
        XCTAssertEqual(session.currentWorkspace?.name, "Updated")
        XCTAssertEqual(session.workspaces.first?.name, "Updated")
        XCTAssertEqual(requestBody["name"] as? String, "Updated")
        XCTAssertTrue(requestBody["description"] is NSNull)
        XCTAssertEqual(requestBody["context"] as? String, "New context")
        let repos = requestBody["repos"] as? [[String: Any]]
        XCTAssertEqual(repos?.map { $0["url"] as? String }, [
            "https://github.com/multica-ai/multica",
            "https://github.com/multica-ai/ios",
        ])
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multi-casual.app.workspace-settings.test"), userDefaults: UserDefaults(suiteName: "WorkspaceSettingsViewModelTests.\(UUID().uuidString)")!)
        let workspace = Workspace(
            id: "w1",
            name: "Workspace",
            slug: "workspace",
            issuePrefix: "PAR",
            description: nil,
            context: nil,
            repos: [WorkspaceRepo(url: "https://github.com/multica-ai/multica")]
        )
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

    private static func workspaceJSON(name: String, description: String?, context: String?) -> Data {
        let descriptionValue = description.map { "\"\($0)\"" } ?? "null"
        let contextValue = context.map { "\"\($0)\"" } ?? "null"
        return """
        {"id":"w1","name":"\(name)","slug":"workspace","description":\(descriptionValue),
         "context":\(contextValue),"issue_prefix":"PAR",
         "repos":[{"url":"https://github.com/multica-ai/multica","default_branch_hint":null}]}
        """.data(using: .utf8)!
    }
}
