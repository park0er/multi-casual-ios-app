// ModelsValidator - a lightweight runner for the same assertions that the
// XCTest-based Multi-CasualTests will run once Xcode is installed.
//
// XCTest is not available on a bare Command Line Tools install (no Xcode on
// this build host), so `swift test` can't be used yet. This executable runs
// the same decode / enum-coverage checks so the models are verified today.
// Exits non-zero on first failure.
//
// Invoke: swift run ModelsValidator
import Foundation
import MultiCasual

var failures: [String] = []
var passed = 0

func expect(_ condition: Bool, _ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
    if condition {
        passed += 1
    } else {
        failures.append("FAIL [\(file):\(line)] \(message())")
    }
}

// MARK: test_issue_decodesFromJSON
do {
    let json = """
    {
        "id": "abc123",
        "identifier": "PAR-71",
        "number": 71,
        "title": "Tech Stack Selection",
        "description": "Determine iOS tech stack",
        "status": "in_progress",
        "priority": "high",
        "assignee_id": null,
        "assignee_type": null,
        "project_id": null,
        "workspace_id": "ws1",
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-02T00:00:00Z"
    }
    """.data(using: .utf8)!
    do {
        let issue = try JSONDecoder().decode(Issue.self, from: json)
        expect(issue.id == "abc123", "issue.id == abc123 (got \(issue.id))")
        expect(issue.identifier == "PAR-71", "issue.identifier == PAR-71")
        expect(issue.status == .inProgress, "issue.status == .inProgress")
        expect(issue.priority == .high, "issue.priority == .high")
        expect(issue.assigneeId == nil, "issue.assigneeId == nil")
        print("ok  test_issue_decodesFromJSON")
    } catch {
        failures.append("FAIL test_issue_decodesFromJSON: \(error)")
    }
}

// MARK: test_comment_decodesFromJSON
do {
    let json = """
    {
        "id": "c1",
        "content": "Hello world",
        "author_id": "u1",
        "author_type": "member",
        "parent_id": null,
        "issue_id": "i1",
        "created_at": "2026-01-01T00:00:00Z"
    }
    """.data(using: .utf8)!
    do {
        let comment = try JSONDecoder().decode(Comment.self, from: json)
        expect(comment.content == "Hello world", "comment.content == Hello world")
        expect(comment.authorType == "member", "comment.authorType == member")
        print("ok  test_comment_decodesFromJSON")
    } catch {
        failures.append("FAIL test_comment_decodesFromJSON: \(error)")
    }
}

// MARK: test_pageResponse_decodesIssuesKey
do {
    let json = """
    {"issues": [
        {"id":"i1","identifier":"T-1","number":1,"title":"T","description":null,
         "status":"todo","priority":"medium","assignee_id":null,"assignee_type":null,
         "project_id":null,"workspace_id":"w","created_at":"","updated_at":""}
    ], "has_more": true, "total": 1}
    """.data(using: .utf8)!
    do {
        let page = try JSONDecoder().decode(PageResponse<Issue>.self, from: json)
        expect(page.items.count == 1, "page.items.count == 1 (got \(page.items.count))")
        expect(page.hasMore == true, "page.hasMore == true")
        print("ok  test_pageResponse_decodesIssuesKey")
    } catch {
        failures.append("FAIL test_pageResponse_decodesIssuesKey: \(error)")
    }
}

// MARK: test_issueStatus_allCases_haveDisplayName
do {
    for status in IssueStatus.allCases {
        expect(!status.displayName.isEmpty, "Status \(status) missing displayName")
        expect(!status.icon.isEmpty, "Status \(status) missing icon")
    }
    print("ok  test_issueStatus_allCases_haveDisplayName")
}

// MARK: - KeychainStore validation (mirrors KeychainStoreTests)
let testStore = KeychainStore(service: "ai.multica.app.validator.test")
try? testStore.delete() // clean slate

// test_saveAndLoad_roundTrips
try testStore.save("test-jwt-token-123")
let loaded = try testStore.load()
assert(loaded == "test-jwt-token-123", "FAIL: save/load round trip")
try testStore.delete()
print("ok  test_saveAndLoad_roundTrips")

// test_loadMissing_throwsNotFound
do {
    _ = try testStore.load()
    assert(false, "FAIL: should have thrown")
} catch KeychainStore.KeychainError.notFound {
    print("ok  test_loadMissing_throwsNotFound")
} catch {
    assert(false, "FAIL: wrong error: \(error)")
}

// test_overwrite_replacesValue
try testStore.save("first")
try testStore.save("second")
let overwritten = try testStore.load()
assert(overwritten == "second", "FAIL: overwrite failed")
try testStore.delete()
print("ok  test_overwrite_replacesValue")

print("")
print("\(passed) assertions passed, \(failures.count) failed")
if !failures.isEmpty {
    for failure in failures { print(failure) }
    exit(1)
}
print("All tests passed.")
