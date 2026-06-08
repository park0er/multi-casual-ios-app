import XCTest
@testable import MultiCasual

// Hits the REAL Multi-Casual production API to catch path bugs that mock-based
// unit tests can't see. Each test sends a deliberately malformed request
// and asserts the response is NOT 404 — i.e. the endpoint exists.
//
// Why this exists: our unit tests use MockURLProtocol which returns 200
// for any URL the client constructs, so `/api/auth/send-code` (wrong)
// and `/auth/send-code` (correct) both pass mocks identically. Only a
// real request distinguishes them.
//
// Tests skip (not fail) when the network is unreachable so offline
// `swift test` stays green.
final class BackendSmokeTests: XCTestCase {
    private let baseURL = URL(string: "https://api.multi-casual.ai")!

    private func assertEndpointExists(
        method: String,
        path: String,
        body: String? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 5
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data(body.utf8)
        }

        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw XCTSkip("Backend unreachable (offline or DNS failure): \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            XCTFail("Non-HTTP response for \(method) \(path)", file: file, line: line); return
        }
        XCTAssertNotEqual(http.statusCode, 404,
            "\(method) /\(path) returned 404 — endpoint does not exist at this path. "
          + "This test deliberately sends a malformed request; 4xx (400/401/422) would prove "
          + "the path exists and only the payload/auth is wrong.",
            file: file, line: line)
    }

    func test_authSendCode_pathExists() async throws {
        try await assertEndpointExists(method: "POST", path: "auth/send-code", body: "{}")
    }

    func test_authVerifyCode_pathExists() async throws {
        try await assertEndpointExists(method: "POST", path: "auth/verify-code", body: "{}")
    }

    // GET without Authorization should come back as 401, not 404.
    func test_apiMe_pathExists() async throws {
        try await assertEndpointExists(method: "GET", path: "api/me")
    }

    func test_apiWorkspaces_pathExists() async throws {
        try await assertEndpointExists(method: "GET", path: "api/workspaces")
    }
}
