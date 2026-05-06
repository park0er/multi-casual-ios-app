import XCTest
@testable import MultiCasual

@MainActor
final class ProjectDetailViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")
    private let project = Project(
        id: "p1",
        name: "iOS MVP",
        description: "Mobile client",
        workspaceId: "w1",
        createdAt: Date(),
        issueCount: 2,
        doneCount: 1
    )

    func test_load_fetchesProjectIssuesAndResources() async throws {
        var issueRequests: [(status: String?, projectId: String?)] = []
        var resourcesWorkspaceIds: [String?] = []
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/issues":
                let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
                let status = components?.queryItems?.first(where: { $0.name == "status" })?.value
                let projectId = components?.queryItems?.first(where: { $0.name == "project_id" })?.value
                issueRequests.append((status, projectId))
                let json = """
                {"issues": [
                    {"id":"i1","identifier":"PAR-1","number":1,"title":"In project","description":null,
                     "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
                     "project_id":"p1","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"},
                    {"id":"i2","identifier":"PAR-2","number":2,"title":"Elsewhere","description":null,
                     "status":"todo","priority":"none","assignee_id":null,"assignee_type":null,
                     "project_id":"p2","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
                ], "total": 2}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            case "/api/projects/p1/resources":
                let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
                resourcesWorkspaceIds.append(components?.queryItems?.first(where: { $0.name == "workspace_id" })?.value)
                let json = """
                {"resources":[{
                    "id":"r1","project_id":"p1","workspace_id":"w1","resource_type":"github_repo",
                    "resource_ref":{"url":"https://github.com/multica-ai/multica","default_branch_hint":"main"},
                    "label":"Multica repo","position":0,"created_at":"2026-01-01T00:00:00Z","created_by":null
                }],"total":1}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ProjectDetailViewModel(project: project, api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.issues.map(\.id), ["i1"])
        XCTAssertEqual(issueRequests.map(\.status), ["backlog", "todo", "in_progress", "in_review", "done", "blocked"])
        XCTAssertEqual(issueRequests.map(\.projectId), Array(repeating: "p1", count: 6))
        XCTAssertEqual(resourcesWorkspaceIds, ["w1"])
        XCTAssertEqual(vm.resources.map(\.displayTitle), ["Multica repo"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_load_paginatesProjectIssuesWithinStatusBuckets() async throws {
        var issueRequests: [(status: String?, offset: String?)] = []
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/issues":
                let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
                let status = components?.queryItems?.first(where: { $0.name == "status" })?.value
                let offset = components?.queryItems?.first(where: { $0.name == "offset" })?.value
                issueRequests.append((status, offset))
                if status == "todo" && offset == "0" {
                    return Self.response(for: req, body: Self.issuesJSON([
                        Self.issueJSON(id: "i1", number: 1, status: "todo")
                    ], total: 2))
                }
                if status == "todo" && offset == "1" {
                    return Self.response(for: req, body: Self.issuesJSON([
                        Self.issueJSON(id: "i2", number: 2, status: "todo")
                    ], total: 2))
                }
                return Self.response(for: req, body: Self.issuesJSON([], total: 0))
            case "/api/projects/p1/resources":
                return Self.response(for: req, body: #"{"resources":[],"total":0}"#.data(using: .utf8)!)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ProjectDetailViewModel(project: project, api: client, authSession: makeSession())

        await vm.load()

        XCTAssertTrue(issueRequests.contains { $0.status == "todo" && $0.offset == "1" })
        XCTAssertEqual(vm.issues.map(\.id), ["i1", "i2"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_load_doesNotRequestProjectDataWhenCurrentWorkspaceDiffersFromProject() async throws {
        var didRequest = false
        let client = makeClient { req in
            didRequest = true
            XCTFail("Unexpected request for stale project route: \(req.url?.absoluteString ?? "")")
            return Self.response(for: req, body: Data("{}".utf8), status: 404)
        }
        let otherWorkspace = Workspace(id: "w2", name: "Other", slug: "other", issuePrefix: "OTH")
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.project-detail.workspace-mismatch.test"))
        session.currentWorkspace = otherWorkspace
        session.workspaces = [workspace, otherWorkspace]
        let vm = ProjectDetailViewModel(project: project, api: client, authSession: session)

        await vm.load()

        XCTAssertFalse(didRequest)
        XCTAssertEqual(vm.errorMessage, "This project belongs to another workspace. Switch back to Workspace to view it.")
    }

    func test_attachAndRemoveGitHubResourceUpdatesResources() async throws {
        var requests: [(method: String?, path: String, workspaceId: String?, body: [String: Any]?)] = []
        let client = makeClient { req in
            let components = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
            let bodyData = MockURLProtocol.bodyData(for: req)
            let body = bodyData.isEmpty ? nil : try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            requests.append((
                req.httpMethod,
                req.url?.path ?? "",
                components?.queryItems?.first(where: { $0.name == "workspace_id" })?.value,
                body
            ))
            switch (req.httpMethod, req.url?.path) {
            case ("POST", "/api/projects/p1/resources"):
                let json = """
                {"id":"r1","project_id":"p1","workspace_id":"w1","resource_type":"github_repo",
                 "resource_ref":{"url":"https://github.com/multica-ai/multica"},"label":null,
                 "position":0,"created_at":"2026-01-01T00:00:00Z","created_by":null}
                """.data(using: .utf8)!
                return Self.response(for: req, body: json, status: 201)
            case ("DELETE", "/api/projects/p1/resources/r1"):
                return Self.response(for: req, body: Data(), status: 204)
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = ProjectDetailViewModel(project: project, api: client, authSession: makeSession())

        await vm.attachGitHubResource(url: " https://github.com/multica-ai/multica ")
        await vm.removeResource(id: "r1")

        XCTAssertEqual(requests.map(\.method), ["POST", "DELETE"])
        XCTAssertEqual(requests.map(\.path), ["/api/projects/p1/resources", "/api/projects/p1/resources/r1"])
        XCTAssertEqual(requests.map(\.workspaceId), ["w1", "w1"])
        XCTAssertEqual((requests[0].body?["resource_ref"] as? [String: Any])?["url"] as? String, "https://github.com/multica-ai/multica")
        XCTAssertEqual(vm.resources.map(\.id), [])
        XCTAssertNil(vm.errorMessage)
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multica.app.project-detail.test"))
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

    private static func issuesJSON(_ issues: [String], total: Int) -> Data {
        let raw = #"{"issues":["# + issues.joined(separator: ",") + #"],"total":"# + "\(total)" + "}"
        return Data(raw.utf8)
    }

    private static func issueJSON(id: String, number: Int, status: String) -> String {
        """
        {"id":"\(id)","identifier":"PAR-\(number)","number":\(number),"title":"Issue \(number)","description":null,
         "status":"\(status)","priority":"none","assignee_id":null,"assignee_type":null,
         "project_id":"p1","workspace_id":"w1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """
    }
}
