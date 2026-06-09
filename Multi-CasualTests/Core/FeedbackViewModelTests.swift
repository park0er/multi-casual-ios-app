import XCTest
@testable import MultiCasual

@MainActor
final class FeedbackViewModelTests: XCTestCase {
    private let workspace = Workspace(id: "w1", name: "Workspace", slug: "workspace", issuePrefix: "PAR")

    func test_submitRequiresWorkspace() async throws {
        var didRequest = false
        let client = makeClient { req in
            didRequest = true
            return Self.response(for: req, body: Data(#"{"id":"fb1","created_at":"2026-05-07T00:00:00Z"}"#.utf8))
        }
        let vm = FeedbackViewModel(api: client, authSession: makeSession(workspace: nil))

        await vm.submit(message: "Hello", url: nil)

        XCTAssertFalse(didRequest)
        XCTAssertEqual(vm.errorMessage, "Pick a workspace before sending feedback.")
        XCTAssertNil(vm.successMessage)
    }

    func test_submitRequiresMessage() async throws {
        let client = makeClient { req in
            XCTFail("Feedback request should not be sent for empty messages: \(req)")
            return Self.response(for: req, body: Data())
        }
        let vm = FeedbackViewModel(api: client, authSession: makeSession(workspace: workspace))

        await vm.submit(message: "   \n ", url: "https://app.multica.ai")

        XCTAssertEqual(vm.errorMessage, "Feedback message is required.")
        XCTAssertNil(vm.successMessage)
    }

    func test_submitTrimsInputAndSetsSuccessState() async throws {
        var capturedBody: [String: Any]?
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/feedback")
            XCTAssertEqual(req.url?.query, "workspace_id=w1")
            let requestBody = MockURLProtocol.bodyData(for: req)
            capturedBody = try? JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
            return Self.response(
                for: req,
                body: Data(#"{"id":"fb1","created_at":"2026-05-07T00:00:00Z"}"#.utf8)
            )
        }
        let vm = FeedbackViewModel(api: client, authSession: makeSession(workspace: workspace))

        await vm.submit(message: "  **Bug** report  ", url: "  https://app.multica.ai/issues/1  ")

        XCTAssertEqual(capturedBody?["message"] as? String, "**Bug** report")
        XCTAssertEqual(capturedBody?["url"] as? String, "https://app.multica.ai/issues/1")
        XCTAssertEqual(capturedBody?["workspace_id"] as? String, "w1")
        XCTAssertEqual(vm.successMessage, "Feedback sent.")
        XCTAssertEqual(vm.lastFeedbackId, "fb1")
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isSubmitting)
    }

    private func makeSession(workspace: Workspace?) -> AuthSession {
        let session = AuthSession(
            keychain: KeychainStore(service: "ai.multi-casual.app.feedback.test.\(UUID().uuidString)"),
            userDefaults: UserDefaults(suiteName: "FeedbackViewModelTests.\(UUID().uuidString)")!
        )
        session.currentWorkspace = workspace
        session.workspaces = workspace.map { [$0] } ?? []
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
}
