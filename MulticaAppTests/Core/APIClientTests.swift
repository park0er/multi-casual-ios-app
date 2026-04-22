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

    func test_sendCode_usesAuthSendCodePath() async throws {
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedPath = req.url?.path
            return (HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
        }
        try await client.sendCode(email: "x@y.com")
        XCTAssertEqual(capturedPath, "/auth/send-code",
            "sendCode must not use the /api/ prefix — backend auth endpoints are rooted at /auth/*")
    }

    func test_verifyCode_usesAuthVerifyCodePath() async throws {
        let json = """
        {"token":"t"}
        """.data(using: .utf8)!
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedPath = req.url?.path
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        _ = try await client.verifyCode(email: "x@y.com", code: "123456")
        XCTAssertEqual(capturedPath, "/auth/verify-code")
    }

    // MARK: - APIError LocalizedError

    func test_apiError_unauthorized_localizesToSignOutPrompt() {
        XCTAssertEqual(
            APIClient.APIError.unauthorized.errorDescription,
            "You're signed out. Please sign in again."
        )
    }

    func test_apiError_serverError_withJSONErrorField_surfacesBackendMessage() {
        let body = #"{"error":"Invalid verification code"}"#
        XCTAssertEqual(
            APIClient.APIError.serverError(400, body: body).errorDescription,
            "Invalid verification code"
        )
    }

    func test_apiError_serverError_withPlainText_includesStatusAndPreview() {
        XCTAssertEqual(
            APIClient.APIError.serverError(500, body: "something broke").errorDescription,
            "Server error (500): something broke"
        )
    }

    func test_apiError_serverError_withEmptyBody_fallsBackToGenericMessage() {
        XCTAssertEqual(
            APIClient.APIError.serverError(503, body: "").errorDescription,
            "Server error (503). Please try again."
        )
    }
}
