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
}
