import XCTest
@testable import MultiCasual

// URLProtocol stub for intercepting requests without a real server
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

@MainActor
final class APIClientTests: XCTestCase {
    var client: APIClient!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        client = APIClient(session: session, token: "test-token")
    }

    func test_getMe_decodesUser() async throws {
        let json = """
        {"id":"u1","email":"test@example.com","name":"Test User","avatar_url":null}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let user = try await client.getMe()
        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(user.email, "test@example.com")
    }

    func test_unauthorized_throwsAuthError() async {
        MockURLProtocol.handler = { req in
            return (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await client.getMe()
            XCTFail("Expected error")
        } catch APIClient.APIError.unauthorized {
            // pass
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_listIssues_sendsWorkspaceIdParam() async throws {
        let json = """
        {"issues":[],"has_more":false,"total":0}
        """.data(using: .utf8)!
        var capturedURL: URL?
        MockURLProtocol.handler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        _ = try await client.listIssues(workspaceId: "ws1", limit: 50, offset: 0)
        XCTAssertTrue(capturedURL?.absoluteString.contains("workspace_id=ws1") ?? false)
        XCTAssertTrue(capturedURL?.absoluteString.contains("limit=50") ?? false)
    }

    func test_verifyGoogleCode_postsPayloadAndReturnsToken() async throws {
        let json = """
        {"token":"multica-session-token"}
        """.data(using: .utf8)!
        var capturedPath: String?
        var capturedMethod: String?
        var capturedBody: Data?
        MockURLProtocol.handler = { req in
            capturedPath = req.url?.path
            capturedMethod = req.httpMethod
            if let body = req.httpBody {
                capturedBody = body
            } else if let stream = req.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = Data()
                var chunk = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let read = stream.read(&chunk, maxLength: chunk.count)
                    if read <= 0 { break }
                    buffer.append(chunk, count: read)
                }
                capturedBody = buffer
            }
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let token = try await client.verifyGoogleCode(
            code: "auth-code-123",
            codeVerifier: "verifier-xyz",
            redirectURI: "ai.multica.app://auth/callback"
        )

        XCTAssertEqual(token, "multica-session-token")
        XCTAssertEqual(capturedPath, "/api/auth/verify-google")
        XCTAssertEqual(capturedMethod, "POST")
        let bodyString = capturedBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertTrue(bodyString.contains("\"code\":\"auth-code-123\""), "body was: \(bodyString)")
        XCTAssertTrue(bodyString.contains("\"code_verifier\":\"verifier-xyz\""), "body was: \(bodyString)")
        XCTAssertTrue(bodyString.contains("\"redirect_uri\":\"ai.multica.app:\\/\\/auth\\/callback\""), "body was: \(bodyString)")
    }
}
