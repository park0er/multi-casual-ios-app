import XCTest
@testable import MultiCasual

@MainActor
final class AuthSessionTests: XCTestCase {
    private let store = KeychainStore(service: "ai.multica.app.auth-session.test")
    private let defaults = UserDefaults(suiteName: "ai.multica.app.auth-session.test")!

    override func setUpWithError() throws {
        #if os(iOS)
        throw XCTSkip("Keychain tests require a signed host app entitlement; covered by macOS swift test.")
        #endif
        try? store.delete()
        defaults.removePersistentDomain(forName: "ai.multica.app.auth-session.test")
    }

    override func tearDown() {
        try? store.delete()
        defaults.removePersistentDomain(forName: "ai.multica.app.auth-session.test")
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

    func test_setWorkspace_updatesCurrentWorkspaceAndPersistsSelection() {
        let first = Workspace(id: "w1", name: "First", slug: "first", issuePrefix: "FIR")
        let second = Workspace(id: "w2", name: "Second", slug: "second", issuePrefix: "SEC")
        let session = AuthSession(keychain: store, userDefaults: defaults)
        session.workspaces = [first, second]

        session.setWorkspace(second)

        XCTAssertEqual(session.currentWorkspace?.id, "w2")
        XCTAssertEqual(session.preferredWorkspaceId, "w2")
    }

    func test_newSessionReadsPersistedWorkspaceSelection() {
        let first = Workspace(id: "w1", name: "First", slug: "first", issuePrefix: "FIR")
        let second = Workspace(id: "w2", name: "Second", slug: "second", issuePrefix: "SEC")
        let session = AuthSession(keychain: store, userDefaults: defaults)
        session.workspaces = [first, second]
        session.setWorkspace(second)

        let nextSession = AuthSession(keychain: store, userDefaults: defaults)

        XCTAssertEqual(nextSession.preferredWorkspaceId, "w2")
        XCTAssertEqual(AuthSession.preferredWorkspace(from: [first, second], preferredId: nextSession.preferredWorkspaceId)?.id, "w2")
    }

    func test_loginStoresAllWorkspacesAndUsesPersistedSelection() throws {
        let first = Workspace(id: "w1", name: "First", slug: "first", issuePrefix: "FIR")
        let second = Workspace(id: "w2", name: "Second", slug: "second", issuePrefix: "SEC")
        defaults.set("w2", forKey: AuthSession.selectedWorkspaceDefaultsKey)
        let user = User(id: "u1", email: "u@example.com", name: "User", avatarUrl: nil)
        let session = AuthSession(keychain: store, userDefaults: defaults)

        try session.login(user: user, workspaces: [first, second], token: "token")

        XCTAssertEqual(session.workspaces.map(\.id), ["w1", "w2"])
        XCTAssertEqual(session.currentWorkspace?.id, "w2")
        XCTAssertEqual(session.token(), "token")
    }

    func test_logoutClearsWorkspaceStateAndPersistedSelection() {
        let workspace = Workspace(id: "w1", name: "First", slug: "first", issuePrefix: "FIR")
        let session = AuthSession(keychain: store, userDefaults: defaults)
        session.workspaces = [workspace]
        session.setWorkspace(workspace)

        session.logout()

        XCTAssertNil(session.currentWorkspace)
        XCTAssertTrue(session.workspaces.isEmpty)
        XCTAssertNil(session.preferredWorkspaceId)
    }
}
