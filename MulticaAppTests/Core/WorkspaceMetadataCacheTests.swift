import XCTest
@testable import MultiCasual

final class WorkspaceMetadataCacheTests: XCTestCase {
    func test_agentsAreCachedPerAPIClientAndWorkspace() async throws {
        let cache = WorkspaceMetadataCache()
        var requestCount = 0
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/agents")
            requestCount += 1
            return Self.response(for: req, body: Self.agentsJSON())
        }

        let first = try await cache.agents(workspaceId: "w1", api: client)
        let second = try await cache.agents(workspaceId: "w1", api: client)

        XCTAssertEqual(first.map(\.id), ["a1"])
        XCTAssertEqual(second.map(\.id), ["a1"])
        XCTAssertEqual(requestCount, 1)
    }

    func test_includeArchivedAgentsSeedActiveAgentCache() async throws {
        let cache = WorkspaceMetadataCache()
        var requestCount = 0
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/agents")
            requestCount += 1
            return Self.response(for: req, body: Self.agentsJSON(includeArchived: true))
        }

        let allAgents = try await cache.agents(workspaceId: "w1", includeArchived: true, api: client)
        let activeAgents = try await cache.agents(workspaceId: "w1", api: client)

        XCTAssertEqual(allAgents.map(\.id), ["a1", "a2"])
        XCTAssertEqual(activeAgents.map(\.id), ["a1"])
        XCTAssertEqual(requestCount, 1)
    }

    func test_membersAreCachedPerWorkspace() async throws {
        let cache = WorkspaceMetadataCache()
        var requestCount = 0
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/workspaces/w1/members")
            requestCount += 1
            return Self.response(for: req, body: Self.membersJSON())
        }

        _ = try await cache.members(workspaceId: "w1", api: client)
        _ = try await cache.members(workspaceId: "w1", api: client)

        XCTAssertEqual(requestCount, 1)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        MockURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return APIClient(session: session, baseURL: URL(string: "https://example.test")!, token: "t")
    }

    private static func response(for request: URLRequest, body: Data) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
    }

    private static func membersJSON() -> Data {
        """
        [{"id":"m1","workspace_id":"w1","user_id":"u1","name":"Parker","email":"parker@example.com","role":"admin","created_at":"2026-01-01T00:00:00Z"}]
        """.data(using: .utf8)!
    }

    private static func agentsJSON(includeArchived: Bool = false) -> Data {
        let archived = includeArchived
            ? #",{"id":"a2","name":"Archived","model":"gpt-5","status":"idle","workspace_id":"w1","created_by":"u1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","archived_at":"2026-01-02T00:00:00Z"}"#
            : ""
        return """
        [{"id":"a1","name":"Codex","model":"gpt-5","status":"idle","workspace_id":"w1","created_by":"u1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","archived_at":null}\(archived)]
        """.data(using: .utf8)!
    }
}
