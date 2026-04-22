import XCTest
@testable import MultiCasual

final class DataStoreTests: XCTestCase {

    func test_invalidateIssue_marksId() async {
        let store = DataStore()
        await store.invalidateIssue("a")
        let result = await store.isIssueInvalidated("a")
        XCTAssertTrue(result)
    }

    func test_clearInvalidation_unmarksId() async {
        let store = DataStore()
        await store.invalidateIssue("b")
        await store.clearInvalidation("b")
        let result = await store.isIssueInvalidated("b")
        XCTAssertFalse(result)
    }

    func test_isIssueInvalidated_returnsFalseForUnknown() async {
        let store = DataStore()
        let result = await store.isIssueInvalidated("never-seen")
        XCTAssertFalse(result)
    }
}
