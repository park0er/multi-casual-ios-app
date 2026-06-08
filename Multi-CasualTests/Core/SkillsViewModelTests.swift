import XCTest
@testable import MultiCasual

@MainActor
final class SkillsViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_loadFetchesSkills() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/skills")
            XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
            return Self.response(for: req, body: "[\(String(data: Self.skillJSON(id: "s1", name: "Writer"), encoding: .utf8)!)]".data(using: .utf8)!)
        }
        let vm = SkillsViewModel(api: client, authSession: makeSession())

        await vm.load()

        XCTAssertEqual(vm.skills.map(\.id), ["s1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_createUpdateImportAndDeleteKeepListInSync() async throws {
        var requests: [String] = []
        var requestURLs: [URL] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            requestURLs.append(req.url!)
            if req.httpMethod == "DELETE" {
                return Self.response(for: req, body: Data("{}".utf8), status: 204)
            }
            let name = req.url?.path == "/api/skills/import" ? "Imported" : "Writer"
            return Self.response(for: req, body: Self.skillJSON(id: "s1", name: name))
        }
        let vm = SkillsViewModel(api: client, authSession: makeSession())

        _ = await vm.createSkill(name: "Writer", description: "", content: "# Skill")
        _ = await vm.updateSkill(id: "s1", name: "Writer", description: "D", content: "# Updated")
        _ = await vm.importSkill(url: "https://example.com/skill")
        await vm.deleteSkill(id: "s1")

        XCTAssertTrue(vm.skills.isEmpty)
        XCTAssertEqual(requests, [
            "POST /api/skills",
            "PUT /api/skills/s1",
            "POST /api/skills/import",
            "DELETE /api/skills/s1",
        ])
        XCTAssertTrue(requestURLs.allSatisfy { $0.absoluteString.contains("workspace_id=w1") })
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadSkillDetailFetchesFullSkillAndCachesItInList() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            switch (req.httpMethod, req.url?.path) {
            case ("GET", "/api/skills"):
                return Self.response(
                    for: req,
                    body: "[\(String(data: Self.skillJSON(id: "s1", name: "Writer", content: ""), encoding: .utf8)!)]".data(using: .utf8)!
                )
            case ("GET", "/api/skills/s1"):
                XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
                return Self.response(for: req, body: Self.skillJSON(
                    id: "s1",
                    name: "Writer",
                    content: "# SKILL.md\n\nDetailed instructions",
                    files: [
                        SkillFile(id: "f1", path: "SKILL.md", content: "# SKILL.md\n\nDetailed instructions"),
                        SkillFile(id: "f2", path: "references/example.md", content: "Example"),
                    ]
                ))
            default:
                XCTFail("Unexpected request: \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = SkillsViewModel(api: client, authSession: makeSession())

        await vm.load()
        let detail = await vm.loadSkillDetail(id: "s1")

        XCTAssertEqual(requests, ["GET /api/skills", "GET /api/skills/s1"])
        XCTAssertEqual(detail?.content, "# SKILL.md\n\nDetailed instructions")
        XCTAssertEqual(detail?.files.map(\.path), ["SKILL.md", "references/example.md"])
        XCTAssertEqual(vm.skills.first?.content, "# SKILL.md\n\nDetailed instructions")
        XCTAssertFalse(vm.isLoadingSkillDetail)
        XCTAssertNil(vm.skillDetailError)
    }

    func test_skillFileTreeBuildsDirectoriesBeforeNestedFiles() {
        let files = [
            SkillFile(id: "b", path: "scripts/build.sh", content: nil),
            SkillFile(id: "a", path: "SKILL.md", content: nil),
            SkillFile(id: "c", path: "references/examples/demo.md", content: nil),
            SkillFile(id: "d", path: "references/overview.md", content: nil),
        ]

        let tree = SkillFileTreeNode.build(from: files)

        XCTAssertEqual(tree.map(\.name), ["references", "scripts", "SKILL.md"])
        XCTAssertEqual(tree.first?.children.map(\.name), ["examples", "overview.md"])
        XCTAssertEqual(tree.first?.children.first?.children.map(\.name), ["demo.md"])
        XCTAssertEqual(tree.first?.children.first?.path, "references/examples")
        XCTAssertEqual(tree.last?.path, "SKILL.md")
    }

    private func makeSession() -> AuthSession {
        let session = AuthSession(keychain: KeychainStore(service: "ai.multi-casual.app.skills.test"))
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

    private static func skillJSON(
        id: String,
        name: String,
        content: String = "# Skill",
        files: [SkillFile] = []
    ) -> Data {
        let encodedContent = String(data: try! JSONEncoder().encode(content), encoding: .utf8)!
        let encodedFiles = String(data: try! JSONEncoder().encode(files), encoding: .utf8)!
        return """
        {"id":"\(id)","workspace_id":"w1","name":"\(name)","description":"D",
         "content":\(encodedContent),"config":{},"files":\(encodedFiles),"created_by":"u1",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }
}
