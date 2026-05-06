import XCTest
@testable import MultiCasual

@MainActor
final class SkillsViewModelTests: XCTestCase {
    func test_loadFetchesSkills() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/skills")
            return Self.response(for: req, body: "[\(String(data: Self.skillJSON(id: "s1", name: "Writer"), encoding: .utf8)!)]".data(using: .utf8)!)
        }
        let vm = SkillsViewModel(api: client)

        await vm.load()

        XCTAssertEqual(vm.skills.map(\.id), ["s1"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_createUpdateImportAndDeleteKeepListInSync() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            if req.httpMethod == "DELETE" {
                return Self.response(for: req, body: Data("{}".utf8), status: 204)
            }
            let name = req.url?.path == "/api/skills/import" ? "Imported" : "Writer"
            return Self.response(for: req, body: Self.skillJSON(id: "s1", name: name))
        }
        let vm = SkillsViewModel(api: client)

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
        XCTAssertNil(vm.errorMessage)
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

    private static func skillJSON(id: String, name: String) -> Data {
        """
        {"id":"\(id)","workspace_id":"w1","name":"\(name)","description":"D",
         "content":"# Skill","config":{},"files":[],"created_by":"u1",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.data(using: .utf8)!
    }
}
