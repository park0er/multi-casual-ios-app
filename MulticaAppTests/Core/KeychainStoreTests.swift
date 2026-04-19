import XCTest
@testable import MultiCasual

final class KeychainStoreTests: XCTestCase {
    let store = KeychainStore(service: "ai.multica.app.test")

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
