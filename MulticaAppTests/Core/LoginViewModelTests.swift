import XCTest
@testable import MultiCasual

@MainActor
final class LoginViewModelTests: XCTestCase {
    private let keychain = KeychainStore(service: "ai.multica.app.login-view-model.test")
    private let defaults = UserDefaults(suiteName: "ai.multica.app.login-view-model.test")!

    override func setUpWithError() throws {
        #if os(iOS)
        throw XCTSkip("Keychain tests require a signed host app entitlement; covered by macOS swift test.")
        #endif
        try? keychain.delete()
        defaults.removePersistentDomain(forName: "ai.multica.app.login-view-model.test")
        MockURLProtocol.handler = nil
    }

    override func tearDown() {
        try? keychain.delete()
        defaults.removePersistentDomain(forName: "ai.multica.app.login-view-model.test")
        MockURLProtocol.handler = nil
    }

    func test_sendCode_movesToOtpAndStartsCooldown() async {
        let vm = makeViewModel { req in
            XCTAssertEqual(req.url?.path, "/auth/send-code")
            return Self.response(req, body: "{}")
        }
        vm.email = "user@example.com"

        await vm.sendCode()

        XCTAssertEqual(vm.step, .otp)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.cooldownSeconds, 60)
        vm.backToEmail()
    }

    func test_sendCode_surfacesServerError() async {
        let vm = makeViewModel { req in
            Self.response(req, status: 500, body: #"{"error":"mail is unavailable"}"#)
        }
        vm.email = "user@example.com"

        await vm.sendCode()

        XCTAssertEqual(vm.step, .email)
        XCTAssertEqual(vm.errorMessage, "mail is unavailable")
        XCTAssertEqual(vm.cooldownSeconds, 0)
    }

    func test_sendCode_requiresEmail() async {
        let vm = makeViewModel { _ in
            XCTFail("Empty email should not call the backend")
            return Self.response(URLRequest(url: URL(string: "https://example.com")!), body: "{}")
        }
        vm.email = "   "

        await vm.sendCode()

        XCTAssertEqual(vm.step, .email)
        XCTAssertEqual(vm.errorMessage, "Email is required")
    }

    func test_verifyCode_logsInWithReturnedTokenAndWorkspaces() async throws {
        var requestedPaths: [String] = []
        let authSession = AuthSession(keychain: keychain, userDefaults: defaults)
        let vm = makeViewModel(authSession: authSession) { req in
            requestedPaths.append(req.url?.path ?? "")
            switch req.url?.path {
            case "/auth/verify-code":
                return Self.response(req, body: #"{"token":"session-token"}"#)
            case "/api/me":
                return Self.response(req, body: #"{"id":"u1","email":"user@example.com","name":"User","avatar_url":null}"#)
            case "/api/workspaces":
                return Self.response(req, body: #"[{"id":"w1","name":"Workspace","slug":"workspace","issue_prefix":"WS"}]"#)
            default:
                return Self.response(req, status: 404, body: "")
            }
        }
        vm.email = "user@example.com"
        vm.code = "123456"

        await vm.verifyCode()

        XCTAssertEqual(requestedPaths, ["/auth/verify-code", "/api/me", "/api/workspaces"])
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(authSession.token(), "session-token")
        XCTAssertEqual(authSession.currentUser?.email, "user@example.com")
        XCTAssertEqual(authSession.currentWorkspace?.id, "w1")
    }

    func test_verifyCode_clearsInvalidCodeOnFailure() async {
        let vm = makeViewModel { req in
            Self.response(req, status: 401, body: "")
        }
        vm.email = "user@example.com"
        vm.code = "123456"

        await vm.verifyCode()

        XCTAssertEqual(vm.code, "")
        XCTAssertEqual(vm.errorMessage, "You're signed out. Please sign in again.")
    }

    func test_resendCode_doesNothingDuringCooldown() async {
        var requestCount = 0
        let vm = makeViewModel { req in
            requestCount += 1
            return Self.response(req, body: "{}")
        }
        vm.email = "user@example.com"
        vm.cooldownSeconds = 10

        await vm.resendCode()

        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(vm.step, .email)
        XCTAssertEqual(vm.cooldownSeconds, 10)
    }

    func test_backToEmailClearsOtpStateAndCooldown() {
        let vm = makeViewModel { req in
            Self.response(req, body: "{}")
        }
        vm.email = "user@example.com"
        vm.code = "123456"
        vm.errorMessage = "Wrong code"
        vm.cooldownSeconds = 12
        vm.step = .otp

        vm.backToEmail()

        XCTAssertEqual(vm.step, .email)
        XCTAssertEqual(vm.code, "")
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.cooldownSeconds, 0)
    }

    private func makeViewModel(
        authSession: AuthSession? = nil,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> LoginViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let api = APIClient(session: session)
        MockURLProtocol.handler = handler
        return LoginViewModel(
            api: api,
            authSession: authSession ?? AuthSession(keychain: keychain, userDefaults: defaults)
        )
    }

    private static func response(
        _ req: URLRequest,
        status: Int = 200,
        body: String
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            body.data(using: .utf8)!
        )
    }
}
