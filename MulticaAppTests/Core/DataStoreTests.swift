import XCTest
@testable import MultiCasual

final class DataStoreTests: XCTestCase {

    func test_setIssues_replacesAll() async {
        let store = DataStore()
        await store.setIssues(makeIssues(["a", "b"]))
        await store.setIssues(makeIssues(["c"]))
        let issues = await store.issues
        XCTAssertEqual(issues.map(\.id), ["c"])
    }

    func test_invalidateIssue_removesById() async {
        let store = DataStore()
        await store.setIssues(makeIssues(["a", "b", "c"]))
        await store.invalidateIssue("b")
        let issues = await store.issues
        XCTAssertEqual(issues.map(\.id), ["a", "c"])
    }

    func test_appendIssues_addsToExisting() async {
        let store = DataStore()
        await store.setIssues(makeIssues(["a"]))
        await store.appendIssues(makeIssues(["b", "c"]))
        let issues = await store.issues
        XCTAssertEqual(issues.map(\.id), ["a", "b", "c"])
    }

    private func makeIssues(_ ids: [String]) -> [Issue] {
        ids.map { Issue(id: $0, identifier: "T-1", number: 1, title: "T",
                        description: nil, status: .todo, priority: .medium,
                        assigneeId: nil, assigneeType: nil, projectId: nil,
                        workspaceId: "w", createdAt: "", updatedAt: "") }
    }
}
