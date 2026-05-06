import XCTest
@testable import MultiCasual

final class DestructiveConfirmationTests: XCTestCase {
    func test_logoutConfirmationNamesCurrentWorkspace() {
        let confirmation = DestructiveConfirmation.logout(workspaceName: "Parker")

        XCTAssertEqual(confirmation.title, "Log out of Parker?")
        XCTAssertEqual(confirmation.message, "You will need to sign in again to use this workspace.")
        XCTAssertEqual(confirmation.confirmTitle, "Log Out")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
    }

    func test_inboxArchiveConfirmationNamesNotification() {
        let confirmation = DestructiveConfirmation.archiveInboxItem(issueTitle: "Core iOS walkthrough")

        XCTAssertEqual(confirmation.title, "Archive this notification?")
        XCTAssertEqual(confirmation.message, "Core iOS walkthrough will be removed from Inbox.")
        XCTAssertEqual(confirmation.confirmTitle, "Archive")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
    }

    func test_archiveInboxBulkConfirmationNamesScope() {
        let confirmation = DestructiveConfirmation.archiveInboxBulk(.read)

        XCTAssertEqual(confirmation.title, "Archive read notifications?")
        XCTAssertEqual(confirmation.message, "All read notifications will be removed from Inbox.")
        XCTAssertEqual(confirmation.confirmTitle, "Archive")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
    }

    func test_issueDeleteConfirmationNamesIdentifier() {
        let confirmation = DestructiveConfirmation.deleteIssue(identifier: "PAR-73", title: "Core iOS walkthrough")

        XCTAssertEqual(confirmation.title, "Delete PAR-73?")
        XCTAssertEqual(confirmation.message, "This removes the issue and its activity from the workspace. This action cannot be undone.")
        XCTAssertEqual(confirmation.confirmTitle, "Delete")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
    }

    func test_issueBatchDeleteConfirmationNamesCount() {
        let confirmation = DestructiveConfirmation.deleteIssues(count: 3)

        XCTAssertEqual(confirmation.title, "Delete 3 issues?")
        XCTAssertEqual(confirmation.message, "This removes the selected issues and their activity from the workspace. This action cannot be undone.")
        XCTAssertEqual(confirmation.confirmTitle, "Delete")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
    }

    func test_cancelTaskConfirmationNamesTaskId() {
        let confirmation = DestructiveConfirmation.cancelTask(id: "task-123")

        XCTAssertEqual(confirmation.title, "Cancel task task-123?")
        XCTAssertEqual(confirmation.message, "The running agent task will be cancelled. Existing messages and history stay available.")
        XCTAssertEqual(confirmation.confirmTitle, "Cancel Task")
        XCTAssertEqual(confirmation.cancelTitle, "Keep Running")
    }

    func test_deleteProjectConfirmationNamesProject() {
        let confirmation = DestructiveConfirmation.deleteProject(name: "Roadmap")

        XCTAssertEqual(confirmation.title, "Delete \"Roadmap\"?")
        XCTAssertEqual(confirmation.message, "This removes the project from the workspace. Linked issues stay available.")
        XCTAssertEqual(confirmation.confirmTitle, "Delete")
        XCTAssertEqual(confirmation.cancelTitle, "Cancel")
    }
}
