import XCTest
@testable import MultiCasual

@MainActor
final class PersonalAccessTokensViewModelTests: XCTestCase {
    func test_loadFetchesPersonalAccessTokens() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.httpMethod, "GET")
            XCTAssertEqual(req.url?.path, "/api/tokens")
            return Self.response(
                for: req,
                body: Data(#"[{"id":"t1","name":"CLI","token_prefix":"mul_abc12345","expires_at":null,"last_used_at":null,"created_at":"2026-05-01T00:00:00Z"}]"#.utf8)
            )
        }
        let vm = PersonalAccessTokensViewModel(api: client)

        await vm.load()

        XCTAssertEqual(vm.tokens.map(\.name), ["CLI"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_createStoresOneTimeTokenAndReloadsList() async throws {
        var requests: [String] = []
        var createBody: [String: Any]?
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            if req.httpMethod == "POST" {
                let requestBody = MockURLProtocol.bodyData(for: req)
                createBody = requestBody.isEmpty
                    ? nil
                    : (try? JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
                return Self.response(
                    for: req,
                    body: Data(#"{"id":"t2","name":"Mobile","token_prefix":"mul_xyz12345","expires_at":null,"last_used_at":null,"created_at":"2026-05-01T00:00:00Z","token":"mul_xyz123456"}"#.utf8),
                    status: 201
                )
            }
            return Self.response(
                for: req,
                body: Data(#"[{"id":"t2","name":"Mobile","token_prefix":"mul_xyz12345","expires_at":null,"last_used_at":null,"created_at":"2026-05-01T00:00:00Z"}]"#.utf8)
            )
        }
        let vm = PersonalAccessTokensViewModel(api: client)

        await vm.createToken(name: "Mobile", expiresInDays: nil)

        XCTAssertEqual(requests, ["POST /api/tokens", "GET /api/tokens"])
        XCTAssertEqual(createBody?["name"] as? String, "Mobile")
        XCTAssertNil(createBody?["expires_in_days"])
        XCTAssertEqual(vm.newToken, "mul_xyz123456")
        XCTAssertEqual(vm.tokens.map(\.id), ["t2"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_revokeDeletesTokenAndReloadsList() async throws {
        var requests: [String] = []
        let client = makeClient { req in
            requests.append("\(req.httpMethod ?? "") \(req.url?.path ?? "")")
            if req.httpMethod == "DELETE" {
                return Self.response(for: req, body: Data(), status: 204)
            }
            return Self.response(for: req, body: Data("[]".utf8))
        }
        let vm = PersonalAccessTokensViewModel(api: client)

        await vm.revokeToken(id: "t1")

        XCTAssertEqual(requests, ["DELETE /api/tokens/t1", "GET /api/tokens"])
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
}
