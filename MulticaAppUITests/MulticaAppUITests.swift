import XCTest

final class Multi-CasualUITests: XCTestCase {
    private let workspaceId = "7f97e6b9-2db3-489c-a270-4e4c6d354469"
    private let par73IssueId = "9a808431-341f-4ead-8d8c-055e2e00686e"
    private let transcriptTaskId = "9eab0d97-de00-4f90-82a6-d70cbb5161a2"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSettingsWorkspaceScreenRenders() {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Log Out"].exists)
    }

    func testCreateIssueSheetRendersRequiredFields() {
        let app = launchApp(initialTab: "issues", openCreateSheet: true)

        XCTAssertTrue(app.navigationBars["New Issue"].waitForExistence(timeout: 20))
        let titleField = app.textFields["Issue title"]
        XCTAssertTrue(titleField.exists)
        XCTAssertTrue(app.staticTexts["Description"].exists)
        XCTAssertTrue(app.staticTexts["Status"].exists)
        XCTAssertTrue(app.staticTexts["Priority"].exists)
        XCTAssertTrue(app.staticTexts["Assignee"].exists)
        XCTAssertTrue(app.staticTexts["Project"].exists)
        XCTAssertTrue(app.staticTexts["Due Date"].exists)

        titleField.tap()
        titleField.typeText("UI smoke draft")
        XCTAssertTrue(app.buttons["Create"].isEnabled)
    }

    func testInboxSwipeShowsArchiveActionWithoutSubmitting() {
        let app = launchApp(initialTab: "inbox")

        XCTAssertTrue(app.staticTexts["Inbox"].waitForExistence(timeout: 20))
        let firstNotification = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstNotification.waitForExistence(timeout: 20))
        let rowButton = firstNotification.buttons.element(boundBy: 0)
        XCTAssertTrue(rowButton.waitForExistence(timeout: 5))
        rowButton.swipeLeft()
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
    }

    func testIssueDetailRendersMetadataCommentsAndInput() {
        let app = launchApp(initialTab: "issues", issueId: par73IssueId)

        XCTAssertTrue(app.staticTexts["PAR-73"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Agent Activity"].waitForExistence(timeout: 20))
        let commentField = app.descendants(matching: .any)["IssueDetailCommentInput"].firstMatch
        XCTAssertTrue(commentField.waitForExistence(timeout: 10))
        commentField.tap()
        commentField.typeText("UI draft")
        XCTAssertTrue(commentField.value.debugDescription.contains("UI draft"))
        XCTAssertTrue(app.buttons["IssueDetailCommentSendButton"].isEnabled)
    }

    func testAgentTranscriptRendersTimeline() {
        let app = launchApp(initialTab: "issues", taskId: transcriptTaskId)

        XCTAssertTrue(app.staticTexts["Agent Transcript"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Tool Use"].waitForExistence(timeout: 20))
    }

    private func launchApp(
        initialTab: String,
        issueId: String? = nil,
        taskId: String? = nil,
        openCreateSheet: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MULTICA_DEBUG_SKIP_PUSH_PROMPT"] = "1"
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_ID"] = workspaceId
        app.launchEnvironment["MULTICA_DEBUG_INITIAL_TAB"] = initialTab
        if let issueId {
            app.launchEnvironment["MULTICA_DEBUG_INITIAL_ISSUE_ID"] = issueId
        }
        if let taskId {
            app.launchEnvironment["MULTICA_DEBUG_INITIAL_TASK_ID"] = taskId
        }
        if openCreateSheet {
            app.launchEnvironment["MULTICA_DEBUG_OPEN_CREATE_SHEET"] = "1"
        }
        app.launch()
        return app
    }

}
