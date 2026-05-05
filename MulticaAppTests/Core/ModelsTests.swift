import XCTest
@testable import MultiCasual

private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}()

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
        let issue = try decoder.decode(Issue.self, from: json)
        XCTAssertEqual(issue.id, "abc123")
        XCTAssertEqual(issue.identifier, "PAR-71")
        XCTAssertEqual(issue.status, .inProgress)
        XCTAssertEqual(issue.priority, .high)
        XCTAssertNil(issue.assigneeId)
    }

    func test_issueStatus_decodesDesktopStatuses() throws {
        let backlog = try decoder.decode(IssueStatus.self, from: #""backlog""#.data(using: .utf8)!)
        let cancelled = try decoder.decode(IssueStatus.self, from: #""cancelled""#.data(using: .utf8)!)

        XCTAssertEqual(backlog, .backlog)
        XCTAssertEqual(cancelled, .cancelled)
    }

    func test_issueStatus_sortsInDesktopBoardOrder() {
        let scrambled: [IssueStatus] = [.blocked, .done, .todo, .cancelled, .backlog, .inReview, .inProgress]

        XCTAssertEqual(scrambled.sorted(), [.backlog, .todo, .inProgress, .inReview, .done, .blocked, .cancelled])
    }

    func test_issueStatus_displayCasesExcludeUnknownAndMatchDesktopBoardOrder() {
        XCTAssertEqual(IssueStatus.displayCases, [.backlog, .todo, .inProgress, .inReview, .done, .blocked, .cancelled])
    }

    func test_issuePriority_decodesDesktopNonePriority() throws {
        let priority = try decoder.decode(IssuePriority.self, from: #""none""#.data(using: .utf8)!)

        XCTAssertEqual(priority, .noPriority)
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
        let comment = try decoder.decode(Comment.self, from: json)
        XCTAssertEqual(comment.content, "Hello world")
        XCTAssertEqual(comment.authorType, "member")
    }

    func test_pageResponse_decodesIssuesKey() throws {
        let json = """
        {"issues": [
            {"id":"i1","identifier":"T-1","number":1,"title":"T","description":null,
             "status":"todo","priority":"medium","assignee_id":null,"assignee_type":null,
             "project_id":null,"workspace_id":"w","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        ], "has_more": true, "total": 1}
        """.data(using: .utf8)!
        let page = try decoder.decode(PageResponse<Issue>.self, from: json)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertTrue(page.hasMore)
    }

    func test_pageResponse_decodesBareArray() throws {
        let json = """
        [
            {"id":"c1","content":"Hello","author_id":"u1","author_type":"member",
             "parent_id":null,"issue_id":"i1","created_at":"2026-01-01T00:00:00Z"}
        ]
        """.data(using: .utf8)!

        let page = try decoder.decode(PageResponse<Comment>.self, from: json)

        XCTAssertEqual(page.items.count, 1)
        XCTAssertFalse(page.hasMore)
        XCTAssertEqual(page.total, 1)
    }

    func test_inboxItem_decodesDesktopShape() throws {
        let json = """
        {
            "id": "n1",
            "workspace_id": "w1",
            "recipient_type": "member",
            "recipient_id": "u1",
            "actor_type": "agent",
            "actor_id": "a1",
            "type": "new_comment",
            "severity": "attention",
            "issue_id": "i1",
            "title": "PAR-73 updated",
            "body": "A comment was added",
            "issue_status": "in_progress",
            "read": false,
            "archived": false,
            "created_at": "2026-01-01T00:00:00Z",
            "details": {"identifier": "PAR-73", "comment_id": "c1"}
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(InboxItem.self, from: json)

        XCTAssertEqual(item.issueId, "i1")
        XCTAssertEqual(item.issueIdentifier, "PAR-73")
        XCTAssertEqual(item.issueTitle, "PAR-73 updated")
        XCTAssertFalse(item.read)
    }

    func test_project_decodesDesktopShape() throws {
        let json = """
        {
            "id": "p1",
            "workspace_id": "w1",
            "title": "iOS MVP",
            "description": "Mobile client",
            "icon": null,
            "status": "in_progress",
            "priority": "none",
            "lead_type": null,
            "lead_id": null,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-02T00:00:00Z",
            "issue_count": 8,
            "done_count": 3
        }
        """.data(using: .utf8)!

        let project = try decoder.decode(Project.self, from: json)

        XCTAssertEqual(project.name, "iOS MVP")
        XCTAssertEqual(project.status, .inProgress)
        XCTAssertEqual(project.priority, .noPriority)
        XCTAssertEqual(project.workspaceId, "w1")
        XCTAssertEqual(project.issueCount, 8)
        XCTAssertEqual(project.doneCount, 3)
    }

    func test_projectStatus_allCases_haveDisplayName() {
        for status in ProjectStatus.allCases {
            XCTAssertFalse(status.displayName.isEmpty, "Project status \(status) missing displayName")
        }
    }

    func test_issueStatus_allCases_haveDisplayName() {
        for status in IssueStatus.allCases {
            XCTAssertFalse(status.displayName.isEmpty, "Status \(status) missing displayName")
            XCTAssertFalse(status.icon.isEmpty, "Status \(status) missing icon")
        }
    }
}
