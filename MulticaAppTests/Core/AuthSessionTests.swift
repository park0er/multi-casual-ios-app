import XCTest
@testable import MultiCasual

@MainActor
final class AuthSessionTests: XCTestCase {
    private let store = KeychainStore(service: "ai.multica.app.auth-session.test")

    override func setUpWithError() throws {
        #if os(iOS)
        throw XCTSkip("Keychain tests require a signed host app entitlement; covered by macOS swift test.")
        #endif
        try? store.delete()
    }

    override func tearDown() {
        try? store.delete()
    }

    func test_installDebugToken_savesProvidedToken() throws {
        let session = AuthSession(keychain: store)

        try session.installDebugToken("debug-token")

        XCTAssertEqual(session.token(), "debug-token")
    }

    func test_preferredWorkspace_usesRequestedWorkspaceWhenPresent() {
        let first = Workspace(id: "w1", name: "First", slug: "first", issuePrefix: "FIR")
        let second = Workspace(id: "w2", name: "Second", slug: "second", issuePrefix: "SEC")

        let selected = AuthSession.preferredWorkspace(from: [first, second], preferredId: "w2")

        XCTAssertEqual(selected?.id, "w2")
    }

    func test_preferredWorkspace_fallsBackToFirstWorkspace() {
        let first = Workspace(id: "w1", name: "First", slug: "first", issuePrefix: "FIR")
        let second = Workspace(id: "w2", name: "Second", slug: "second", issuePrefix: "SEC")

        let selected = AuthSession.preferredWorkspace(from: [first, second], preferredId: "missing")

        XCTAssertEqual(selected?.id, "w1")
    }
}
