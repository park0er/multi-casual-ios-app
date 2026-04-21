import XCTest
@testable import MultiCasual

final class KeychainStoreTests: XCTestCase {
    let store = KeychainStore(service: "ai.multica.app.test")

    override func setUpWithError() throws {
        // iOS Simulator denies SecItem* calls (-34018 errSecMissingEntitlement) for test
        // bundles without a signed host app providing keychain-access-groups.
        // Coverage is via `swift test` on macOS, which has no such restriction.
        #if os(iOS)
        throw XCTSkip("Keychain tests require a signed host app entitlement; covered by macOS swift test.")
        #endif
    }

    override func tearDown() {
        try? store.delete()
    }

    func test_saveAndLoad_roundTrips() throws {
        try store.save("test-jwt-token-123")
        let loaded = try store.load()
        XCTAssertEqual(loaded, "test-jwt-token-123")
    }

    func test_loadMissing_throwsNotFound() {
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? KeychainStore.KeychainError, .notFound)
        }
    }

    func test_delete_removesToken() throws {
        try store.save("token")
        try store.delete()
        XCTAssertThrowsError(try store.load())
    }

    func test_overwrite_replacesValue() throws {
        try store.save("first")
        try store.save("second")
        let loaded = try store.load()
        XCTAssertEqual(loaded, "second")
    }
}
