import XCTest
@testable import MultiCasual

final class ModelsTests: XCTestCase {

    func test_issue_decodesFromJSON() throws {
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
        let issue = try JSONDecoder().decode(Issue.self, from: json)
        XCTAssertEqual(issue.id, "abc123")
        XCTAssertEqual(issue.identifier, "PAR-71")
        XCTAssertEqual(issue.status, .inProgress)
        XCTAssertEqual(issue.priority, .high)
        XCTAssertNil(issue.assigneeId)
    }

    func test_comment_decodesFromJSON() throws {
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
        let comment = try JSONDecoder().decode(Comment.self, from: json)
        XCTAssertEqual(comment.content, "Hello world")
        XCTAssertEqual(comment.authorType, "member")
    }

    func test_pageResponse_decodesIssuesKey() throws {
        let json = """
        {"issues": [
            {"id":"i1","identifier":"T-1","number":1,"title":"T","description":null,
             "status":"todo","priority":"medium","assignee_id":null,"assignee_type":null,
             "project_id":null,"workspace_id":"w","created_at":"","updated_at":""}
        ], "has_more": true, "total": 1}
        """.data(using: .utf8)!
        let page = try JSONDecoder().decode(PageResponse<Issue>.self, from: json)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertTrue(page.hasMore)
    }

    func test_issueStatus_allCases_haveDisplayName() {
        for status in IssueStatus.allCases {
            XCTAssertFalse(status.displayName.isEmpty, "Status \(status) missing displayName")
            XCTAssertFalse(status.icon.isEmpty, "Status \(status) missing icon")
        }
    }
}
