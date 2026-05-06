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
            "parent_issue_id": "parent1",
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
        XCTAssertEqual(issue.parentIssueId, "parent1")
    }

    func test_issue_decodesAttachmentsFromDesktopDetailResponse() throws {
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
            "updated_at": "2026-01-02T00:00:00Z",
            "attachments": [{
                "id": "att1",
                "workspace_id": "ws1",
                "issue_id": "abc123",
                "comment_id": null,
                "uploader_type": "member",
                "uploader_id": "u1",
                "filename": "spec.pdf",
                "url": "https://cdn.example/spec.pdf",
                "download_url": "https://cdn.example/spec.pdf?sig=1",
                "content_type": "application/pdf",
                "size_bytes": 2048,
                "created_at": "2026-01-01T00:00:00Z"
            }]
        }
        """.data(using: .utf8)!

        let issue = try decoder.decode(Issue.self, from: json)

        XCTAssertEqual(issue.attachments.count, 1)
        XCTAssertEqual(issue.attachments.first?.filename, "spec.pdf")
        XCTAssertEqual(issue.attachments.first?.sizeBytes, 2048)
    }

    func test_issue_decodesLabelsFromDesktopDetailResponse() throws {
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
            "updated_at": "2026-01-02T00:00:00Z",
            "labels": [{
                "id": "l1",
                "workspace_id": "ws1",
                "name": "bug",
                "color": "#ef4444",
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-01-01T00:00:00Z"
            }]
        }
        """.data(using: .utf8)!

        let issue = try decoder.decode(Issue.self, from: json)

        XCTAssertEqual(issue.labels.map(\.id), ["l1"])
        XCTAssertEqual(issue.labels.first?.name, "bug")
        XCTAssertEqual(issue.labels.first?.color, "#ef4444")
    }

    func test_issue_decodesReactionsFromDesktopDetailResponse() throws {
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
            "updated_at": "2026-01-02T00:00:00Z",
            "reactions": [{
                "id": "ir1",
                "issue_id": "abc123",
                "actor_type": "member",
                "actor_id": "u1",
                "emoji": "👍",
                "created_at": "2026-01-01T00:00:00Z"
            }]
        }
        """.data(using: .utf8)!

        let issue = try decoder.decode(Issue.self, from: json)

        XCTAssertEqual(issue.reactions.map(\.id), ["ir1"])
        XCTAssertEqual(issue.reactions.first?.emoji, "👍")
        XCTAssertEqual(issue.reactions.first?.actorId, "u1")
    }

    func test_issueSubscriber_decodesDesktopShape() throws {
        let json = """
        {
            "issue_id": "i1",
            "user_type": "member",
            "user_id": "u1",
            "reason": "manual",
            "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let subscriber = try decoder.decode(IssueSubscriber.self, from: json)

        XCTAssertEqual(subscriber.id, "member:u1")
        XCTAssertEqual(subscriber.issueId, "i1")
        XCTAssertEqual(subscriber.userType, "member")
        XCTAssertEqual(subscriber.userId, "u1")
        XCTAssertEqual(subscriber.reason, "manual")
        XCTAssertEqual(subscriber.createdAt, ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z"))
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

    func test_issueStatus_displayCasesExcludeUnknownAndKeepCancelledForForms() {
        XCTAssertEqual(IssueStatus.displayCases, [.backlog, .todo, .inProgress, .inReview, .done, .blocked, .cancelled])
    }

    func test_issueStatus_boardCasesMatchDesktopBoardStatuses() {
        XCTAssertEqual(IssueStatus.boardCases, [.backlog, .todo, .inProgress, .inReview, .done, .blocked])
    }

    func test_issuePriority_decodesDesktopNonePriority() throws {
        let priority = try decoder.decode(IssuePriority.self, from: #""none""#.data(using: .utf8)!)

        XCTAssertEqual(priority, .noPriority)
    }

    func test_timelineEntry_decodesDesktopActivityAndCommentShapes() throws {
        let json = """
        [{
            "type": "activity",
            "id": "activity1",
            "actor_type": "member",
            "actor_id": "user1",
            "created_at": "2026-01-01T00:00:00Z",
            "action": "priority_changed",
            "details": {"from": "low", "to": "urgent", "count": 2}
        }, {
            "type": "comment",
            "id": "comment1",
            "actor_type": "agent",
            "actor_id": "agent1",
            "created_at": "2026-01-02T00:00:00Z",
            "content": "**Markdown** comment",
            "parent_id": null,
            "comment_type": "comment",
            "attachments": []
        }]
        """.data(using: .utf8)!

        let entries = try decoder.decode([TimelineEntry].self, from: json)

        XCTAssertEqual(entries[0].type, .activity)
        XCTAssertEqual(entries[0].action, "priority_changed")
        XCTAssertEqual(entries[0].detailString("to"), "urgent")
        XCTAssertEqual(entries[0].detailString("count"), "2")
        XCTAssertEqual(entries[1].type, .comment)
        XCTAssertEqual(entries[1].content, "**Markdown** comment")
        XCTAssertTrue(entries[1].attachments.isEmpty)
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

    func test_comment_decodesAttachmentsFromDesktopShape() throws {
        let json = """
        {
            "id": "c1",
            "content": "See screenshot",
            "author_id": "u1",
            "author_type": "member",
            "parent_id": null,
            "issue_id": "i1",
            "reactions": [],
            "attachments": [{
                "id": "att1",
                "workspace_id": "ws1",
                "issue_id": "i1",
                "comment_id": "c1",
                "uploader_type": "member",
                "uploader_id": "u1",
                "filename": "screen.png",
                "url": "https://cdn.example/screen.png",
                "download_url": "https://cdn.example/screen.png?sig=1",
                "content_type": "image/png",
                "size_bytes": 4096,
                "created_at": "2026-01-01T00:00:00Z"
            }],
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let comment = try decoder.decode(Comment.self, from: json)

        XCTAssertEqual(comment.attachments.count, 1)
        XCTAssertEqual(comment.attachments.first?.filename, "screen.png")
        XCTAssertEqual(comment.attachments.first?.contentType, "image/png")
    }

    func test_comment_decodesReactionsFromDesktopShape() throws {
        let json = """
        {
            "id": "c1",
            "content": "Looks good",
            "author_id": "u1",
            "author_type": "member",
            "parent_id": null,
            "issue_id": "i1",
            "reactions": [{
                "id": "r1",
                "comment_id": "c1",
                "actor_type": "member",
                "actor_id": "u2",
                "emoji": "👀",
                "created_at": "2026-01-01T00:00:00Z"
            }],
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let comment = try decoder.decode(Comment.self, from: json)

        XCTAssertEqual(comment.reactions.map(\.id), ["r1"])
        XCTAssertEqual(comment.reactions.first?.emoji, "👀")
        XCTAssertEqual(comment.reactions.first?.actorId, "u2")
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
        XCTAssertEqual(item.type, "new_comment")
        XCTAssertEqual(item.body, "A comment was added")
        XCTAssertEqual(item.severity, "attention")
        XCTAssertEqual(item.issueStatus, .inProgress)
        XCTAssertFalse(item.read)
    }

    func test_inboxItem_decodesLegacyShapeWithDisplayDefaults() throws {
        let json = """
        {
            "id": "n1",
            "issue_id": "i1",
            "issue_identifier": "PAR-73",
            "issue_title": "Legacy notification",
            "read": true,
            "archived": false,
            "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(InboxItem.self, from: json)

        XCTAssertEqual(item.type, "notification")
        XCTAssertNil(item.body)
        XCTAssertNil(item.severity)
        XCTAssertEqual(item.issueStatus, .unknown)
        XCTAssertTrue(item.read)
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
