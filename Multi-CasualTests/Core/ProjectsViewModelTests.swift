import XCTest
@testable import MultiCasual

@MainActor
final class ProjectsViewModelTests: XCTestCase {
    private let workspace = Workspace(
        id: "w1",
        name: "Workspace",
        slug: "workspace",
        issuePrefix: "PAR",
        repos: [
            WorkspaceRepo(url: "https://github.com/multica-ai/multica", defaultBranchHint: "main")
        ]
    )

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

        let created = await vm.createProject(
            title: "Beta",
            description: "**Docs**",
            status: .planned,
            priority: .medium,
            icon: "📱",
            leadType: "agent",
            leadId: "a1",
            resourceURLs: ["https://github.com/multica-ai/multica"]
        )
        let updated = await vm.updateProject(
            id: "p1",
            title: "Alpha Edited",
            description: nil,
            status: .paused,
            priority: .high,
            icon: nil,
            leadType: nil,
            leadId: nil
        )
        await vm.deleteProject(id: "p2")

        XCTAssertEqual(created?.id, "p2")
        XCTAssertEqual(updated?.name, "Alpha Edited")
        XCTAssertEqual(vm.loader.items.map(\.name), ["Alpha Edited"])
        XCTAssertEqual(requests.map(\.method), ["POST", "PUT", "DELETE"])
        XCTAssertEqual(requests.map(\.workspaceId), ["w1", "w1", "w1"])
        XCTAssertEqual(requests[0].body?["description"] as? String, "**Docs**")
        XCTAssertEqual(requests[0].body?["icon"] as? String, "📱")
        XCTAssertEqual(requests[0].body?["lead_type"] as? String, "agent")
        XCTAssertEqual(requests[0].body?["lead_id"] as? String, "a1")
        let resources = requests[0].body?["resources"] as? [[String: Any]]
        XCTAssertEqual((resources?.first?["resource_ref"] as? [String: Any])?["url"] as? String, "https://github.com/multica-ai/multica")
        XCTAssertTrue(requests[1].body?["description"] is NSNull)
        XCTAssertTrue(requests[1].body?["icon"] is NSNull)
        XCTAssertTrue(requests[1].body?["lead_type"] is NSNull)
        XCTAssertTrue(requests[1].body?["lead_id"] is NSNull)
        XCTAssertNil(vm.lastError)
    }

    func test_loadProjectOptionsBuildsLeadChoicesAndWorkspaceRepos() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/workspaces/w1/members":
                let json = """
                [{"id":"m1","workspace_id":"w1","user_id":"u1","role":"owner",
                  "created_at":"2026-01-01T00:00:00Z","name":"Parker",
                  "email":"p@example.com","avatar_url":null}]
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/agents":
                let json = """
                [{"id":"a1","workspace_id":"w1","runtime_id":"r1","name":"Codex",
                  "description":"","instructions":"","avatar_url":null,"runtime_mode":"cloud",
                  "runtime_config":{},"custom_env":{},"custom_args":[],"custom_env_redacted":false,
                  "visibility":"workspace","status":"active","max_concurrent_tasks":1,
                  "model":"gpt","owner_id":null,"skills":[],"created_at":"2026-01-01T00:00:00Z",
                  "updated_at":"2026-01-01T00:00:00Z","archived_at":null,"archived_by":null}]
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/squads":
                return Self.response(for: req, body: Data(#"{"squads":[]}"#.utf8))
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ProjectsViewModel(api: client, authSession: makeSession())

        await vm.loadProjectOptions()

        XCTAssertEqual(vm.projectLeadOptions.map(\.id), ["member:u1", "agent:a1"])
        XCTAssertEqual(vm.workspaceRepoURLs, ["https://github.com/multica-ai/multica"])
        XCTAssertNil(vm.lastError)
    }

    func test_searchQueryUsesDesktopSearchEndpointAndReplacesProjects() async throws {
        var requested: [(path: String, query: [URLQueryItem])] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            requested.append((req.url?.path ?? "", components?.queryItems ?? []))
            switch req.url?.path {
            case "/api/projects/search":
                let json = """
                {"projects":[{"id":"p1","workspace_id":"w1","title":"Mobile App","description":null,
                 "icon":"📱","status":"active","priority":"high",
                 "lead_type":null,"lead_id":null,"created_at":"2026-01-01T00:00:00Z",
                 "updated_at":"2026-01-01T00:00:00Z","issue_count":2,"done_count":1}],
                 "has_more":false,"total":1}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/squads":
                return Self.response(for: req, body: Data(#"{"squads":[]}"#.utf8))
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ProjectsViewModel(api: client, authSession: makeSession())

        await vm.setSearchQuery("Mobile")

        XCTAssertEqual(vm.searchQuery, "Mobile")
        XCTAssertEqual(vm.loader.items.map(\.name), ["Mobile App"])
        XCTAssertFalse(vm.loader.hasMore)
        XCTAssertEqual(requested.first?.path, "/api/projects/search")
        XCTAssertEqual(requested.first?.query.first(where: { $0.name == "q" })?.value, "Mobile")
        XCTAssertEqual(requested.first?.query.first(where: { $0.name == "workspace_id" })?.value, "w1")
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
        let session = AuthSession(keychain: KeychainStore(service: "ai.multi-casual.app.projects.test"), userDefaults: makeUserDefaults())
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
         "icon":"📱","status":"\(status)","priority":"high",
         "lead_type":"agent","lead_id":"a1","created_at":"2026-01-01T00:00:00Z",
         "updated_at":"2026-01-01T00:00:00Z","issue_count":0,"done_count":0}
        """.data(using: .utf8)!
    }
}
